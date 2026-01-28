import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import '../services/firebase_auth_service.dart';

/// Centralized Authentication Error Handler
/// Maps all auth errors to localized messages using easy_localization
class AuthErrorHandler {
  /// Handle any authentication error and return localized message
  static String handleError(dynamic error) {
    logError(error);

    // Firebase Auth Exceptions
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

    return 'errors.unknown_error'.tr();
  }

  /// Handle Dio/HTTP errors from backend - returns keys with source clarification
  static String _handleDioError(DioException error) {
    // 1. Check for specific Timeout/Connection errors (Network Source)
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'errors.network_error';
    }

    // 2. Handle Backend Response (Service/Server Source)
    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      // Prioritize specific backend "detail" messages
      if (data is Map && data.containsKey('detail')) {
        final detail = data['detail'].toString();

        if (detail.contains('Email already registered')) {
          return 'errors.email_already_in_use';
        }
        if (detail.contains('Login error: Not registered')) {
          return 'auth.google_not_registered';
        }
        if (detail.contains('Account recovery')) {
          return 'auth.recovery_role_required';
        }
        if (detail.contains('Email mismatch')) return 'auth.email_mismatch';
        if (detail.contains('Incorrect email or password')) {
          return 'errors.invalid_credentials';
        }
        if (detail.contains('Account is inactive')) {
          return 'errors.account_disabled';
        }
        if (detail.contains('Please select a role')) {
          return 'auth.role_selection_required';
        }
        if (detail.contains('Email not yet verified')) {
          return 'auth.email_not_verified_firebase';
        }

        // Validation errors (Input Source)
        if (detail.contains('validation error') || statusCode == 422) {
          return 'errors.required_field';
        }

        // Return raw detail if it looks like a manual message, otherwise fallback
        return detail.isNotEmpty ? detail : 'errors.server_error';
      }

      // Map by Status Code if no detail is available
      switch (statusCode) {
        case 400:
          return 'errors.required_field';
        case 401:
          return 'errors.unauthorized';
        case 403:
          return 'errors.operation_not_allowed';
        case 404:
          return 'errors.user_not_found';
        case 409:
          return 'errors.email_already_in_use';
        case 429:
          return 'errors.too_many_requests';
        case 500:
          return 'errors.server_error';
        default:
          return 'errors.server_error';
      }
    }

    // 3. Handle low-level Unknown or Socket errors (Interface Source)
    final errStr = error.toString();
    if (errStr.contains('SocketException') ||
        errStr.contains('HandshakeException')) {
      return 'errors.network_error';
    }

    if (error.type == DioExceptionType.badResponse) {
      return 'errors.server_error';
    }
    if (error.type == DioExceptionType.cancel) {
      return 'errors.request_cancelled';
    }

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

    return 'errors.something_went_wrong';
  }

  /// Log error for debugging with clear markers
  static void logError(dynamic error, {StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('🚨 [Auth Error Source]: ${error.runtimeType}');
      if (error is DioException) {
        debugPrint('🔗 [URL]: ${error.requestOptions.uri}');
        debugPrint('📋 [Status]: ${error.response?.statusCode}');
        debugPrint('📦 [Data]: ${error.response?.data}');
        debugPrint('⚠️ [Type]: ${error.type}');
      }
      debugPrint('💬 [Message]: $error');
      if (stackTrace != null) {
        debugPrint('🥞 [Stack]: $stackTrace');
      }
    }
  }
}
