// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'room_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$ledgerHash() => r'9855efae78d510076fa4d46cc3447d33e9ebcce8';

/// See also [_ledger].
@ProviderFor(_ledger)
final _ledgerProvider = AutoDisposeProvider<_Ledger?>.internal(
  _ledger,
  name: r'_ledgerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$ledgerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef _LedgerRef = AutoDisposeProviderRef<_Ledger?>;
String _$roomSummariesHash() => r'9498c956e275605e44bef4c5944f19f8f4ac8af2';

/// All my rooms with my balance in each. Null while loading.
///
/// Copied from [roomSummaries].
@ProviderFor(roomSummaries)
final roomSummariesProvider = AutoDisposeProvider<List<RoomSummary>?>.internal(
  roomSummaries,
  name: r'roomSummariesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$roomSummariesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RoomSummariesRef = AutoDisposeProviderRef<List<RoomSummary>?>;
String _$roomDetailHash() => r'3a77c662d76b71bee4a6554422ffe97b663bef67';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [roomDetail].
@ProviderFor(roomDetail)
const roomDetailProvider = RoomDetailFamily();

/// See also [roomDetail].
class RoomDetailFamily extends Family<RoomDetail?> {
  /// See also [roomDetail].
  const RoomDetailFamily();

  /// See also [roomDetail].
  RoomDetailProvider call(String roomId) {
    return RoomDetailProvider(roomId);
  }

  @override
  RoomDetailProvider getProviderOverride(
    covariant RoomDetailProvider provider,
  ) {
    return call(provider.roomId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'roomDetailProvider';
}

/// See also [roomDetail].
class RoomDetailProvider extends AutoDisposeProvider<RoomDetail?> {
  /// See also [roomDetail].
  RoomDetailProvider(String roomId)
    : this._internal(
        (ref) => roomDetail(ref as RoomDetailRef, roomId),
        from: roomDetailProvider,
        name: r'roomDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$roomDetailHash,
        dependencies: RoomDetailFamily._dependencies,
        allTransitiveDependencies: RoomDetailFamily._allTransitiveDependencies,
        roomId: roomId,
      );

  RoomDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.roomId,
  }) : super.internal();

  final String roomId;

  @override
  Override overrideWith(RoomDetail? Function(RoomDetailRef provider) create) {
    return ProviderOverride(
      origin: this,
      override: RoomDetailProvider._internal(
        (ref) => create(ref as RoomDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        roomId: roomId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<RoomDetail?> createElement() {
    return _RoomDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is RoomDetailProvider && other.roomId == roomId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, roomId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin RoomDetailRef on AutoDisposeProviderRef<RoomDetail?> {
  /// The parameter `roomId` of this provider.
  String get roomId;
}

class _RoomDetailProviderElement extends AutoDisposeProviderElement<RoomDetail?>
    with RoomDetailRef {
  _RoomDetailProviderElement(super.provider);

  @override
  String get roomId => (origin as RoomDetailProvider).roomId;
}

String _$myDebtsHash() => r'85f6d1c0173d3d99e4a4e98c8637a4a8c1198ec9';

/// See also [myDebts].
@ProviderFor(myDebts)
final myDebtsProvider = AutoDisposeProvider<MyDebts?>.internal(
  myDebts,
  name: r'myDebtsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$myDebtsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MyDebtsRef = AutoDisposeProviderRef<MyDebts?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
