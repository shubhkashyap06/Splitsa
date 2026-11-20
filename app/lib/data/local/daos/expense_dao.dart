import 'package:drift/drift.dart';

import '../database.dart';
import '../tables/expenses_table.dart';

part 'expense_dao.g.dart';

/// Read-side access to expenses, splits and settlements.
///
/// The local DB only ever contains rows for rooms the user belongs to (RLS
/// scopes what the delta pull can fetch), so "all rows" queries are already
/// "all rows I'm allowed to see".
///
/// Writes go through the repositories in `data/repositories/`, which pair
/// every local write with a `sync_queue` entry in the same transaction.
@DriftAccessor(
  tables: [
    ExpensesTable,
    ExpenseSplitsTable,
    PersonalExpensesTable,
    SettlementsTable,
  ],
)
class ExpenseDao extends DatabaseAccessor<AppDatabase> with _$ExpenseDaoMixin {
  ExpenseDao(super.db);

  // ── Shared expenses ──────────────────────────────────────────────────────

  Stream<List<ExpensesTableData>> watchAllExpenses() =>
      (select(expensesTable)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Stream<List<ExpenseSplitsTableData>> watchAllSplits() =>
      (select(expenseSplitsTable)..where((t) => t.deletedAt.isNull())).watch();

  Future<ExpensesTableData?> getExpense(String id) =>
      (select(expensesTable)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<ExpenseSplitsTableData>> getSplitsForExpense(String expenseId) =>
      (select(expenseSplitsTable)
            ..where((t) => t.expenseId.equals(expenseId))
            ..where((t) => t.deletedAt.isNull()))
          .get();

  // ── Personal expenses ────────────────────────────────────────────────────

  Stream<List<PersonalExpensesTableData>> watchPersonalExpenses(
    String userId,
  ) =>
      (select(personalExpensesTable)
            ..where((t) => t.userId.equals(userId))
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  // ── Settlements ──────────────────────────────────────────────────────────

  Stream<List<SettlementsTableData>> watchAllSettlements() =>
      (select(settlementsTable)
            ..where((t) => t.deletedAt.isNull())
            ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
          .watch();

  Future<void> upsertSettlement(SettlementsTableCompanion companion) =>
      into(settlementsTable).insertOnConflictUpdate(companion);
}
