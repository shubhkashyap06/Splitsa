import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'data/remote/supabase_service.dart';
import 'main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppConfig.init();
  if (AppConfig.instance.demoMode) {
    throw StateError('DEMO mode is dev-only and must not ship in prod');
  }
  await SupabaseService.init();

  runApp(const ProviderScope(child: SplitsaApp()));
}
