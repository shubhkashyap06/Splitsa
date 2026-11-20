// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pot_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$potViewsHash() => r'16555d880356c6f969181edc89573c2a3634f1b6';

/// Personal pots first (the first one is "Your Potli"), then group pots.
///
/// Copied from [potViews].
@ProviderFor(potViews)
final potViewsProvider = AutoDisposeProvider<List<PotView>?>.internal(
  potViews,
  name: r'potViewsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$potViewsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PotViewsRef = AutoDisposeProviderRef<List<PotView>?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
