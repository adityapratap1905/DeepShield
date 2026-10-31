import 'package:flutter/foundation.dart';

/// DeepShield API Endpoint Constants
///
/// Base URL points to the FastAPI backend.
/// Change [baseUrl] to switch environments.
abstract class ApiConstants {
  ApiConstants._();

  // ── Base URL ────────────────────────────────────────────────────
  /// Override with --dart-define for a physical device or another environment.
  /// Android emulators use the host's loopback alias; USB phones can use adb reverse.
  static const String _baseUrlOverride =
      String.fromEnvironment('DEEPSHIELD_API_BASE_URL');
  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) return _baseUrlOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  // ── Auth ────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String resetPassword = '/auth/reset-password';
  static const String refreshToken = '/auth/refresh';
  static const String logout = '/auth/logout';
  static const String currentUser = '/auth/me';
  static const String myProfile = '/profiles/me';
  static const String socialFeed = '/social/feed';
  static const String socialPosts = '/social/posts';
  static const String shareScanReport = '/scan-reports/share';
  static const String communities = '/communities';

  // ── Scan ────────────────────────────────────────────────────────
  static const String scanUrl = '/scan/url';
  static const String scanFile = '/scan/file';
  static const String scanImage = '/scan/image';
  static const String detectVideo = '/api/v2/detect/video';
  static const String scanQr = '/scan/qr';

  // ── History ─────────────────────────────────────────────────────
  static const String history = '/history';
  static String historyItem(String id) => '/history/$id';

  // ── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';
  static String markNotificationRead(String id) => '/notifications/$id/read';
  static const String markAllRead = '/notifications/read-all';

  // ── Profile ─────────────────────────────────────────────────────
  static const String profile = '/profile';
  static const String updateProfile = '/profile/update';
  static const String changePassword = '/profiles/me/password';
  static const String uploadAvatar = '/profiles/me/avatar';

  // ── Header Keys ─────────────────────────────────────────────────
  static const String headerAuthorization = 'Authorization';
  static const String headerContentType = 'Content-Type';
  static const String headerAccept = 'Accept';

  // ── Error Codes ──────────────────────────────────────────────────
  static const int statusUnauthorized = 401;
  static const int statusForbidden = 403;
  static const int statusNotFound = 404;
  static const int statusServerError = 500;
}
