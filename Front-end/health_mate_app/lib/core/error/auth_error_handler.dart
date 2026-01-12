import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';

/// Centralized Authentication Error Handler
/// Maps all auth errors to localized messages using easy_localization
class AuthErrorHandler {
  /// Handle any authentication error and return localized message
  static String handleError(dynamic error) {
    // Firebase Auth Exceptions (already return keys)
    if (error is AuthException) {
      return error.message.tr();
    }

    // DioException (Backend API errors)
    if (error is DioException) {
      return _handleDioError(error).tr();
    }

    // Generic errors
    if (error is Exception) {
      return _handleGenericError(error).tr();
    }

    return 'common.error'.tr();
  }

  /// Handle Dio/HTTP errors from backend - returns keys
  static String _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'errors.network_error';
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'errors.network_error';
    }

    if (error.response != null) {
      final statusCode = error.response!.statusCode;

      switch (statusCode) {
        case 400:
          return 'errors.required_field';
        case 401:
          return 'errors.unauthorized';
        case 404:
          return 'errors.server_error';
        case 409:
          return 'errors.email_already_in_use';
        case 500:
          return 'errors.server_error';
        default:
          return 'errors.server_error';
      }
    }

    // Handle cases where response is null but it's not a standard timeout
    // This often happens with connection refused or host unreachable
    if (error.error != null &&
        error.error.toString().contains('SocketException')) {
      return 'errors.network_error';
    }

    if (error.message != null && error.message!.contains('SocketException')) {
      return 'errors.network_error';
    }

    // Default fallback for any other DioError that didn't match above
    return 'errors.network_error';
  }

  /// Handle generic exceptions - returns keys
  static String _handleGenericError(Exception error) {
    final errorString = error.toString();

    if (errorString.contains('SocketException') ||
        errorString.contains('Connection refused') ||
        errorString.contains('Network is unreachable')) {
      return 'common.no_internet';
    }

    return 'errors.server_error';
  }

  /// Log error for debugging
  static void logError(dynamic error, {StackTrace? stackTrace}) {
    debugPrint('🔴 Auth Error: $error');
    if (stackTrace != null) {
      debugPrint('Stack Trace: $stackTrace');
    }
  }
}
