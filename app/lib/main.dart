import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_mode_provider.dart';
import 'data/sync/sync_providers.dart';

/// The root widget. Environment initialization (AppConfig, Supabase) happens
/// in the flavor entry points (main_dev.dart, …) before runApp.
class SplitsaApp extends ConsumerStatefulWidget {
  const SplitsaApp({super.key});

  @override
  ConsumerState<SplitsaApp> createState() => _SplitsaAppState();
}

class _SplitsaAppState extends ConsumerState<SplitsaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// "Match my phone" follows the OS switching to dark at sunset.
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    // Starts the background sync cadence (sign-in, resume, every 60s, after
    // local writes). Lives for the app's lifetime — keepAlive provider.
    ref.watch(syncSchedulerProvider);

    final mode = ref.watch(appearanceSettingProvider);
    final platformDark =
        WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
    final night =
        mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    final palette = night ? SplitsaPalette.night : SplitsaPalette.day;

    // Every `AppColors.x` reads this; the key below rebuilds the whole tree
    // on a switch so no widget keeps a stale colour.
    AppColors.current = palette;

    return MaterialApp.router(
      key: ValueKey(palette.brightness),
      title: 'Splitsa',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(palette),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
