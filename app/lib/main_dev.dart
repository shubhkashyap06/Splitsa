import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_config.dart';
import 'data/local/database.dart';
import 'data/local/demo_seed.dart';
import 'data/remote/supabase_service.dart';
import 'main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read --dart-define-from-file values
  AppConfig.init();

  // Initialize Supabase with the loaded config (no network needed here).
  await SupabaseService.init();

  final container = ProviderContainer();
  if (AppConfig.instance.demoMode) {
    // `--dart-define=DEMO=true`: sample data + simulated server, no sign-in.
    await seedDemoData(container.read(appDatabaseProvider));
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SplitsaApp()),
  );
}
