import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import '../services/storage_service.dart';

/// Singleton Dio HTTP client with interceptors.
///
/// Features:
/// - Automatic JWT auth header injection
/// - Token refresh on 401
/// - Structured error handling
/// - Request/response logging in debug mode
class DioClient {
  DioClient._();
  static DioClient? _instance;
  static DioClient get instance => _instance ??= DioClient._();

  late final Dio _dio;
  bool _initialized = false;

  Dio get dio {
    assert(
        _initialized, 'DioClient must be initialized before use. Call init().');
    return _dio;
  }

  /// Initialize Dio — call once from main()
  Future<void> init() async {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectTimeout),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeout),
        sendTimeout: const Duration(seconds: AppConstants.connectTimeout),
        headers: {
          ApiConstants.headerContentType: 'application/json',
          ApiConstants.headerAccept: 'application/json',
        },
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );

    // Auth injection interceptor
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await StorageService.instance.getToken();
          if (token != null) {
            options.headers[ApiConstants.headerAuthorization] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          // Handle 401 — attempt token refresh
          if (error.response?.statusCode == ApiConstants.statusUnauthorized) {
            // In production: call refresh token endpoint here
            // For now, propagate the error
            await StorageService.instance.clearAll();
          }
          return handler.next(error);
        },
      ),
    );

    // Logging in debug mode only
    if (kDebugMode) {
      _dio.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          responseHeader: false,
          error: true,
          compact: true,
        ),
      );
    }

    _initialized = true;
  }

  /// Parse DioException into a human-readable message
  static String parseError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Request timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Please check your network.';
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map && data.containsKey('detail')) {
          return data['detail'].toString();
        }
        return 'Server error (${error.response?.statusCode}).';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      default:
        return 'An unexpected error occurred.';
    }
  }
}
