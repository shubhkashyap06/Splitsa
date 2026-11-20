import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/local/database.dart';
import '../../../data/local/local_streams.dart';
import '../../../data/remote/session.dart';
import '../../recommendations/recommendation_engine.dart';
import '../../recommendations/recommendation_provider.dart';
import '../../recommendations/spend_feature_builder.dart';

part 'insights_providers.g.dart';

class InsightsData {
  const InsightsData({
    required this.features,
    required this.persona,
    required this.summary,
    required this.nudge,
  });
  final SpendFeatureData features;
  final SpendPersona persona;
  final SpendingSummary summary;
  final SavingsNudge? nudge;

  /// Last 7 days, all categories (split shares + personal).
  int get thisWeekPaise =>
      features.weeklyTotalsAll.isEmpty ? 0 : features.weeklyTotalsAll[0];

  /// The 7 days before that.
  int get lastWeekPaise =>
      features.weeklyTotalsAll.length < 2 ? 0 : features.weeklyTotalsAll[1];

  /// Oldest → newest, for the bar chart.
  List<int> get weeklyTrendOldestFirst =>
      features.weeklyTotalsAll.reversed.toList();

  /// (this − last) / last, or null when last week had no spend.
  double? get weekOverWeek => lastWeekPaise == 0
      ? null
      : (thisWeekPaise - lastWeekPaise) / lastWeekPaise;
}

/// Spend features + engine outputs, computed entirely from the local DB —
/// works identically offline on Android and the PWA (OFFLINE_SYNC.md §5).
@riverpod
Future<InsightsData?> insights(Ref ref) async {
  final me = ref.watch(currentUserIdProvider);
  final personal = ref.watch(myPersonalExpensesProvider).valueOrNull;
  final expenses = ref.watch(allExpensesProvider).valueOrNull;
  final splits = ref.watch(allSplitsProvider).valueOrNull;
  if (me == null || personal == null || expenses == null || splits == null) {
    return null;
  }

  final features = const SpendFeatureBuilder().build(
    personalExpenses: personal,
    sharedExpenses: expenses,
    sharedSplits: splits.where((s) => s.userId == me).toList(),
  );
  final engine = ref.watch(recommendationEngineProvider);
  return InsightsData(
    features: features,
    persona: await engine.classifyPersona(features),
    summary: await engine.computeSpendingSummary(features),
    nudge: await engine.generateNudge(features),
  );
}

/// The pot a "Move it" nudge sends money to: the user's first personal pot.
@riverpod
PotsTableData? nudgeTargetPot(Ref ref) {
  final me = ref.watch(currentUserIdProvider);
  final pots = ref.watch(allPotsProvider).valueOrNull ?? const [];
  return pots
      .where((p) => p.ownerType == 'personal' && p.userId == me)
      .firstOrNull;
}

String personaLabel(SpendPersona p) => switch (p) {
  SpendPersona.weekendSpender => 'Weekend Spender 🎈',
  SpendPersona.bulkBuyer => 'Bulk Buyer 🛒',
  SpendPersona.consistent => 'Steady Spender 📊',
  SpendPersona.highFixedCost => 'Fixed-Cost Heavy 🏠',
  SpendPersona.coldStart => 'Just getting started ✨',
};

String personaExplainer(SpendPersona p, SpendFeatureData f) => switch (p) {
  SpendPersona.weekendSpender =>
    '${(f.weekendSpendPaise * 100 / (f.weekendSpendPaise + f.weekdaySpendPaise).clamp(1, 1 << 62)).round()}% of your spend lands on weekends. Small weekday habits could pad your pots nicely.',
  SpendPersona.bulkBuyer =>
    'A few big spends drive most of your month. Spacing them out keeps your weeks smoother.',
  SpendPersona.consistent =>
    'Your weeks look steady — which makes savings nudges reliable for you.',
  SpendPersona.highFixedCost =>
    'Rent and bills are most of your spend, so your day-to-day is actually lean.',
  SpendPersona.coldStart =>
    'Log a few weeks of spends and your persona sharpens up. Nothing is locked — it just gets more precise.',
};
