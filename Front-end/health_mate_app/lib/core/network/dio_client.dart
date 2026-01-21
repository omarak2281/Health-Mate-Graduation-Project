import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

/// Dio HTTP Client
/// Configured with interceptors, auth, and error handling

class DioClient {
  late final Dio _dio;
  final SecureStorage _secureStorage;

  DioClient(this._secureStorage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectionTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _authInterceptor(),
      _errorInterceptor(),
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
      ),
    ]);
  }

  Dio get dio => _dio;

  // Auth Interceptor - Add JWT token to requests
  InterceptorsWrapper _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _secureStorage.getAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // Handle 401 (Unauthorized) OR 403 (Forbidden/Expired) for token refresh
        if (error.response?.statusCode == 401 ||
            error.response?.statusCode == 403) {
          // Token might be expired or invalid - try refresh
          final refreshed = await _refreshToken();
          if (refreshed) {
            // Retry original request
            final options = error.requestOptions;
            final token = await _secureStorage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }

            try {
              // Create a new Dio instance for retry to avoid interceptor loops if needed,
              // but here we use the same one which is generally fine if handled.
              final response = await _dio.fetch(options);
              handler.resolve(response);
              return;
            } catch (e) {
              handler.next(error);
              return;
            }
          }
        }
        handler.next(error);
      },
    );
  }

  // Error Interceptor - Handle common errors
  InterceptorsWrapper _errorInterceptor() {
    return InterceptorsWrapper(
      onError: (error, handler) {
        String errorMessage = 'Unknown error occurred';

        if (error.type == DioExceptionType.connectionTimeout ||
            error.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Connection timeout. Please check your internet.';
        } else if (error.type == DioExceptionType.badResponse) {
          switch (error.response?.statusCode) {
            case 400:
              errorMessage = error.response?.data['detail'] ?? 'Bad request';
              break;
            case 401:
              errorMessage = 'Unauthorized. Please login again.';
              break;
            case 403:
              errorMessage = 'Access denied';
              break;
            case 404:
              errorMessage = 'Resource not found';
              break;
            case 500:
              errorMessage = 'Server error. Please try again later.';
              break;
            default:
              errorMessage = 'Error: ${error.response?.statusCode}';
          }
        } else if (error.type == DioExceptionType.unknown) {
          errorMessage = 'No internet connection';
        }

        handler.next(
          DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: errorMessage,
          ),
        );
      },
    );
  }

  // Refresh token logic
  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) return false;

      final response = await _dio.post(
        ApiConstants.refreshToken,
        queryParameters: {'refresh_token': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access_token'];
        final newRefreshToken = response.data['refresh_token'];

        await _secureStorage.saveTokens(newAccessToken, newRefreshToken);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

// Provider
final dioClientProvider = Provider<DioClient>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return DioClient(secureStorage);
});
