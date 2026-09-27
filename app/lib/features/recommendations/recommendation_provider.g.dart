// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recommendation_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recommendationEngineHash() =>
    r'e9b507b9306919497b45bc0f42d2710ab399b2e3';

/// Provides the active [RecommendationEngine] implementation.
///
/// In v1, this is always [LogicRecommendationEngine].
/// In v2, this provider will check model_versions for an active ONNX model
/// and return [MlRecommendationEngine] when one is available — falling back
/// to [LogicRecommendationEngine] if the model download hasn't completed.
/// The UI never needs to know which implementation is active.
///
/// Copied from [recommendationEngine].
@ProviderFor(recommendationEngine)
final recommendationEngineProvider = Provider<RecommendationEngine>.internal(
  recommendationEngine,
  name: r'recommendationEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$recommendationEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecommendationEngineRef = ProviderRef<RecommendationEngine>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
