import 'package:dio/dio.dart';
import '../constants/error_messages.dart';

/// Error Detection and Handling Service
/// Provides intelligent error type detection and appropriate responses
class ErrorHandlingService {
  ErrorHandlingService._();

  /// Detects error type from exception and returns appropriate error message key
  static ErrorInfo detectErrorType(dynamic exception) {
    if (exception is DioException) {
      return _handleDioException(exception);
    } else if (exception is Exception) {
      return _handleGeneralException(exception);
    } else {
      return ErrorInfo(
        titleKey: 'unknown_error',
        messageKey: ErrorMessages.unknownError,
        subtitleKey: ErrorMessages.pleaseTryAgain,
        canRetry: true,
      );
    }
  }

  /// Handles Dio-specific exceptions
  static ErrorInfo _handleDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ErrorInfo(
          titleKey: 'connection_timeout',
          messageKey: ErrorMessages.connectionTimeout,
          subtitleKey: 'check_internet_connection',
          canRetry: true,
        );
      
      case DioExceptionType.badResponse:
        return _handleHttpError(exception);
      
      case DioExceptionType.cancel:
        return ErrorInfo(
          titleKey: 'request_cancelled',
          messageKey: ErrorMessages.requestCancelled,
          canRetry: false,
        );
      
      case DioExceptionType.connectionError:
        return ErrorInfo(
          titleKey: 'connection_error',
          messageKey: ErrorMessages.networkError,
          subtitleKey: 'check_internet_connection',
          canRetry: true,
        );
      
      default:
        return ErrorInfo(
          titleKey: 'network_error',
          messageKey: ErrorMessages.networkError,
          subtitleKey: ErrorMessages.pleaseTryAgain,
          canRetry: true,
        );
    }
  }

  /// Handles HTTP status code errors
  static ErrorInfo _handleHttpError(DioException exception) {
    final statusCode = exception.response?.statusCode;
    final data = exception.response?.data;
    
    // Try to extract error message from response
    String? serverMessage;
    if (data is Map<String, dynamic>) {
      serverMessage = data['detail'] as String? ?? 
                     data['message'] as String? ?? 
                     data['error'] as String?;
    }

    switch (statusCode) {
      case 400:
        return ErrorInfo(
          titleKey: 'bad_request',
          messageKey: serverMessage ?? ErrorMessages.invalidSymptomData,
          canRetry: false,
        );
      
      case 401:
        return ErrorInfo(
          titleKey: 'unauthorized',
          messageKey: ErrorMessages.unauthorized,
          subtitleKey: 'please_login_again',
          canRetry: false,
        );
      
      case 403:
        return ErrorInfo(
          titleKey: 'forbidden',
          messageKey: 'access_denied',
          canRetry: false,
        );
      
      case 404:
        return ErrorInfo(
          titleKey: 'not_found',
          messageKey: ErrorMessages.serviceUnavailable,
          subtitleKey: ErrorMessages.pleaseTryAgain,
          canRetry: true,
        );
      
      case 429:
        return ErrorInfo(
          titleKey: 'too_many_requests',
          messageKey: ErrorMessages.tooManyRequests,
          subtitleKey: 'please_wait_and_retry',
          canRetry: true,
        );
      
      case 500:
      case 502:
      case 503:
      case 504:
        return ErrorInfo(
          titleKey: 'server_error',
          messageKey: ErrorMessages.serversBusy,
          subtitleKey: ErrorMessages.pleaseTryAgain,
          canRetry: true,
        );
      
      default:
        return ErrorInfo(
          titleKey: 'http_error',
          messageKey: serverMessage ?? ErrorMessages.serverError,
          subtitleKey: 'status_code_$statusCode',
          canRetry: true,
        );
    }
  }

  /// Handles general exceptions
  static ErrorInfo _handleGeneralException(Exception exception) {
    final message = exception.toString().toLowerCase();
    
    if (message.contains('timeout') || message.contains('connection')) {
      return ErrorInfo(
        titleKey: 'connection_timeout',
        messageKey: ErrorMessages.connectionTimeout,
        canRetry: true,
      );
    } else if (message.contains('network') || message.contains('internet')) {
      return ErrorInfo(
        titleKey: 'network_error',
        messageKey: ErrorMessages.networkError,
        canRetry: true,
      );
    } else if (message.contains('parse') || message.contains('format')) {
      return ErrorInfo(
        titleKey: 'data_error',
        messageKey: ErrorMessages.invalidSymptomData,
        canRetry: false,
      );
    } else {
      return ErrorInfo(
        titleKey: 'unexpected_error',
        messageKey: ErrorMessages.unknownError,
        subtitleKey: ErrorMessages.pleaseTryAgain,
        canRetry: true,
      );
    }
  }
}

/// Error Information Model
class ErrorInfo {
  final String titleKey;
  final String messageKey;
  final String? subtitleKey;
  final bool canRetry;
  final String? actionKey;

  ErrorInfo({
    required this.titleKey,
    required this.messageKey,
    this.subtitleKey,
    this.canRetry = true,
    this.actionKey,
  });
}
