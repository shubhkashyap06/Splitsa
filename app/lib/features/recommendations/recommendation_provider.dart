import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'recommendation_engine.dart';
import 'logic_engine/logic_recommendation_engine.dart';

part 'recommendation_provider.g.dart';

/// Provides the active [RecommendationEngine] implementation.
///
/// In v1, this is always [LogicRecommendationEngine].
/// In v2, this provider will check model_versions for an active ONNX model
/// and return [MlRecommendationEngine] when one is available — falling back
/// to [LogicRecommendationEngine] if the model download hasn't completed.
/// The UI never needs to know which implementation is active.
@Riverpod(keepAlive: true)
RecommendationEngine recommendationEngine(RecommendationEngineRef ref) {
  // v1: always logic engine
  return const LogicRecommendationEngine();
  // v2 will check model_versions and return MlRecommendationEngine if available
}
