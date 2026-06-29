/// App Exceptions
/// Custom exception classes for better error handling

class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'No internet connection'])
    : super(message, 'NETWORK_ERROR');
}

class ServerException extends AppException {
  ServerException([String message = 'Server error occurred'])
    : super(message, 'SERVER_ERROR');
}

class UnauthorizedException extends AppException {
  UnauthorizedException([String message = 'Unauthorized access'])
    : super(message, 'UNAUTHORIZED');
}

class CacheException extends AppException {
  CacheException([String message = 'Cache error'])
    : super(message, 'CACHE_ERROR');
}

class ValidationException extends AppException {
  ValidationException(String message) : super(message, 'VALIDATION_ERROR');
}
