import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/user_model.dart';

/// Server-backed email and password authentication.
class AuthRepository {
  Dio get _dio => DioClient.instance.dio;

  /// Restores a saved session and rejects expired or invalid bearer tokens.
  /// A temporary network failure keeps the local session so cached app data remains usable.
  Future<bool> restoreSession() async {
    final storage = StorageService.instance;
    final token = await storage.getToken();
    if (token == null || token.isEmpty) {
      await storage.clearAuthSession();
      return false;
    }

    try {
      final response = await _dio.get(
        ApiConstants.currentUser,
        options: Options(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      final data = response.data;
      if (data is! Map<String, dynamic>) {
        await storage.clearAuthSession();
        return false;
      }
      final user = UserModel.fromJson(data);
      await storage.saveUserInfo(
        name: user.name,
        email: user.email,
        id: user.id,
        createdAt: user.createdAt.toIso8601String(),
      );
      await storage.setLoggedIn(true);
      return true;
    } on DioException catch (error) {
      if (error.response?.statusCode == ApiConstants.statusUnauthorized) {
        await storage.clearAuthSession();
        return false;
      }
      return storage.isLoggedIn;
    } on FormatException {
      await storage.clearAuthSession();
      return false;
    } on TypeError {
      await storage.clearAuthSession();
      return false;
    }
  }

  Future<UserModel> login(
      {required String email, required String password}) async {
    try {
      final response = await _dio.post(ApiConstants.login, data: {
        'email': email.trim(),
        'password': password,
      });
      return _saveSession(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw Exception(DioClient.parseError(error));
    }
  }

  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post(ApiConstants.register, data: {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });
      return _saveSession(response.data as Map<String, dynamic>);
    } on DioException catch (error) {
      throw Exception(DioClient.parseError(error));
    }
  }

  Future<void> forgotPassword({required String email}) async {
    throw Exception(
        'Password reset is not available yet. Contact support to reset your password.');
  }

  Future<void> logout() async {
    try {
      await _dio.post(
        ApiConstants.logout,
        options: Options(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
    } on DioException {
      // A local logout must still succeed if the server cannot be reached.
    } finally {
      await StorageService.instance.clearAuthSession();
    }
  }

  Future<UserModel> _saveSession(Map<String, dynamic> data) async {
    final token = data['access_token'] as String?;
    final userData = data['user'];
    if (token == null || userData is! Map<String, dynamic>) {
      throw Exception(
          'The server returned an invalid authentication response.');
    }
    final user = UserModel.fromJson(userData);
    final storage = StorageService.instance;
    await storage.saveToken(token);
    await storage.setLoggedIn(true);
    await storage.saveUserInfo(
      name: user.name,
      email: user.email,
      id: user.id,
      createdAt: user.createdAt.toIso8601String(),
    );
    return user;
  }
}
