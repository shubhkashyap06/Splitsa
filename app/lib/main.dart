import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// The root widget of the application.
/// Environment initialization (AppConfig, Supabase, Drift) must happen
/// in the flavor entry points (main_dev.dart, etc) before calling runApp.
class SplitsaApp extends ConsumerWidget {
  const SplitsaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Splitsa',
      debugShowCheckedModeBanner: AppConfig.instance.isDev,
      theme: AppTheme.dark, // the app is always in dark mode per spec
      routerConfig: router,
    );
  }
}
