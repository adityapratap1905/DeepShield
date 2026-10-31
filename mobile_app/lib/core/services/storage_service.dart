import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// Unified local storage service.
///
/// - Sensitive data (tokens) → FlutterSecureStorage (encrypted keychain/keystore)
/// - Preferences → SharedPreferences
class StorageService {
  StorageService._();
  static StorageService? _instance;
  static StorageService get instance => _instance ??= StorageService._();

  late SharedPreferences _prefs;
  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  bool _initialized = false;

  /// Must be called once before first use (in main())
  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ── Secure Token Storage ─────────────────────────────────────────
  Future<void> saveToken(String token) async {
    await _secure.write(key: AppConstants.keyAccessToken, value: token);
  }

  Future<String?> getToken() async {
    return _secure.read(key: AppConstants.keyAccessToken);
  }

  Future<void> deleteToken() async {
    await _secure.delete(key: AppConstants.keyAccessToken);
  }

  Future<void> clearAuthSession() async {
    await deleteToken();
    await setLoggedIn(false);
    await saveUserInfo(name: '', email: '', id: '');
    await _prefs.remove(AppConstants.keyUserCreatedAt);
  }

  // ── Auth State ───────────────────────────────────────────────────
  Future<void> setLoggedIn(bool value) async {
    await _prefs.setBool(AppConstants.keyIsLoggedIn, value);
  }

  bool get isLoggedIn => _prefs.getBool(AppConstants.keyIsLoggedIn) ?? false;

  // ── Onboarding ──────────────────────────────────────────────────
  Future<void> setOnboardingDone() async {
    await _prefs.setBool(AppConstants.keyOnboardingDone, true);
  }

  bool get isOnboardingDone =>
      _prefs.getBool(AppConstants.keyOnboardingDone) ?? false;

  // ── Theme ────────────────────────────────────────────────────────
  Future<void> saveThemeMode(String mode) async {
    await _prefs.setString(AppConstants.keyThemeMode, mode);
  }

  String get themeMode =>
      _prefs.getString(AppConstants.keyThemeMode) ?? 'light';

  // ── User Info ────────────────────────────────────────────────────
  Future<void> saveUserInfo(
      {required String name,
      required String email,
      required String id,
      String? createdAt}) async {
    await _prefs.setString(AppConstants.keyUserName, name);
    await _prefs.setString(AppConstants.keyUserEmail, email);
    await _prefs.setString(AppConstants.keyUserId, id);
    if (createdAt != null && createdAt.isNotEmpty) {
      await _prefs.setString(AppConstants.keyUserCreatedAt, createdAt);
    }
  }

  String get userName => _prefs.getString(AppConstants.keyUserName) ?? 'User';
  String get userEmail => _prefs.getString(AppConstants.keyUserEmail) ?? '';
  String get userId => _prefs.getString(AppConstants.keyUserId) ?? '';

  // ── Generic Helpers ──────────────────────────────────────────────
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  String? getString(String key) => _prefs.getString(key);

  Future<void> setBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  bool? getBool(String key) => _prefs.getBool(key);

  /// Clear all data (logout)
  Future<void> clearAll() async {
    await _prefs.clear();
    await _secure.deleteAll();
    await _clearScanPreviews();
  }

  Future<void> _clearScanPreviews() async {
    try {
      final supportDirectory = await getApplicationSupportDirectory();
      final previewDirectory = Directory(
        '${supportDirectory.path}${Platform.pathSeparator}scan_history',
      );
      if (!await previewDirectory.exists()) return;

      await for (final entry in previewDirectory.list(followLinks: false)) {
        if (entry is File) await entry.delete();
      }
    } on FileSystemException {
      // Logout can still clear credentials if preview cleanup fails.
    }
  }
}
