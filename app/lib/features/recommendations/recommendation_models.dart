/// Data models for the RecommendationEngine interface.
library;

// ── Enums ──────────────────────────────────────────────────────────────────

enum SpendPersona {
  /// Fewer than kColdStartWeeks weeks of data — no pattern detected yet.
  coldStart,

  /// Spends regularly within a narrow band — savings nudges are reliable.
  consistent,

  /// Weekend spend systematically > 60% of weekday spend.
  weekendSpender,

  /// High spend volatility (excl. fixed costs) + large single transactions.
  bulkBuyer,

  /// High fixed-cost share (rent, bills) — variable spend is actually low.
  highFixedCost,
}

// ── Feature input ──────────────────────────────────────────────────────────

class SpendFeatureData {
  const SpendFeatureData({
    required this.rolling4wAvgPaiseByCategory,
    required this.lastWeekActualPaiseByCategory,
    required this.totalWeeksOfHistory,
    required this.weekendSpendPaise,
    required this.weekdaySpendPaise,
    required this.categoryShares,
    required this.weeklyTotalsExclFixed,
    required this.maxSingleTransactionPaise,
    required this.medianTransactionPaise,
  });

  /// Rolling 4-week average spend per category, in paise.
  final Map<String, int> rolling4wAvgPaiseByCategory;

  /// Last week's actual spend per category, in paise.
  final Map<String, int> lastWeekActualPaiseByCategory;

  /// How many full weeks of expense history exist for this user.
  final int totalWeeksOfHistory;

  /// Total weekend spend over the 4-week window, in paise.
  final int weekendSpendPaise;

  /// Total weekday spend over the 4-week window, in paise.
  final int weekdaySpendPaise;

  /// Each category's proportion of total spend (0.0–1.0).
  final Map<String, double> categoryShares;

  /// Per-week totals excluding fixed-cost categories, in paise.
  final List<int> weeklyTotalsExclFixed;

  /// Largest single transaction in the 4-week window, in paise.
  final int maxSingleTransactionPaise;

  /// User's own median transaction size, in paise.
  final int medianTransactionPaise;

  /// Fixed-cost category keys — excluded from volatility calculation.
  static const fixedCategories = {
    'rent', 'electricity', 'wifi', 'subscriptions', 'gas',
  };

  /// Weekend/weekday ratio. > 0.6 → weekendSpender persona.
  double get weekendWeekdayRatio =>
      weekdaySpendPaise == 0 ? 0 : weekendSpendPaise / weekdaySpendPaise;

  /// Standard deviation of weekly totals (excl. fixed costs).
  double get spendVolatility {
    if (weeklyTotalsExclFixed.isEmpty) return 0;
    final mean = weeklyTotalsExclFixed.reduce((a, b) => a + b) /
        weeklyTotalsExclFixed.length;
    final variance = weeklyTotalsExclFixed
        .map((t) => (t - mean) * (t - mean))
        .reduce((a, b) => a + b) /
        weeklyTotalsExclFixed.length;
    return variance > 0 ? variance.sqrt() : 0;
  }

  /// Ratio of largest single transaction to user's own median.
  double get maxToMedianRatio =>
      medianTransactionPaise == 0
          ? 0
          : maxSingleTransactionPaise / medianTransactionPaise;

  int get totalActualPaise =>
      lastWeekActualPaiseByCategory.values.fold(0, (s, v) => s + v);

  int get totalAvgPaise =>
      rolling4wAvgPaiseByCategory.values.fold(0, (s, v) => s + v);

  /// Surplus this week: positive = underspent vs. rolling average.
  int get surplusPaise => totalAvgPaise - totalActualPaise;

  double get fixedCostShare =>
      categoryShares.entries
          .where((e) => fixedCategories.contains(e.key))
          .fold(0.0, (s, e) => s + e.value);
}

extension on double {
  double sqrt() {
    if (this <= 0) return 0;
    double x = this;
    double root = x / 2;
    for (int i = 0; i < 50; i++) {
      root = (root + x / root) / 2;
    }
    return root;
  }
}

// ── Output models ──────────────────────────────────────────────────────────

class SavingsNudge {
  const SavingsNudge({
    required this.recommendedAmountPaise,
    required this.headline,
    required this.subtext,
    required this.persona,
    required this.targetCategory,
  });

  final int recommendedAmountPaise;
  final String headline;
  final String subtext;
  final SpendPersona persona;

  /// The category where the underspend was detected.
  final String targetCategory;
}

class SpendingSummary {
  const SpendingSummary({
    required this.totalPaise,
    required this.byCategory,
    required this.weeklyTrend,
    required this.topCategory,
    required this.vsLastPeriodPct,
  });

  /// Total spend in the period, in paise.
  final int totalPaise;

  /// Per-category totals, in paise.
  final Map<String, int> byCategory;

  /// Per-week totals in chronological order, in paise.
  final List<int> weeklyTrend;

  /// Highest-spend category key.
  final String topCategory;

  /// (this_period - last_period) / last_period. Positive = more spent.
  final double vsLastPeriodPct;
}
