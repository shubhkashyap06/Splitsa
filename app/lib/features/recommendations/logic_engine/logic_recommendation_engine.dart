/// LogicRecommendationEngine — v1 deterministic recommendation engine.
///
/// Fulfils the [RecommendationEngine] interface using pure Dart rules
/// derived from docs/PRODUCT_LOGIC.md §3.
///
/// This class has NO dependency on any ML library, ONNX runtime, or
/// third-party AI API — it is the sole recommendation source in v1.
/// It will be replaced (not modified) by MlRecommendationEngine in v2
/// once the ML pipeline is trained.
///
/// Algorithm summary (full details in docs/PRODUCT_LOGIC.md §3):
///   1. Classify persona using rolling 4-week features
///   2. Detect surplus = rolling_avg - actual_last_week
///   3. Recommend saving 70% of surplus (conservative — leaves buffer)
///   4. Select nudge copy from the persona-specific copy table
///   5. Return null if surplus < ₹200 or history < 4 weeks (cold start)
library;

import '../recommendation_engine.dart';

class LogicRecommendationEngine implements RecommendationEngine {
  const LogicRecommendationEngine();

  // ── RecommendationEngine implementation ───────────────────────────────────

  @override
  Future<SpendPersona> classifyPersona(SpendFeatureData features) async {
    if (features.totalWeeksOfHistory < kColdStartWeeks) {
      return SpendPersona.coldStart;
    }

    // Fixed-cost share > 65% of total spend
    if (features.fixedCostShare > 0.65) {
      return SpendPersona.highFixedCost;
    }

    // Weekend/weekday ratio > 0.6 (more than 60% as much on weekends as weekdays)
    if (features.weekendWeekdayRatio > 0.6) {
      return SpendPersona.weekendSpender;
    }

    // High volatility + large single transactions
    // Volatility threshold: > 40% of mean weekly spend excl. fixed costs
    final meanWeeklyExclFixed = features.weeklyTotalsExclFixed.isEmpty
        ? 0
        : features.weeklyTotalsExclFixed.reduce((a, b) => a + b) ~/
            features.weeklyTotalsExclFixed.length;
    final volatilityPct = meanWeeklyExclFixed == 0
        ? 0
        : features.spendVolatility / meanWeeklyExclFixed;

    if (volatilityPct > 0.40 && features.maxToMedianRatio > 2.0) {
      return SpendPersona.bulkBuyer;
    }

    return SpendPersona.consistent;
  }

  @override
  Future<SavingsNudge?> generateNudge(SpendFeatureData features) async {
    // No nudge for cold-start users
    if (features.totalWeeksOfHistory < kColdStartWeeks) return null;

    final surplus = features.surplusPaise;
    if (surplus < kNudgeFloorPaise) return null; // < ₹200 — not actionable

    final recommended = (surplus * kSavingsSafetyFraction).round();
    final persona = await classifyPersona(features);

    // Find the category with the biggest underspend this week
    String topSurplusCategory = 'other';
    int topSurplusAmount = 0;
    for (final entry in features.rolling4wAvgPaiseByCategory.entries) {
      final avg    = entry.value;
      final actual = features.lastWeekActualPaiseByCategory[entry.key] ?? 0;
      final diff   = avg - actual;
      if (diff > topSurplusAmount) {
        topSurplusAmount = diff;
        topSurplusCategory = entry.key;
      }
    }

    final copy = _nudgeCopy(persona, topSurplusCategory, recommended);
    return SavingsNudge(
      recommendedAmountPaise: recommended,
      headline:               copy.headline,
      subtext:                copy.subtext,
      persona:                persona,
      targetCategory:         topSurplusCategory,
    );
  }

  @override
  Future<SpendingSummary> computeSpendingSummary(SpendFeatureData features) async {
    final byCategory = Map<String, int>.from(features.lastWeekActualPaiseByCategory);
    final total      = byCategory.values.fold(0, (s, v) => s + v);

    String topCategory = 'other';
    int topAmount = 0;
    for (final entry in byCategory.entries) {
      if (entry.value > topAmount) {
        topAmount = entry.value;
        topCategory = entry.key;
      }
    }

    final avgTotal = features.totalAvgPaise;
    final vsLastPct = avgTotal == 0
        ? 0.0
        : (total - avgTotal) / avgTotal;

    return SpendingSummary(
      totalPaise:      total,
      byCategory:      byCategory,
      weeklyTrend:     features.weeklyTotalsExclFixed,
      topCategory:     topCategory,
      vsLastPeriodPct: vsLastPct,
    );
  }

  // ── Nudge copy table ───────────────────────────────────────────────────────
  // Each persona + category pair maps to headline/subtext copy.
  // Full copy strings per docs/PRODUCT_LOGIC.md §3 "Nudge copy".

  ({String headline, String subtext}) _nudgeCopy(
    SpendPersona persona,
    String category,
    int recommendedPaise,
  ) {
    final rupees = (recommendedPaise / 100).round();
    final amount = '₹$rupees';

    return switch (persona) {
      SpendPersona.weekendSpender => (
        headline: 'Quieter week, louder savings?',
        subtext:
            'You spent less on ${_categoryName(category)} this week. Move $amount to your Potli before the weekend hits.',
      ),
      SpendPersona.bulkBuyer => (
        headline: 'Light week — stash the difference',
        subtext:
            'Your bulk spending stayed low this week. $amount is sitting idle — your Potli could use it.',
      ),
      SpendPersona.highFixedCost => (
        headline: 'Your variable spend dipped',
        subtext:
            'Fixed bills aside, you spent less on ${_categoryName(category)}. $amount is free — save it?',
      ),
      SpendPersona.consistent => (
        headline: 'You came in under budget',
        subtext:
            'Spent less on ${_categoryName(category)} than usual. $amount available — move it to savings?',
      ),
      SpendPersona.coldStart => (
        headline: 'Nice — you spent less this week',
        subtext: '$amount is available to save. Tap to move it to your Potli.',
      ),
    };
  }

  String _categoryName(String key) => switch (key) {
    'food'          => 'food',
    'travel'        => 'travel',
    'entertainment' => 'entertainment',
    'home'          => 'home expenses',
    'health'        => 'health',
    'shopping'      => 'shopping',
    _               => 'spending',
  };
}
