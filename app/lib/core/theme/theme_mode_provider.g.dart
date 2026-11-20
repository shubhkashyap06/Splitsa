// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_mode_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appearanceSettingHash() => r'becec0e15926bb8405c49b5b2c468d19ddf4b931';

/// Appearance setting: System (follows the phone), Day or Night.
/// A per-device preference — stored locally, never synced to the server.
///
/// Copied from [AppearanceSetting].
@ProviderFor(AppearanceSetting)
final appearanceSettingProvider =
    NotifierProvider<AppearanceSetting, ThemeMode>.internal(
      AppearanceSetting.new,
      name: r'appearanceSettingProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$appearanceSettingHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$AppearanceSetting = Notifier<ThemeMode>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
