import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'tables/profiles_table.dart';
import 'tables/rooms_table.dart';
import 'tables/expenses_table.dart';
import 'tables/pots_table.dart';
import 'tables/sync_tables.dart';
import 'daos/profile_dao.dart';
import 'daos/room_dao.dart';
import 'daos/expense_dao.dart';
import 'daos/sync_dao.dart';
import 'connection.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    ProfilesTable,
    RoomsTable,
    RoomMembersTable,
    RoomInvitesTable,
    ExpensesTable,
    ExpenseSplitsTable,
    PersonalExpensesTable,
    SettlementsTable,
    PotsTable,
    PotContributionsTable,
    SyncQueueTable,
    SyncStateTable,
  ],
  daos: [
    ProfileDao,
    RoomDao,
    ExpenseDao,
    SyncDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Future schema migrations go here.
      // Rule: each version bump must be forward-compatible with data already
      // in production — never a destructive ALTER.
    },
  );
}


@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
