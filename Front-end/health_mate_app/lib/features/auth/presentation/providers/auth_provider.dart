import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/user.dart';
import '../../data/auth_repository.dart';
import '../../../../core/error/auth_error_handler.dart';
import '../../../../core/services/firebase_auth_service.dart';

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
  final String? errorMessage;

  AuthState({required this.status, this.user, this.errorMessage});

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

// Auth State Notifier
class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _authRepository;

  AuthNotifier(this._authRepository)
    : super(AuthState(status: AuthStatus.initial)) {
    _checkAuthStatus();
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
          state = state.copyWith(status: AuthStatus.authenticated, user: user);
        }
      } catch (e) {
        // Silently handle - on first launch or offline, this is expected
        // Try cached user
        final cachedUser = _authRepository.getCachedUser();
        if (cachedUser != null) {
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
  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.login(
        email: email,
        password: password,
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
  }) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );

      // Set to unverified after registration
      state = state.copyWith(
        status: AuthStatus.unverified,
        user: user,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Google Sign-In
  Future<void> loginWithGoogle({required String role}) async {
    state = state.copyWith(status: AuthStatus.loading);

    try {
      final user = await _authRepository.loginWithGoogle(role: role);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthErrorHandler.handleError(e),
      );
    }
  }

  // Resend Verification Email
  Future<void> resendVerificationEmail() async {
    try {
      await _authRepository.resendVerificationEmail();
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
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
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
          clearError: true,
        );
      } catch (e) {
        state = state.copyWith(
          status: AuthStatus.error,
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
    state = state.copyWith(status: AuthStatus.unauthenticated, user: null);
  }

  // Update Profile
  Future<void> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final user = await _authRepository.updateProfile(
        fullName: fullName,
        phone: phone,
        profileImage: profileImage,
      );
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
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
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: AuthErrorHandler.handleError(e),
      );
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
  return AuthNotifier(authRepository);
});
