import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/ids.dart';
import '../local/database.dart';
import '../remote/remote_gateway.dart';
import '../remote/session.dart';
import '../sync/sync_providers.dart';

part 'settle_repository.g.dart';

/// What the server agreed to — the Settle sheet shows *these* numbers, never
/// its own (ARCHITECTURE.md §4: don't trust a client amount for a deep link).
class SettleIntent {
  const SettleIntent({
    required this.opId,
    required this.validatedAmountPaise,
    required this.payeeName,
    required this.upiId,
  });
  final String opId;
  final int validatedAmountPaise;
  final String payeeName;
  final String? upiId;
}

class SettleError implements Exception {
  const SettleError(this.message, {this.owedPaise, this.offline = false});
  final String message;

  /// Set on a 409: what the server says is actually owed right now.
  final int? owedPaise;
  final bool offline;

  @override
  String toString() => message;
}

/// Settle-up is the one write that is *not* offline-first by design:
/// `settle-intent` is the only path that may create a settlement
/// (OFFLINE_SYNC.md §4), and handing off to a UPI app needs a connection
/// anyway. The op_id is generated once per attempt and reused on retry, so
/// a flaky network can never record the same payment twice.
class SettleRepository {
  SettleRepository(this._db, this._remote, {void Function()? onWrite})
    : _onWrite = onWrite ?? _noop;

  final AppDatabase _db;
  final RemoteGateway _remote;
  final void Function() _onWrite;

  static void _noop() {}

  String newOpId() => newId();

  Future<SettleIntent> settle({
    required String opId,
    required String roomId,
    required String payerId,
    required String payeeId,
    required int amountPaise,
  }) async {
    final Json res;
    try {
      res = await _remote.invoke('settle-intent', {
        'op_id': opId,
        'room_id': roomId,
        'payee_id': payeeId,
        'amount_paise': amountPaise,
      });
    } on RemoteFailure catch (e) {
      if (e.kind == RemoteFailureKind.transient) {
        throw const SettleError(
          'You\'re offline — settling needs a connection',
          offline: true,
        );
      }
      throw SettleError(
        e.message,
        owedPaise: (e.body?['owed_paise'] as num?)?.toInt(),
      );
    }

    final validated = (res['validated_amount_paise'] as num).toInt();
    final createdAt =
        DateTime.tryParse(res['created_at'] as String? ?? '') ?? DateTime.now();

    // Mirror the server-recorded settlement locally right away so balances
    // update without waiting for the next pull (the pull will upsert the
    // same id — idempotent).
    await _db.expenseDao.upsertSettlement(
      SettlementsTableCompanion.insert(
        id: opId,
        roomId: roomId,
        payerId: payerId,
        payeeId: payeeId,
        amountPaise: validated,
        createdAt: createdAt,
        updatedAt: createdAt,
        deletedAt: const Value(null),
      ),
    );
    _onWrite();

    return SettleIntent(
      opId: opId,
      validatedAmountPaise: validated,
      payeeName: res['payee_display_name'] as String? ?? 'them',
      upiId: res['upi_id'] as String?,
    );
  }
}

@Riverpod(keepAlive: true)
SettleRepository settleRepository(Ref ref) => SettleRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(remoteGatewayProvider),
  onWrite: () => ref.read(syncSchedulerProvider).kick(),
);
