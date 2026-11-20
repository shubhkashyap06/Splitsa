/// AppConfig — reads all environment values injected via
/// `--dart-define-from-file=.env.<flavor>.json`.
///
/// Access anywhere with `AppConfig.instance` after [AppConfig.init] is called
/// in main_*.dart. Never read String.fromEnvironment() outside this file.
library;

enum AppEnvironment { dev, staging, prod }

class AppConfig {
  AppConfig._({
    required this.supabaseUrl,
    required this.supabasePublishableKey,
    required this.supabaseRedirectScheme,
    required this.environment,
    required this.webOrigin,
    required this.demoMode,
  });

  static AppConfig? _instance;

  /// Call once, early in main(), before runApp().
  static void init() {
    _instance = AppConfig._(
      supabaseUrl: const String.fromEnvironment('SUPABASE_URL'),
      supabasePublishableKey: const String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
      ),
      supabaseRedirectScheme: const String.fromEnvironment(
        'SUPABASE_REDIRECT_SCHEME',
        defaultValue: 'com.splitsa.app',
      ),
      environment: _parseEnv(
        const String.fromEnvironment('ENV', defaultValue: 'dev'),
      ),
      webOrigin: const String.fromEnvironment('APP_WEB_ORIGIN'),
      demoMode: const bool.fromEnvironment('DEMO'),
    );
    assert(
      !(_instance!.demoMode && _instance!.isProd),
      'DEMO mode must never be enabled in a prod build',
    );

    assert(
      _instance!.supabaseUrl.isNotEmpty,
      'SUPABASE_URL is empty — did you pass --dart-define-from-file=.env.<flavor>.json ?',
    );
    assert(
      _instance!.supabasePublishableKey.isNotEmpty,
      'SUPABASE_PUBLISHABLE_KEY is empty — did you pass --dart-define-from-file=.env.<flavor>.json ?',
    );
  }

  static AppConfig get instance {
    assert(
      _instance != null,
      'AppConfig.init() must be called before accessing AppConfig.instance',
    );
    return _instance!;
  }

  // ── Values ────────────────────────────────────────────────────────────────

  final String supabaseUrl;
  final String supabasePublishableKey;
  final String supabaseRedirectScheme;
  final AppEnvironment environment;

  /// Public origin of the deployed PWA (e.g. https://app.splitsa.in), used to
  /// build shareable `/join?code=` invite links. Empty → share the code only.
  final String webOrigin;

  /// Dev-only: `--dart-define=DEMO=true` skips sign-in, seeds sample data
  /// and swaps Supabase for an in-process simulated server, so every screen
  /// can be shown without a backend. Never true in prod (asserted above,
  /// and main_prod.dart refuses to start with it).
  final bool demoMode;

  bool get isDev => environment == AppEnvironment.dev;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isProd => environment == AppEnvironment.prod;

  /// Deep-link redirect URI for email OTP / magic-link callbacks.
  String get authRedirectUri => '$supabaseRedirectScheme://auth-callback';

  /// Whether push notification dispatch is configured.
  /// Gate any FCM/Web-Push credential usage behind this flag.
  /// Returns false until FCM server key is provided in the env JSON.
  bool get pushEnabled {
    // TODO: add PUSH_FCM_SERVER_KEY to env JSONs when push creds exist
    return false;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static AppEnvironment _parseEnv(String raw) => switch (raw) {
    'staging' => AppEnvironment.staging,
    'prod' => AppEnvironment.prod,
    _ => AppEnvironment.dev,
  };

  @override
  String toString() =>
      'AppConfig(env: $environment, url: $supabaseUrl, push: $pushEnabled)';
}
