import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'connection.dart';
import 'daos/expense_dao.dart';
import 'daos/pot_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/room_dao.dart';
import 'daos/sync_dao.dart';
import 'tables/expenses_table.dart';
import 'tables/pots_table.dart';
import 'tables/profiles_table.dart';
import 'tables/rooms_table.dart';
import 'tables/sync_tables.dart';

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
  daos: [ProfileDao, RoomDao, ExpenseDao, PotDao, SyncDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Rule: each bump must be forward-compatible with data already on
      // devices — additive only, never a destructive ALTER.
      if (from < 2) {
        await m.addColumn(profilesTable, profilesTable.monthlyBudgetPaise);
      }
    },
  );

  /// Wipes every local table — used on sign-out so the next account on
  /// this device never sees the previous one's cached financial data.
  Future<void> clearAll() => transaction(() async {
    for (final table in allTables) {
      await delete(table).go();
    }
  });
}

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}
