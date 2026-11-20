// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$syncEngineHash() => r'6b044056208c0eb68c1e650c37e17f308554b9b3';

/// See also [syncEngine].
@ProviderFor(syncEngine)
final syncEngineProvider = Provider<SyncEngine>.internal(
  syncEngine,
  name: r'syncEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncEngineRef = ProviderRef<SyncEngine>;
String _$syncSchedulerHash() => r'e90092cafbd8139968dddf6bccd67998caae7f79';

/// See also [syncScheduler].
@ProviderFor(syncScheduler)
final syncSchedulerProvider = Provider<SyncScheduler>.internal(
  syncScheduler,
  name: r'syncSchedulerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncSchedulerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncSchedulerRef = ProviderRef<SyncScheduler>;
String _$syncStatusHash() => r'39ccbddee0b26c819900c52093e8bc1399c78586';

/// See also [syncStatus].
@ProviderFor(syncStatus)
final syncStatusProvider = AutoDisposeStreamProvider<SyncStatus>.internal(
  syncStatus,
  name: r'syncStatusProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$syncStatusHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SyncStatusRef = AutoDisposeStreamProviderRef<SyncStatus>;
String _$pendingRowIdsHash() => r'e25359f2f0c05964a31c95ce78aa647c9255a807';

/// Row ids with an unsynced local write — drives the "pending" marker.
///
/// Copied from [pendingRowIds].
@ProviderFor(pendingRowIds)
final pendingRowIdsProvider = AutoDisposeStreamProvider<Set<String>>.internal(
  pendingRowIds,
  name: r'pendingRowIdsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$pendingRowIdsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PendingRowIdsRef = AutoDisposeStreamProviderRef<Set<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
