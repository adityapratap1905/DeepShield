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
  Future<String?>? _refreshFuture;

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
          if (error.response?.statusCode == ApiConstants.statusUnauthorized) {
            final request = error.requestOptions;
            final isAuthRequest = request.path.endsWith('/auth/login') ||
                request.path.endsWith('/auth/register') ||
                request.path.endsWith('/auth/refresh') ||
                request.path.endsWith('/auth/logout');
            final alreadyRetried = request.extra['authRetried'] == true;
            if (!isAuthRequest && !alreadyRetried) {
              final oldToken = await StorageService.instance.getToken();
              if (oldToken != null && oldToken.isNotEmpty) {
                final newToken = await _refreshAccessToken(oldToken);
                if (newToken != null) {
                  request.headers[ApiConstants.headerAuthorization] =
                      'Bearer $newToken';
                  request.extra['authRetried'] = true;
                  try {
                    final response = await _dio.fetch<dynamic>(request);
                    return handler.resolve(response);
                  } on DioException catch (retryError) {
                    return handler.next(retryError);
                  }
                }
              }
              await StorageService.instance.clearAuthSession();
            }
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

  Future<String?> _refreshAccessToken(String token) {
    return _refreshFuture ??= _performTokenRefresh(token).whenComplete(() {
      _refreshFuture = null;
    });
  }

  Future<String?> _performTokenRefresh(String token) async {
    try {
      final refreshClient = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 3),
        receiveTimeout: const Duration(seconds: 3),
        headers: {ApiConstants.headerAccept: 'application/json'},
      ));
      final response = await refreshClient.post(
        ApiConstants.refreshToken,
        options: Options(headers: {
          ApiConstants.headerAuthorization: 'Bearer $token',
        }),
      );
      final data = response.data;
      final newToken =
          data is Map<String, dynamic> ? data['access_token'] as String? : null;
      if (newToken == null || newToken.isEmpty) return null;
      await StorageService.instance.saveToken(newToken);
      return newToken;
    } on DioException {
      return null;
    }
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
