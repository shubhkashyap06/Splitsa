import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';

part 'home_providers.g.dart';

/// Home hero card numbers for the current calendar month.
class BudgetSnapshot {
  const BudgetSnapshot({
    required this.budgetPaise,
    required this.spentPaise,
    required this.savedInPotsPaise,
    required this.daysLeft,
    required this.monthStart,
  });

  /// Null when the user hasn't set a budget yet.
  final int? budgetPaise;

  /// My share of shared expenses + my personal expenses this month.
  final int spentPaise;

  /// What I moved into pots this month.
  final int savedInPotsPaise;
  final int daysLeft;
  final DateTime monthStart;

  /// Budget minus what's already allocated (spent + saved). Can go negative
  /// when over budget — the UI shows that honestly rather than clamping.
  int? get spendablePaise =>
      budgetPaise == null ? null : budgetPaise! - spentPaise - savedInPotsPaise;

  double get allocatedFraction {
    final b = budgetPaise;
    if (b == null || b == 0) return 0;
    return ((spentPaise + savedInPotsPaise) / b).clamp(0.0, 1.0);
  }
}

@riverpod
BudgetSnapshot? budgetSnapshot(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  final profile = ref.watch(myProfileProvider).valueOrNull;
  final personal = ref.watch(myPersonalExpensesProvider).valueOrNull;
  final expenses = ref.watch(allExpensesProvider).valueOrNull;
  final splits = ref.watch(allSplitsProvider).valueOrNull;
  final contributions = ref.watch(allContributionsProvider).valueOrNull;
  if (me == null ||
      personal == null ||
      expenses == null ||
      splits == null ||
      contributions == null) {
    return null;
  }

  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month);
  final nextMonth = DateTime(now.year, now.month + 1);
  bool inMonth(DateTime d) => !d.isBefore(monthStart) && d.isBefore(nextMonth);

  var spent = personal
      .where((p) => inMonth(p.createdAt))
      .fold<int>(0, (s, p) => s + p.amountPaise);

  final liveExpenses = {
    for (final e in expenses)
      if (e.deletedAt == null && inMonth(e.createdAt)) e.id: e,
  };
  for (final s in splits) {
    if (s.userId == me && liveExpenses.containsKey(s.expenseId)) {
      spent += s.amountPaise;
    }
  }

  final saved = contributions
      .where((c) => c.userId == me && inMonth(c.createdAt))
      .fold<int>(0, (s, c) => s + c.amountPaise);

  return BudgetSnapshot(
    budgetPaise: profile?.monthlyBudgetPaise,
    spentPaise: spent,
    savedInPotsPaise: saved,
    daysLeft: nextMonth
        .difference(DateTime(now.year, now.month, now.day))
        .inDays,
    monthStart: monthStart,
  );
}
