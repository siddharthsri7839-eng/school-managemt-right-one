/// SINGLE SOURCE OF TRUTH for per-client values in the staff app.
///
/// When building an APK for a new client, edit ONLY this file (server URL + the
/// display text below), or override at build time with --dart-define, e.g.:
///   flutter build apk --dart-define=API_ORIGIN=https://yourschool.com \
///                      --dart-define=APP_NAME="Heritage Staff"
///
/// NOTE: when dynamic branding is ON, the live app name comes from the backend;
/// the values below are the offline/default fallbacks.
class AppConfig {
  /// Backend server origin (scheme + host). Everything else is derived from it.
  static const String origin = String.fromEnvironment(
    'API_ORIGIN',
    defaultValue: 'https://multischoolv2.projectworlds.com',
  );

  /// Base URL for API calls (trailing slash preserved for the existing client).
  static const String apiBaseUrl = '$origin/api/v1/';

  /// Base URL for public storage files.
  static const String storageBaseUrl = origin;

  // ── App display text ───────────────────────────────────────────────────────
  /// Brand / app name — app bar, branding fallback.
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Staff PWS',
  );

  /// Big headline on the splash screen.
  static const String splashTitle = String.fromEnvironment(
    'APP_SPLASH_TITLE',
    defaultValue: 'Staff Portal',
  );

  /// Subtitle under the logo on the login screen.
  static const String loginSubtitle = String.fromEnvironment(
    'APP_SUBTITLE',
    defaultValue: 'Staff Portal Login',
  );

  /// "Powered by" footer on the splash screen.
  static const String poweredBy = String.fromEnvironment(
    'APP_POWERED_BY',
    defaultValue: 'Powered by ProjectWorlds',
  );
}
