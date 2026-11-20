import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/app_config.dart';
import 'demo_gateway.dart';
import 'remote_gateway.dart';
import 'supabase_service.dart';
import '../local/database.dart';

part 'session.g.dart';

/// The signed-in user's id, or null. Rebuilds on every auth state change.
/// Override in tests — nothing else in the app reads Supabase auth directly.
@Riverpod(keepAlive: true)
String? currentUserId(Ref ref) {
  if (AppConfig.instance.demoMode) return kDemoUserId;
  final auth = SupabaseService.client.auth;
  final sub = auth.onAuthStateChange.listen((event) {
    if (event.event == AuthChangeEvent.signedIn ||
        event.event == AuthChangeEvent.signedOut) {
      ref.invalidateSelf();
    }
  });
  ref.onDispose(sub.cancel);
  return auth.currentUser?.id;
}

/// Email of the signed-in user — used for type-to-confirm on deletion.
@riverpod
String? currentUserEmail(Ref ref) {
  ref.watch(currentUserIdProvider);
  if (AppConfig.instance.demoMode) return kDemoEmail;
  return SupabaseService.client.auth.currentUser?.email;
}

@Riverpod(keepAlive: true)
RemoteGateway remoteGateway(Ref ref) => AppConfig.instance.demoMode
    ? DemoRemoteGateway(ref.read(appDatabaseProvider))
    : SupabaseRemoteGateway(SupabaseService.client);
