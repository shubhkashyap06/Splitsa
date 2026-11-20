import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'theme_mode_provider.g.dart';

const _key = 'appearance';

/// Appearance setting: System (follows the phone), Day or Night.
/// A per-device preference — stored locally, never synced to the server.
@Riverpod(keepAlive: true)
class AppearanceSetting extends _$AppearanceSetting {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_key);
      final mode = ThemeMode.values.where((m) => m.name == saved).firstOrNull;
      if (mode != null && mode != state) state = mode;
    } catch (_) {
      // Storage unavailable (private mode etc.) — stay on System.
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, mode.name);
    } catch (_) {}
  }
}

String appearanceLabel(ThemeMode m) => switch (m) {
  ThemeMode.system => 'Match my phone',
  ThemeMode.light => 'Day',
  ThemeMode.dark => 'Night',
};
