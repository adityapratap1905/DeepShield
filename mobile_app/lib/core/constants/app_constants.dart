/// DeepShield App Constants
abstract class AppConstants {
  AppConstants._();

  static const String appName = 'DeepShield Social';
  static const String appVersion = '1.0.0';
  static const String appTagline = 'Detect. Discuss. Protect.';

  // ── Shared Preferences Keys ─────────────────────────────────────
  static const String keyIsLoggedIn = 'is_logged_in';
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyThemeMode =
      'theme_mode'; // 'dark' | 'light' | 'system'
  static const String keyUserEmail = 'user_email';
  static const String keyUserId = 'user_id';
  static const String keyUserName = 'user_name';
  static const String keyUserCreatedAt = 'user_created_at';
  static const String keyScanHistory = 'scan_history_v1';

  // ── Animation Durations ─────────────────────────────────────────
  static const Duration durationFast = Duration(milliseconds: 150);
  static const Duration durationNormal = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);
  static const Duration durationExtraSlow = Duration(milliseconds: 800);

  // ── Pagination ──────────────────────────────────────────────────
  static const int pageSize = 20;

  // ── Timeouts ────────────────────────────────────────────────────
  static const int connectTimeout = 30; // seconds
  static const int receiveTimeout = 60; // seconds

  // ── Score thresholds ────────────────────────────────────────────
  static const int scoreThresholdSafe = 80;
  static const int scoreThresholdWarning = 50;

  // ── URL Regex ───────────────────────────────────────────────────
  static final RegExp urlRegex = RegExp(
    r'^(https?:\/\/)?([\da-z.-]+)\.([a-z.]{2,6})([\/\w .-]*)*\/?$',
    caseSensitive: false,
  );
}
