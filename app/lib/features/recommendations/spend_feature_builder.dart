/// SpendFeatureBuilder — computes [SpendFeatureData] from raw local database rows.
///
/// This is the bridge between the Drift database and the RecommendationEngine.
/// All computation is offline-first: it reads only from the local DB,
/// never makes a network call.
library;

import 'dart:math' as math;
import '../../data/local/database.dart';
import '../recommendations/recommendation_models.dart';

class SpendFeatureBuilder {
  const SpendFeatureBuilder();

  /// Build features from the user's personal + shared expenses.
  ///
  /// [personalExpenses] — all personal expenses for this user.
  /// [sharedExpenses] — all shared expenses where this user has a split.
  /// [sharedSplits] — the user's split rows from shared expenses.
  SpendFeatureData build({
    required List<PersonalExpensesTableData> personalExpenses,
    required List<ExpensesTableData> sharedExpenses,
    required List<ExpenseSplitsTableData> sharedSplits,
  }) {
    final now = DateTime.now();
    final fourWeeksAgo = now.subtract(const Duration(days: 28));

    // Merge all expenses into a flat list of (category, amountPaise, createdAt)
    final allTransactions = <_Transaction>[];

    for (final pe in personalExpenses) {
      if (pe.deletedAt != null) continue;
      allTransactions.add(_Transaction(
        category: pe.category,
        amountPaise: pe.amountPaise.toInt(),
        createdAt: pe.createdAt,
      ));
    }

    // For shared expenses, use the user's split amount (what they actually owe)
    final expenseMap = {for (final e in sharedExpenses) e.id: e};
    for (final split in sharedSplits) {
      if (split.deletedAt != null) continue;
      final expense = expenseMap[split.expenseId];
      if (expense == null || expense.deletedAt != null) continue;
      allTransactions.add(_Transaction(
        category: expense.category,
        amountPaise: split.amountPaise.toInt(),
        createdAt: expense.createdAt,
      ));
    }

    // Filter to last 4 weeks
    final recent = allTransactions.where((t) => t.createdAt.isAfter(fourWeeksAgo)).toList();

    // Group by week (0 = current week, 1 = last week, etc.)
    final weekBuckets = <int, List<_Transaction>>{};
    for (final t in recent) {
      final weekIndex = now.difference(t.createdAt).inDays ~/ 7;
      weekBuckets.putIfAbsent(weekIndex, () => []).add(t);
    }

    // Determine total weeks of history
    final oldestTransaction = allTransactions.isEmpty
        ? now
        : allTransactions.map((t) => t.createdAt).reduce((a, b) => a.isBefore(b) ? a : b);
    final totalWeeksOfHistory = math.max(1, now.difference(oldestTransaction).inDays ~/ 7);

    // Rolling 4-week average by category
    final catTotals = <String, List<int>>{}; // category -> [week0, week1, ...]
    for (int w = 0; w < 4; w++) {
      final weekTxns = weekBuckets[w] ?? [];
      final byCat = <String, int>{};
      for (final t in weekTxns) {
        byCat[t.category] = (byCat[t.category] ?? 0) + t.amountPaise;
      }
      for (final entry in byCat.entries) {
        catTotals.putIfAbsent(entry.key, () => [0, 0, 0, 0])[w] = entry.value;
      }
    }

    final rolling4wAvg = <String, int>{};
    for (final entry in catTotals.entries) {
      rolling4wAvg[entry.key] = entry.value.reduce((a, b) => a + b) ~/ 4;
    }

    // Last week's actual by category
    final lastWeekActual = <String, int>{};
    for (final t in (weekBuckets[0] ?? <_Transaction>[])) {
      lastWeekActual[t.category] = (lastWeekActual[t.category] ?? 0) + (t.amountPaise as int);
    }

    // Weekend vs weekday spend
    int weekendSpend = 0;
    int weekdaySpend = 0;
    for (final t in recent) {
      if (t.createdAt.weekday == DateTime.saturday || t.createdAt.weekday == DateTime.sunday) {
        weekendSpend += t.amountPaise;
      } else {
        weekdaySpend += t.amountPaise;
      }
    }

    // Category shares
    final totalSpend = recent.fold<int>(0, (s, t) => s + t.amountPaise);
    final categoryShares = <String, double>{};
    if (totalSpend > 0) {
      final catSpend = <String, int>{};
      for (final t in recent) {
        catSpend[t.category] = (catSpend[t.category] ?? 0) + t.amountPaise;
      }
      for (final entry in catSpend.entries) {
        categoryShares[entry.key] = entry.value / totalSpend;
      }
    }

    // Weekly totals excluding fixed costs
    final weeklyTotalsExclFixed = <int>[];
    for (int w = 0; w < 4; w++) {
      final weekTxns = weekBuckets[w] ?? [];
      final total = weekTxns
          .where((t) => !SpendFeatureData.fixedCategories.contains(t.category))
          .fold<int>(0, (s, t) => s + t.amountPaise);
      weeklyTotalsExclFixed.add(total);
    }

    // Max single transaction and median
    final sortedAmounts = recent.map((t) => t.amountPaise).toList()..sort();
    final maxSingleTransaction = sortedAmounts.isEmpty ? 0 : sortedAmounts.last;
    final medianTransaction = sortedAmounts.isEmpty
        ? 0
        : sortedAmounts[sortedAmounts.length ~/ 2];

    return SpendFeatureData(
      rolling4wAvgPaiseByCategory: rolling4wAvg,
      lastWeekActualPaiseByCategory: lastWeekActual,
      totalWeeksOfHistory: totalWeeksOfHistory,
      weekendSpendPaise: weekendSpend,
      weekdaySpendPaise: weekdaySpend,
      categoryShares: categoryShares,
      weeklyTotalsExclFixed: weeklyTotalsExclFixed,
      maxSingleTransactionPaise: maxSingleTransaction,
      medianTransactionPaise: medianTransaction,
    );
  }
}

class _Transaction {
  const _Transaction({
    required this.category,
    required this.amountPaise,
    required this.createdAt,
  });
  final String category;
  final int amountPaise;
  final DateTime createdAt;
}
