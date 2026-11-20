import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/profiles_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [ProfilesTable])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  ProfileDao(super.db);

  Future<ProfilesTableData?> getProfile(String userId) => (select(
    profilesTable,
  )..where((t) => t.id.equals(userId))).getSingleOrNull();

  Stream<ProfilesTableData?> watchProfile(String userId) => (select(
    profilesTable,
  )..where((t) => t.id.equals(userId))).watchSingleOrNull();

  /// Own profile + every co-member's profile the delta pull has fetched.
  Stream<List<ProfilesTableData>> watchAllProfiles() =>
      select(profilesTable).watch();

  /// Only used on sign-in to seed a row before the first pull lands.
  Future<void> insertIfAbsent(ProfilesTableCompanion companion) =>
      into(profilesTable).insert(companion, mode: InsertMode.insertOrIgnore);
}
