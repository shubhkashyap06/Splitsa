import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/profiles_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [ProfilesTable])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  /// Returns the currently logged-in user's profile, or null if not cached.
  Future<ProfilesTableData?> getProfile(String userId) =>
      (select(profilesTable)..where((t) => t.id.equals(userId))).getSingleOrNull();

  /// Watch the current user's profile for real-time updates.
  Stream<ProfilesTableData?> watchProfile(String userId) =>
      (select(profilesTable)..where((t) => t.id.equals(userId))).watchSingleOrNull();

  /// Upsert — used when syncing from Supabase or on first sign-in.
  Future<void> upsertProfile(ProfilesTableCompanion companion) =>
      into(profilesTable).insertOnConflictUpdate(companion);

  /// Update UPI ID after the user enters it in Profile settings.
  Future<void> setUpiId(String userId, String? upiId) =>
      (update(profilesTable)..where((t) => t.id.equals(userId))).write(
        ProfilesTableCompanion(
          upiId:     Value(upiId),
          updatedAt: Value(DateTime.now()),
        ),
      );

  Future<void> setNotificationPrefs({
    required String userId,
    bool? regularEnabled,
    String? quietStart,
    String? quietEnd,
  }) =>
      (update(profilesTable)..where((t) => t.id.equals(userId))).write(
        ProfilesTableCompanion(
          notificationsRegularEnabled: regularEnabled != null ? Value(regularEnabled) : const Value.absent(),
          quietHoursStart:             quietStart != null ? Value(quietStart) : const Value.absent(),
          quietHoursEnd:               quietEnd   != null ? Value(quietEnd)   : const Value.absent(),
          updatedAt:                   Value(DateTime.now()),
        ),
      );

  Future<void> softDeleteProfile(String userId) =>
      (update(profilesTable)..where((t) => t.id.equals(userId))).write(
        ProfilesTableCompanion(
          displayName: const Value('Deleted user'),
          deletedAt:   Value(DateTime.now()),
          updatedAt:   Value(DateTime.now()),
        ),
      );
}
