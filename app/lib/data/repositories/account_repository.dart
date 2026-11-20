import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/config/app_config.dart';
import '../local/database.dart';
import '../remote/remote_gateway.dart';
import '../remote/session.dart';
import '../remote/supabase_service.dart';

part 'account_repository.g.dart';

class BlockingBalance {
  const BlockingBalance({
    required this.roomId,
    required this.roomName,
    required this.netBalancePaise,
  });
  final String roomId;
  final String roomName;

  /// Negative = they owe; positive = they're owed.
  final int netBalancePaise;
}

sealed class DeleteAccountResult {
  const DeleteAccountResult();
}

class AccountDeleted extends DeleteAccountResult {
  const AccountDeleted();
}

class DeletionBlocked extends DeleteAccountResult {
  const DeletionBlocked(this.balances);
  final List<BlockingBalance> balances;
}

class AccountActionError implements Exception {
  const AccountActionError(this.message);
  final String message;
  @override
  String toString() => message;
}

class AccountRepository {
  AccountRepository(this._db, this._remote);
  final AppDatabase _db;
  final RemoteGateway _remote;

  /// Server-enforced deletion (PRODUCT_LOGIC.md §6). The local balance check
  /// in the UI is a courtesy; `account-delete` is the real gate.
  Future<DeleteAccountResult> deleteAccount({
    required String confirmEmail,
    required bool forfeitOwed,
  }) async {
    try {
      await _remote.invoke('account-delete', {
        'confirm': confirmEmail,
        'forfeit_owed': forfeitOwed,
      });
    } on RemoteFailure catch (e) {
      if (e.status == 409 && e.body?['blocking'] is List) {
        final list = (e.body!['blocking'] as List).cast<Map>();
        return DeletionBlocked([
          for (final b in list)
            BlockingBalance(
              roomId: b['room_id'] as String,
              roomName: b['room_name'] as String? ?? 'Room',
              netBalancePaise: (b['net_balance_paise'] as num).toInt(),
            ),
        ]);
      }
      if (e.kind == RemoteFailureKind.transient) {
        throw const AccountActionError(
          'You\'re offline — try again with a connection',
        );
      }
      throw AccountActionError(e.message);
    }
    await signOut();
    return const AccountDeleted();
  }

  /// Signs out and wipes the local DB so the next account on this device
  /// never sees cached data from this one.
  Future<void> signOut() async {
    if (AppConfig.instance.demoMode) {
      await _db.clearAll(); // demo re-seeds on next launch
      return;
    }
    try {
      await SupabaseService.client.auth.signOut();
    } catch (_) {
      // Already invalid server-side (e.g. just deleted) — still clear locally.
    }
    await _db.clearAll();
  }
}

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) => AccountRepository(
  ref.watch(appDatabaseProvider),
  ref.watch(remoteGatewayProvider),
);
