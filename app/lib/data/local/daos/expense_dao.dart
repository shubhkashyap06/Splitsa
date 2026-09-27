import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

@DriftAccessor(tables: [ExpensesTable, ExpenseSplitsTable, PersonalExpensesTable, SettlementsTable])
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  // ── Shared expenses ──────────────────────────────────────────────────────

  Stream<List<ExpensesTableData>> watchExpensesForRoom(String roomId) =>
      (select(expensesTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertExpense(ExpensesTableCompanion companion) =>
      into(expensesTable).insertOnConflictUpdate(companion);

  Future<void> upsertSplit(ExpenseSplitsTableCompanion companion) =>
      into(expenseSplitsTable).insertOnConflictUpdate(companion);

  Future<List<ExpenseSplitsTableData>> getSplitsForExpense(String expenseId) =>
      (select(expenseSplitsTable)..where((t) => t.expenseId.equals(expenseId))).get();

  // ── Personal expenses ────────────────────────────────────────────────────

  Stream<List<PersonalExpensesTableData>> watchPersonalExpenses(String userId) =>
      (select(personalExpensesTable)
        ..where((t) => t.userId.equals(userId))
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertPersonalExpense(PersonalExpensesTableCompanion companion) =>
      into(personalExpensesTable).insertOnConflictUpdate(companion);

  // ── Settlements ──────────────────────────────────────────────────────────

  Stream<List<SettlementsTableData>> watchSettlementsForRoom(String roomId) =>
      (select(settlementsTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull())
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertSettlement(SettlementsTableCompanion companion) =>
      into(settlementsTable).insertOnConflictUpdate(companion);

  // ── Balance computation (pure Dart — no DB query) ───────────────────────
  // The actual debt simplification algorithm lives in:
  // app/lib/features/recommendations/logic_engine/debt_simplifier.dart
  // This DAO just provides the raw data rows it needs.

  Future<List<ExpensesTableData>> getExpensesForRoom(String roomId) =>
      (select(expensesTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull()))
          .get();

  Future<List<SettlementsTableData>> getSettlementsForRoom(String roomId) =>
      (select(settlementsTable)
        ..where((t) => t.roomId.equals(roomId))
        ..where((t) => t.deletedAt.isNull()))
          .get();

  Future<List<ExpenseSplitsTableData>> getSplitsForRoom(String roomId) {
    final query = select(expenseSplitsTable).join([
      innerJoin(expensesTable, expensesTable.id.equalsExp(expenseSplitsTable.expenseId)),
    ])
      ..where(expensesTable.roomId.equals(roomId))
      ..where(expensesTable.deletedAt.isNull())
      ..where(expenseSplitsTable.deletedAt.isNull());
    return query.map((r) => r.readTable(expenseSplitsTable)).get();
  }
}
