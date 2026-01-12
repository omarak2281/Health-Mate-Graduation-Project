/// Error Messages Constants
/// All error messages centralized for consistency
/// These keys should be added to localization files

class ErrorMessages {
  ErrorMessages._();

  // Firebase Auth Errors
  static const String firebaseUserCreationFailed =
      'errors.firebase_user_creation_failed';
  static const String firebaseTokenFailed = 'errors.firebase_token_failed';
  static const String firebaseLoginFailed = 'errors.firebase_login_failed';
  static const String googleSignInFailed = 'errors.google_sign_in_failed';
  static const String googleTokenFailed = 'errors.google_token_failed';

  // Network Errors
  static const String networkError = 'errors.network_error';
  static const String serverError = 'errors.server_error';
  static const String connectionTimeout = 'errors.connection_timeout';
  static const String requestCancelled = 'errors.request_cancelled';

  // Validation Errors
  static const String invalidEmail = 'errors.invalid_email';
  static const String passwordTooShort = 'errors.password_too_short';
  static const String passwordsDontMatch = 'errors.passwords_dont_match';
  static const String requiredField = 'errors.required_field';
  static const String nameTooShort = 'errors.name_too_short';
  static const String invalidPhone = 'errors.invalid_phone';

  // Auth Errors
  static const String unauthorized = 'errors.unauthorized';
  static const String emailAlreadyInUse = 'errors.email_already_in_use';
  static const String invalidCredentials = 'errors.invalid_credentials';
  static const String userNotFound = 'errors.user_not_found';
  static const String wrongPassword = 'errors.wrong_password';
  static const String accountDisabled = 'errors.account_disabled';
  static const String tooManyRequests = 'errors.too_many_requests';

  // Generic Errors
  static const String unknownError = 'errors.unknown_error';
  static const String somethingWentWrong = 'errors.something_went_wrong';
}
