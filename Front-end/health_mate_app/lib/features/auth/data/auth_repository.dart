import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/foundation.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../core/models/user.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/locale_keys.dart';
import '../../../core/services/firebase_auth_service.dart';
import '../../../core/error/auth_error_handler.dart';

/// Authentication Repository
/// Handles all auth operations with Firebase integration
/// Firebase handles authentication, backend handles authorization and user data

class AuthRepository {
  final DioClient _dioClient;
  final SecureStorage _secureStorage;
  final HiveCache _hiveCache;
  final FirebaseAuthService? _firebaseAuthService;

  AuthRepository(
    this._dioClient,
    this._secureStorage,
    this._hiveCache,
    this._firebaseAuthService,
  );

  // ============================================================================
  // Email & Password Registration with Firebase
  // ============================================================================

  Future<User> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
    required String role,
  }) async {
    try {
      // Step 1: Create Firebase user (if Firebase is available)
      firebase_auth.User? firebaseUser;
      if (_firebaseAuthService != null && _firebaseAuthService.isInitialized) {
        try {
          firebaseUser = await _firebaseAuthService.signUpWithEmail(
            email: email,
            password: password,
          );
          debugPrint('✅ Firebase user created: ${firebaseUser?.uid}');
        } catch (e) {
          // If user already exists in Firebase, just sign in
          if (e.toString().contains('email_already_in_use') ||
              e.toString().contains('email-already-in-use')) {
            debugPrint('ℹ️ User already in Firebase, attempting sign in...');
            firebaseUser = await _firebaseAuthService.signInWithEmail(
              email: email,
              password: password,
            );
          } else {
            rethrow;
          }
        }
      } else {
        debugPrint('ℹ️ Firebase unavailable - using backend-only auth');
      }

      // Step 2: Get Firebase ID token (optional if Firebase is available)
      String? firebaseUid;
      if (firebaseUser != null) {
        final idToken = await firebaseUser.getIdToken();
        if (idToken == null) {
          debugPrint('⚠️ Failed to get Firebase token');
        }
        firebaseUid = firebaseUser.uid;
      }

      // Step 3: Register in backend
      debugPrint(
        '🚀 Registering user in backend at: ${ApiConstants.baseUrl}${ApiConstants.register}',
      );
      final response = await _dioClient.dio.post(
        ApiConstants.register,
        data: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'phone': phone,
          'role': role,
          if (firebaseUid != null) 'firebase_uid': firebaseUid,
        },
      );

      final user = User.fromJson(response.data);

      // Cache user
      await _hiveCache.cacheUser(user.toJson());

      return user;
    } catch (e) {
      AuthErrorHandler.logError(e);
      rethrow;
    }
  }

  // ============================================================================
  // Email & Password Login with Firebase
  // ============================================================================

  Future<User> login({required String email, required String password}) async {
    try {
      // Step 1: Sign in with Firebase (if available)
      firebase_auth.User? firebaseUser;
      if (_firebaseAuthService != null && _firebaseAuthService.isInitialized) {
        debugPrint('🚀 Sign-in attempt for: $email');
        firebaseUser = await _firebaseAuthService.signInWithEmail(
          email: email,
          password: password,
        );

        if (firebaseUser != null) {
          // Get Firebase ID token
          final idToken = await firebaseUser.getIdToken();
          if (idToken == null) {
            debugPrint('⚠️ Failed to get Firebase token');
          }
        }
      } else {
        debugPrint('ℹ️ Firebase unavailable - using backend-only auth');
      }

      // Step 3: Login to backend
      debugPrint(
        '🚀 Logging in to backend at: ${ApiConstants.baseUrl}${ApiConstants.login}',
      );
      final response = await _dioClient.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );

      // Save tokens
      final accessToken = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];
      await _secureStorage.saveTokens(accessToken, refreshToken);

      // Get user profile
      final user = await getCurrentUser();

      return user;
    } catch (e) {
      AuthErrorHandler.logError(e);
      rethrow;
    }
  }

  Future<User> getCurrentUser() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.userProfile);
      final user = User.fromJson(response.data);

      // Cache user
      await _hiveCache.cacheUser(user.toJson());

      return user;
    } catch (e) {
      // Try to get from cache
      final cachedUser = _hiveCache.getCachedUser();
      if (cachedUser != null) {
        return User.fromJson(cachedUser);
      }
      rethrow;
    }
  }

  // Update profile
  Future<User> updateProfile({
    String? fullName,
    String? phone,
    String? profileImage,
  }) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.userProfile,
        data: {
          if (fullName != null) 'full_name': fullName,
          if (phone != null) 'phone': phone,
          if (profileImage != null) 'profile_image': profileImage,
        },
      );
      final user = User.fromJson(response.data);
      await _hiveCache.cacheUser(user.toJson());
      return user;
    } catch (e) {
      rethrow;
    }
  }

  // Change Password
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      await _dioClient.dio.put(
        ApiConstants.userPassword,
        data: {'old_password': oldPassword, 'new_password': newPassword},
      );
    } catch (e) {
      rethrow;
    }
  }

  // Upload Profile Image
  Future<String> uploadProfileImage(dynamic file) async {
    try {
      final formData = FormData.fromMap({'file': file});

      final response = await _dioClient.dio.post(
        ApiConstants
            .uploadProfilePicture, // Standardized to use profile-picture endpoint
        data: formData,
      );

      return response.data['url'];
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _dioClient.dio.post(ApiConstants.logout);
    } catch (e) {
      // Continue with local logout even if API fails
    } finally {
      // Clear all local data
      await _secureStorage.deleteTokens();
      await _hiveCache.clearAll();
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getAccessToken();
    return token != null;
  }

  // Get cached user (offline)
  User? getCachedUser() {
    final cachedUserData = _hiveCache.getCachedUser();
    if (cachedUserData != null) {
      return User.fromJson(cachedUserData);
    }
    return null;
  }

  // ============================================================================
  // Google Sign-In
  // ============================================================================

  Future<User> loginWithGoogle({required String role}) async {
    try {
      // Step 1: Sign in with Google via Firebase
      if (_firebaseAuthService == null || !_firebaseAuthService.isInitialized) {
        throw Exception(LocaleKeys.errorsGoogleSignInFailed);
      }

      final firebaseUser = await _firebaseAuthService.signInWithGoogle();

      if (firebaseUser == null) {
        throw Exception(LocaleKeys.errorsGoogleSignInFailed);
      }

      // Step 2: Get Firebase ID token
      final idToken = await firebaseUser.getIdToken();
      if (idToken == null) {
        throw Exception(LocaleKeys.errorsGoogleTokenFailed);
      }

      // Step 3: Authenticate with backend using social auth endpoint
      final response = await _dioClient.dio.post(
        ApiConstants.googleLogin,
        data: {'firebase_id_token': idToken, 'role': role},
      );

      // Save tokens
      final accessToken = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];
      await _secureStorage.saveTokens(accessToken, refreshToken);

      // Get user profile
      final user = await getCurrentUser();

      return user;
    } catch (e) {
      AuthErrorHandler.logError(e);
      rethrow;
    }
  }

  // ============================================================================
  // Email Verification
  // ============================================================================

  Future<void> resendVerificationEmail() async {
    try {
      if (_firebaseAuthService != null && _firebaseAuthService.isInitialized) {
        await _firebaseAuthService.sendEmailVerification();
      }
    } catch (e) {
      AuthErrorHandler.logError(e);
      rethrow;
    }
  }

  Future<bool> checkEmailVerification() async {
    try {
      if (_firebaseAuthService == null || !_firebaseAuthService.isInitialized)
        return false;
      return await _firebaseAuthService.checkEmailVerified();
    } catch (e) {
      AuthErrorHandler.logError(e);
      return false;
    }
  }

  Future<User> verifyAndLogin() async {
    try {
      if (_firebaseAuthService == null || !_firebaseAuthService.isInitialized)
        throw Exception('Firebase not initialized');

      final idToken = await _firebaseAuthService.getIdToken();
      if (idToken == null) throw Exception('Failed to get token');

      // Use social auth endpoint to exchange token for backend session
      final response = await _dioClient.dio.post(
        ApiConstants.googleLogin,
        data: {'firebase_id_token': idToken, 'role': 'patient'},
      );

      final accessToken = response.data['access_token'];
      final refreshToken = response.data['refresh_token'];
      await _secureStorage.saveTokens(accessToken, refreshToken);

      return await getCurrentUser();
    } catch (e) {
      AuthErrorHandler.logError(e);
      rethrow;
    }
  }
}

// Provider
final firebaseAuthServiceProvider = Provider<FirebaseAuthService?>((ref) {
  try {
    return FirebaseAuthService();
  } catch (e) {
    debugPrint('⚠️ FirebaseAuthService unavailable: $e');
    // Return null if Firebase isn't initialized - app can still work with backend auth
    return null;
  }
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final secureStorage = ref.watch(secureStorageProvider);
  final hiveCache = ref.watch(hiveCacheProvider);
  final firebaseAuthService = ref.watch(firebaseAuthServiceProvider);

  return AuthRepository(
    dioClient,
    secureStorage,
    hiveCache,
    firebaseAuthService,
  );
});
