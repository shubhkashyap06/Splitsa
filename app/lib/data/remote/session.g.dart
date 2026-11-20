// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$currentUserIdHash() => r'49f9144e1b76ee4892e95f4bf111ef7eba911c16';

/// The signed-in user's id, or null. Rebuilds on every auth state change.
/// Override in tests — nothing else in the app reads Supabase auth directly.
///
/// Copied from [currentUserId].
@ProviderFor(currentUserId)
final currentUserIdProvider = Provider<String?>.internal(
  currentUserId,
  name: r'currentUserIdProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserIdHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserIdRef = ProviderRef<String?>;
String _$currentUserEmailHash() => r'e8361f73f694d18a70ad3bf33c0faa535198665f';

/// Email of the signed-in user — used for type-to-confirm on deletion.
///
/// Copied from [currentUserEmail].
@ProviderFor(currentUserEmail)
final currentUserEmailProvider = AutoDisposeProvider<String?>.internal(
  currentUserEmail,
  name: r'currentUserEmailProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$currentUserEmailHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentUserEmailRef = AutoDisposeProviderRef<String?>;
String _$remoteGatewayHash() => r'5afe7002945aff9283b91dedfef286440a326a9b';

/// See also [remoteGateway].
@ProviderFor(remoteGateway)
final remoteGatewayProvider = Provider<RemoteGateway>.internal(
  remoteGateway,
  name: r'remoteGatewayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$remoteGatewayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RemoteGatewayRef = ProviderRef<RemoteGateway>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
