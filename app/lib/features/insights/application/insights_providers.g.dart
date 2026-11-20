// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'insights_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$insightsHash() => r'aa2b8c765af23a26b43c6ecfd121355c3ee20f4d';

/// Spend features + engine outputs, computed entirely from the local DB —
/// works identically offline on Android and the PWA (OFFLINE_SYNC.md §5).
///
/// Copied from [insights].
@ProviderFor(insights)
final insightsProvider = AutoDisposeFutureProvider<InsightsData?>.internal(
  insights,
  name: r'insightsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$insightsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef InsightsRef = AutoDisposeFutureProviderRef<InsightsData?>;
String _$nudgeTargetPotHash() => r'2571be69dc69ffd6452bc0c6ea7e66a4f2e23c2d';

/// The pot a "Move it" nudge sends money to: the user's first personal pot.
///
/// Copied from [nudgeTargetPot].
@ProviderFor(nudgeTargetPot)
final nudgeTargetPotProvider = AutoDisposeProvider<PotsTableData?>.internal(
  nudgeTargetPot,
  name: r'nudgeTargetPotProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$nudgeTargetPotHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef NudgeTargetPotRef = AutoDisposeProviderRef<PotsTableData?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
