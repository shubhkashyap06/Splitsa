/// RecommendationEngine — abstract interface for spend-pattern analysis.
///
/// v1 is fulfilled by [LogicRecommendationEngine] (pure Dart, no ML).
/// v2 will fulfill this same interface using ONNX models downloaded
/// from the model_versions table — the UI code never changes.
///
/// See docs/PRODUCT_LOGIC.md §3 for the full algorithm specification.
library;

import 'recommendation_models.dart';

export 'recommendation_models.dart';

abstract class RecommendationEngine {
  const RecommendationEngine();

  /// Classify the user's spending persona based on the last 4 weeks of data.
  ///
  /// Returns [SpendPersona.coldStart] when the user has fewer than
  /// [kColdStartWeeks] weeks of history.
  Future<SpendPersona> classifyPersona(SpendFeatureData features);

  /// Generate a savings nudge, or null if no actionable nudge this week.
  ///
  /// Returns null when:
  ///   • No surplus detected (actual ≥ rolling average)
  ///   • Surplus < ₹200 (below nudge floor)
  ///   • Nudge was already shown this week (caller must guard)
  Future<SavingsNudge?> generateNudge(SpendFeatureData features);

  /// Compute the spending summary for the given period.
  /// Used for the Insights tab's "this month" and "last month" views.
  Future<SpendingSummary> computeSpendingSummary(SpendFeatureData features);
}

/// Minimum weeks of history before the rolling average is trustworthy.
/// Below this threshold, use the cold-start heuristic instead.
const int kColdStartWeeks = 4;

/// Fraction of detected surplus recommended to save (never 100%).
/// Conservative: leaves buffer for unexpected end-of-week spend.
const double kSavingsSafetyFraction = 0.70;

/// Nudge floor in paise — amounts below ₹200 aren't actionable.
const int kNudgeFloorPaise = 20000;
