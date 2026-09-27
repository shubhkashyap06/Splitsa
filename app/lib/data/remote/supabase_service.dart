/// Supabase client initialisation.
///
/// Call [SupabaseService.init] once in main_*.dart before runApp().
/// Access the client via [SupabaseService.client] anywhere in the app.
///
/// The Supabase client is used for:
///   • Auth (email OTP sign-in / sign-out)
///   • Realtime subscriptions (room expense feed)
///   • Edge Function calls (settle-intent, room-invite)
///
/// All reads that the UI displays come from the Drift local database
/// (offline-first). The Supabase client is never queried directly from
/// a widget or a provider that feeds the UI — that would break offline mode.
library;

import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/config/app_config.dart';

abstract final class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> init() async {
    await Supabase.initialize(
      url:    AppConfig.instance.supabaseUrl,
      anonKey: AppConfig.instance.supabasePublishableKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
  }
}
