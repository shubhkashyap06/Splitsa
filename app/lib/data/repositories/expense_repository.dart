import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/utils/ids.dart';
import '../local/database.dart';
import '../sync/outbox.dart';
import '../sync/sync_providers.dart';
import '../sync/synced_tables.dart';

part 'expense_repository.g.dart';

enum SplitMode { equal, unequal, percentage }

extension SplitModeWire on SplitMode {
  String get wire => switch (this) {
    SplitMode.equal => 'equal',
    SplitMode.unequal => 'unequal',
    SplitMode.percentage => 'percentage',
  };
}

class ExpenseValidationError implements Exception {
  const ExpenseValidationError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Writes expenses locally first, then queues them (OFFLINE_SYNC.md §2).
/// Never awaits the network — returns as soon as the local transaction
/// commits, so "Add expense" is instant in airplane mode.
class ExpenseRepository {
  ExpenseRepository(this._db, {void Function()? onWrite})
    : _outbox = Outbox(_db),
      _onWrite = onWrite ?? _noop;

  final AppDatabase _db;
  final Outbox _outbox;
  final void Function() _onWrite;

  static void _noop() {}

  /// Logs a shared expense. [shares] maps userId → paise and must already
  /// include the rounding remainder on the payer (use `splitAmount` etc.).
  Future<String> addSharedExpense({
    required String roomId,
    required String paidBy,
    required String description,
    required int amountPaise,
    required String category,
    String? subCategory,
    SplitMode splitMode = SplitMode.equal,
    required Map<String, int> shares,
    DateTime? at,
  }) async {
    if (amountPaise <= 0) {
      throw const ExpenseValidationError('Amount must be more than ₹0');
    }
    if (shares.isEmpty) {
      throw const ExpenseValidationError(
        'Pick at least one person to split with',
      );
    }
    if (shares.values.any((v) => v < 0)) {
      throw const ExpenseValidationError('Shares can\'t be negative');
    }
    final total = shares.values.fold<int>(0, (s, v) => s + v);
    if (total != amountPaise) {
      throw ExpenseValidationError(
        'Shares add up to ${total / 100}, not ${amountPaise / 100}',
      );
    }

    final now = at ?? DateTime.now();
    final expenseId = newId();
    final expense = ExpensesTableData(
      id: expenseId,
      roomId: roomId,
      paidBy: paidBy,
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amountPaise: amountPaise,
      category: category,
      subCategory: subCategory,
      splitMode: splitMode.wire,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction(() async {
      await _db.into(_db.expensesTable).insert(expense);
      await _outbox.insert(
        expensesSync.name,
        expenseId,
        expensesSync.toRemote(expense),
      );

      for (final entry in shares.entries) {
        final split = ExpenseSplitsTableData(
          id: newId(),
          expenseId: expenseId,
          userId: entry.key,
          amountPaise: entry.value,
          createdAt: now,
          updatedAt: now,
        );
        await _db.into(_db.expenseSplitsTable).insert(split);
        await _outbox.insert(
          expenseSplitsSync.name,
          split.id,
          expenseSplitsSync.toRemote(split),
        );
      }
    });
    _onWrite();
    return expenseId;
  }

  Future<String> addPersonalExpense({
    required String userId,
    required String description,
    required int amountPaise,
    required String category,
    String? subCategory,
    DateTime? at,
  }) async {
    if (amountPaise <= 0) {
      throw const ExpenseValidationError('Amount must be more than ₹0');
    }
    final now = at ?? DateTime.now();
    final row = PersonalExpensesTableData(
      id: newId(),
      userId: userId,
      description: description.trim().isEmpty ? 'Expense' : description.trim(),
      amountPaise: amountPaise,
      category: category,
      subCategory: subCategory,
      createdAt: now,
      updatedAt: now,
    );
    await _db.transaction(() async {
      await _db.into(_db.personalExpensesTable).insert(row);
      await _outbox.insert(
        personalExpensesSync.name,
        row.id,
        personalExpensesSync.toRemote(row),
      );
    });
    _onWrite();
    return row.id;
  }

  /// Soft-deletes a shared expense. Only its payer may (RLS enforces this
  /// server-side too); splits disappear with it because every balance query
  /// joins through a non-deleted expense.
  Future<void> deleteSharedExpense(
    String expenseId, {
    required String byUserId,
  }) async {
    final expense = await _db.expenseDao.getExpense(expenseId);
    if (expense == null) return;
    if (expense.paidBy != byUserId) {
      throw const ExpenseValidationError(
        'Only the person who paid can delete this',
      );
    }
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.expensesTable,
      )..where((t) => t.id.equals(expenseId))).write(
        ExpensesTableCompanion(deletedAt: Value(now), updatedAt: Value(now)),
      );
      await _outbox.softDelete(expensesSync.name, expenseId, now);
    });
    _onWrite();
  }

  Future<void> deletePersonalExpense(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(
        _db.personalExpensesTable,
      )..where((t) => t.id.equals(id))).write(
        PersonalExpensesTableCompanion(
          deletedAt: Value(now),
          updatedAt: Value(now),
        ),
      );
      await _outbox.softDelete(personalExpensesSync.name, id, now);
    });
    _onWrite();
  }
}

@Riverpod(keepAlive: true)
ExpenseRepository expenseRepository(Ref ref) => ExpenseRepository(
  ref.watch(appDatabaseProvider),
  onWrite: () => ref.read(syncSchedulerProvider).kick(),
);
