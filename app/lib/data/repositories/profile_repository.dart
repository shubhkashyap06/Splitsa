import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../local/database.dart';
import '../sync/outbox.dart';
import '../sync/sync_providers.dart';
import '../sync/synced_tables.dart';

part 'profile_repository.g.dart';

class ProfileValidationError implements Exception {
  const ProfileValidationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// UPI VPA shape: handle@psp — letters/digits/.-_ then an alpha PSP code.
final _vpaPattern = RegExp(r'^[a-zA-Z0-9.\-_]{2,256}@[a-zA-Z]{2,64}$');

class ProfileRepository {
  ProfileRepository(this._db, {void Function()? onWrite})
    : _outbox = Outbox(_db),
      _onWrite = onWrite ?? _noop;

  final AppDatabase _db;
  final Outbox _outbox;
  final void Function() _onWrite;

  static void _noop() {}

  static String? validateUpi(String? raw) {
    final v = raw?.trim() ?? '';
    if (v.isEmpty) return null;
    return _vpaPattern.hasMatch(v)
        ? null
        : 'That doesn\'t look like a UPI ID (name@bank)';
  }

  Future<void> update(
    String userId, {
    String? displayName,
    String? upiId,
    bool clearUpi = false,
    int? monthlyBudgetPaise,
    bool clearBudget = false,
    bool? regularNotifications,
    String? quietStart,
    String? quietEnd,
    bool clearQuietHours = false,
  }) async {
    if (displayName != null && displayName.trim().isEmpty) {
      throw const ProfileValidationError('Name can\'t be empty');
    }
    final upiError = validateUpi(upiId);
    if (upiError != null) throw ProfileValidationError(upiError);
    if (monthlyBudgetPaise != null && monthlyBudgetPaise < 0) {
      throw const ProfileValidationError('Budget can\'t be negative');
    }

    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.profilesTable,
      )..where((t) => t.id.equals(userId))).write(
        ProfilesTableCompanion(
          displayName: displayName == null
              ? const Value.absent()
              : Value(displayName.trim()),
          upiId: clearUpi
              ? const Value(null)
              : (upiId == null ? const Value.absent() : Value(upiId.trim())),
          monthlyBudgetPaise: clearBudget
              ? const Value(null)
              : (monthlyBudgetPaise == null
                    ? const Value.absent()
                    : Value(monthlyBudgetPaise)),
          notificationsRegularEnabled: regularNotifications == null
              ? const Value.absent()
              : Value(regularNotifications),
          quietHoursStart: clearQuietHours
              ? const Value(null)
              : (quietStart == null ? const Value.absent() : Value(quietStart)),
          quietHoursEnd: clearQuietHours
              ? const Value(null)
              : (quietEnd == null ? const Value.absent() : Value(quietEnd)),
          updatedAt: Value(now),
        ),
      );
      final row = await _db.profileDao.getProfile(userId);
      if (row != null) {
        await _outbox.update(
          profilesSync.name,
          userId,
          profilesSync.toRemote(row),
        );
      }
    });
    _onWrite();
  }
}

@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) => ProfileRepository(
  ref.watch(appDatabaseProvider),
  onWrite: () => ref.read(syncSchedulerProvider).kick(),
);
