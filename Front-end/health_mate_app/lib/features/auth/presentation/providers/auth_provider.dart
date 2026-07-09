import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../../core/models/user.dart';
import '../../data/auth_repository.dart';
import '../../../../core/error/auth_error_handler.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/storage/shared_prefs_cache.dart';

/// Auth State
/// Manages authentication state across the app

enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  unverified, // New state for email verification
  error,
}

class AuthState {
  final AuthStatus status;
  final User? user;
  final String? errorKey;
  final String? errorMessage;

  AuthState(
      {required this.status, this.user, this.errorKey, this.errorMessage});

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorKey,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorKey: clearError ? null : (errorKey ?? this.errorKey),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;
  final SharedPrefsCache _sharedPrefs;
  final SocketService _socketService;

  AuthNotifier(this._authRepository, this._sharedPrefs, this._socketService)
      : super(AuthState(status: AuthStatus.initial)) {
    _checkAuthStatus();
  }

  Future<void> _startRealtime() async {
    final token = await _authRepository.getAccessToken();
    if (token != null) {
      _socketService.init(token);
    }
  }

  // Check if user is already logged in
  // Errors here are expected (e.g., no backend, first launch) so we don't log them
  Future<void> _checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);

    final isLoggedIn = await _authRepository.isLoggedIn();

    if (isLoggedIn) {
      try {
        final user = await _authRepository.getCurrentUser();

        // Check if user is verified
        if (!user.isVerified) {
          state = state.copyWith(status: AuthStatus.unverified, user: user);
        } else {
          // Mark onboarding as completed if already authenticated
          _sharedPrefs.setOnboardingCompleted(true);
          await _startRealtime();
          state = state.copyWith(status: AuthStatus.authenticated, user: user);
        }
      } catch (e) {
        // Silently handle - on first launch or offline, this is expected
        // Try cached user
        final cachedUser = _authRepository.getCachedUser();
        if (cachedUser != null) {
          await _startRealtime();
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: cachedUser,
          );
        } else {
          // No auth, go to login - this is normal, not an error
          state = state.copyWith(status: AuthStatus.unauthenticated);
        }
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  // Login
  Future<void> login({
    required String email,
    required String password,
    String? role,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
        role: role,
      );

      // Check if user needs verification
      if (!user.isVerified) {
        state = state.copyWith(
          status: AuthStatus.unverified,
          user: user,
          errorMessage: null,
          clearError: true,
        );
      } else {
        // Mark onboarding as completed upon successful login
        _sharedPrefs.setOnboardingCompleted(true);
        await _startRealtime();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
          clearError: true,
        );
      }
    } catch (e) {
      // Handle email not verified error specifically
      if (e is AuthException && e.code == 'email-not-verified') {
        state = state.copyWith(
          status: AuthStatus.unverified,
          // Create temporary user with email for display
          user: User(
            id: '',
            email: email,
            fullName: '',
            role: 'patient',
            isVerified: false,
            isActive: true,
            createdAt: DateTime.now(),
          ),
          errorMessage: null, // Don't show error, just redirect
          clearError: true,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Register
  Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String role,
    String? birthDate,
    String? gender,
    dynamic profileImage, // Can be File
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      String? profileImageUrl;
      if (profileImage != null) {
        // Upload image first
        profileImageUrl =
            await _authRepository.uploadProfileImage(profileImage);
      }

      final user = await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
        birthDate: birthDate,
        gender: gender,
        profileImage: profileImageUrl,
      );

      // Set to unverified after registration
      state = state.copyWith(
        status: AuthStatus.unverified,
        user: user,
        errorMessage: null,
        clearError: true,
      );
    } catch (e) {
      // Enhanced error handling for registration
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final detail = e.response?.data?['detail']?.toString() ?? '';

        // Handle email already exists
        if (statusCode == 409 || detail.contains('Email already registered')) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'errors.email_already_in_use',
            errorMessage:
                'This email is already registered. Please try signing in or use a different email.',
          );
          return;
        }

        // Handle validation errors
        if (statusCode == 422 || detail.contains('validation error')) {
          String validationMessage = 'Please check your input and try again.';
          if (detail.contains('email')) {
            validationMessage = 'Please enter a valid email address.';
          } else if (detail.contains('password')) {
            validationMessage = 'Password must be at least 8 characters long.';
          } else if (detail.contains('name')) {
            validationMessage = 'Please enter your full name.';
          }

          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'errors.required_field',
            errorMessage: validationMessage,
          );
          return;
        }

        // Handle network errors
        if (statusCode == null || statusCode >= 500) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'errors.server_error',
            errorMessage:
                'Server is temporarily unavailable. Please try again later.',
          );
          return;
        }
      }

      // Handle Firebase-specific errors
      if (e.toString().contains('email-already-in-use')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'errors.email_already_in_use',
          errorMessage:
              'This email is already registered. Please try signing in instead.',
        );
        return;
      }

      if (e.toString().contains('weak-password')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'errors.password_too_short',
          errorMessage:
              'Password is too weak. Please choose a stronger password.',
        );
        return;
      }

      if (e.toString().contains('invalid-email')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'errors.invalid_email',
          errorMessage: 'Please enter a valid email address.',
        );
        return;
      }

      // Handle network/connection errors
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'errors.network_error',
          errorMessage:
              'Network connection issue. Please check your internet and try again.',
        );
        return;
      }

      // Generic error handling
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Google Sign-In
  Future<void> loginWithGoogle({
    String? role,
    bool isSignup = false,
    String? birthDate,
    String? phone,
    String? gender,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.loginWithGoogle(
        role: role,
        isSignup: isSignup,
        birthDate: birthDate,
        phone: phone,
        gender: gender,
      );

      // Mark onboarding as completed upon successful Google login
      _sharedPrefs.setOnboardingCompleted(true);
      await _startRealtime();
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
        clearError: true,
      );
    } catch (e) {
      // Enhanced error handling for Google auth
      if (e is DioException) {
        final statusCode = e.response?.statusCode;
        final detail = e.response?.data?['detail']?.toString() ?? '';

        // Handle unregistered Google user
        if (statusCode == 404 || detail.contains('Not registered')) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'auth.google_not_registered',
            errorMessage:
                'This Google account is not registered. Please sign up first.',
          );
          return;
        }

        // Handle Google account not linked
        if (detail.contains('Google Login attempt for existing email') &&
            detail.contains('but not linked via Google yet')) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'auth.google_not_linked',
            errorMessage:
                'This email is registered but not linked to Google. Please sign in with your password or link your Google account.',
          );
          return;
        }

        // Handle email already exists
        if (statusCode == 409 || detail.contains('Email already registered')) {
          state = state.copyWith(
            status: AuthStatus.error,
            errorKey: 'errors.email_already_in_use',
            errorMessage:
                'This Google account is already registered. Please try signing in instead.',
          );
          return;
        }

        // Handle verification required
        if (detail.contains('Email not yet verified')) {
          state = state.copyWith(
            status: AuthStatus.unverified,
            user: User(
              id: '',
              email: _extractEmailFromError(e),
              fullName: '',
              role: 'patient',
              isVerified: false,
              isActive: true,
              createdAt: DateTime.now(),
            ),
            errorKey: 'auth.email_not_verified_firebase',
            errorMessage: 'Please verify your email before continuing.',
          );
          return;
        }
      }

      // Handle Firebase-specific errors
      if (e.toString().contains('user-not-found') ||
          e.toString().contains('user-disabled') ||
          e.toString().contains('user-mismatch')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'auth.google_account_issue',
          errorMessage:
              'There\'s an issue with your Google account. Please try again or use a different sign-in method.',
        );
        return;
      }

      // Handle network/connection errors
      if (e.toString().contains('network') ||
          e.toString().contains('connection') ||
          e.toString().contains('timeout')) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: 'errors.network_error',
          errorMessage:
              'Network connection issue. Please check your internet and try again.',
        );
        return;
      }

      // Generic error handling
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
      rethrow;
    }
  }

  // Helper method to extract email from error data
  String _extractEmailFromError(dynamic error) {
    if (error is DioException && error.response?.data is Map) {
      final data = error.response!.data as Map;
      return data['email'] as String? ?? 'unknown@example.com';
    }
    return 'unknown@example.com';
  }

  // Resend Verification Email
  Future<void> resendVerificationEmail() async {
    try {
      await _authRepository.resendVerificationEmail();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Check Verification Status (called from Verification UI)
  Future<void> checkVerificationStatus() async {
    // Keep current state but maybe show loading indicator if UI supports it
    // For now we assume UI handles the Future completion
    final isVerified = await _authRepository.checkEmailVerification();

    if (isVerified) {
      try {
        // Exchange Firebase ID Token for Backend JWT
        final user = await _authRepository.verifyAndLogin();
        await _startRealtime();
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
          clearError: true,
        );
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorKey: AuthErrorHandler.getErrorKey(e),
          errorMessage: AuthErrorHandler.handleError(e),
        );
      }
    } else {
      // If not verified, just ensure state remains unverified (refresh check)
      // We don't change state here to avoid UI flickering, just let user try again
    }
  }

  // Logout
  Future<void> logout() async {
    await _authRepository.logout();
    _socketService.dispose();
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }

  // Delete Account
  Future<void> deleteAccount() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.deleteAccount();
      _socketService.dispose();
      state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
      rethrow;
    }
  }

  // Update Profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
    String? birthDate,
    String? gender,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authRepository.updateProfile(
        fullName: fullName,
        phone: phone,
        profileImage: profileImage,
        birthDate: birthDate,
        gender: gender,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Change Password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.changePassword(
        oldPassword: oldPassword,
        newPassword: newPassword,
      );
      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: null,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Reset Password (Forgot Password)
  Future<void> resetPassword(String email) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      await _authRepository.resetPassword(email);
      // We don't change state to authenticated, just clear loading
      // The user still needs to login with the new password
      state = state.copyWith(
        status: AuthStatus.unauthenticated, // or keep previous state?
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
      rethrow; // Rethrow so UI can show success/error dialogs
    }
  }

  // Upload Profile Image
  Future<String?> uploadProfileImage(dynamic file) async {
    try {
      final imageUrl = await _authRepository.uploadProfileImage(file);
      // Automatically update profile with new image
      await updateProfile(profileImage: imageUrl);
      return imageUrl;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorKey: AuthErrorHandler.getErrorKey(e),
        errorMessage: AuthErrorHandler.handleError(e),
      );
      return null;
    }
  }

  // Clear Error - Call this when navigating between screens
  void clearError() {
    if (state.status == AuthStatus.error) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );
    }
  }
}

// Provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final authRepository = ref.watch(authRepositoryProvider);
  final sharedPrefs = ref.watch(sharedPrefsCacheProvider);
  final socketService = ref.watch(socketServiceProvider);
  return AuthNotifier(authRepository, sharedPrefs, socketService);
});
