import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

/// Firebase Authentication Service
/// Handles all Firebase Auth operations: Email/Password, Google Sign-In
class FirebaseAuthService {
  final firebase_auth.FirebaseAuth? _firebaseAuth;
  final GoogleSignIn _googleSignIn;

  FirebaseAuthService({
    firebase_auth.FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _firebaseAuth = _getFirebaseAuth(firebaseAuth),
        _googleSignIn = googleSignIn ?? GoogleSignIn();

  static firebase_auth.FirebaseAuth? _getFirebaseAuth(
    firebase_auth.FirebaseAuth? provided,
  ) {
    if (provided != null) return provided;
    try {
      return firebase_auth.FirebaseAuth.instance;
    } catch (e) {
      // On web/debug, if Firebase isn't initialized, this will throw.
      // We return null so the service can still be created (in a degrading state).
      debugPrint('Warning: FirebaseAuth.instance access failed: $e');
      return null;
    }
  }

  bool get isInitialized => _firebaseAuth != null;

  // ============================================================================
  // Email & Password Authentication
  // ============================================================================

  /// Sign up with email and password
  /// Creates Firebase user and sends verification email
  Future<firebase_auth.User?> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-not-initialized',
        message: 'errors.server_error',
      );
    }
    try {
      final userCredential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Send verification email
      await userCredential.user?.sendEmailVerification();

      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Sign in with email and password
  /// Checks if email is verified before allowing login
  Future<firebase_auth.User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-not-initialized',
        message: 'errors.server_error',
      );
    }
    try {
      final userCredential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      // Check email verification
      if (user != null && !user.emailVerified) {
        await auth.signOut();
        throw AuthException(
          code: 'email-not-verified',
          message: 'auth.not_verified',
        );
      }

      return user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Send email verification to current user
  Future<void> sendEmailVerification() async {
    final auth = _firebaseAuth;
    if (auth == null) return;
    try {
      final user = auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Check if current user's email is verified
  /// Reloads user to get latest verification status
  Future<bool> checkEmailVerified() async {
    final auth = _firebaseAuth;
    if (auth == null) return false;
    try {
      final user = auth.currentUser;
      if (user == null) return false;

      await user.reload();
      final refreshedUser = auth.currentUser;
      return refreshedUser?.emailVerified ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _firebaseAuth;
    if (auth == null) return;
    try {
      await auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  // ============================================================================
  // Google Sign-In
  // ============================================================================

  /// Sign in with Google
  /// Returns Firebase user with Google credentials
  Future<firebase_auth.User?> signInWithGoogle() async {
    final auth = _firebaseAuth;
    if (auth == null) {
      throw AuthException(
        code: 'firebase-not-initialized',
        message: 'errors.server_error',
      );
    }
    try {
      // Trigger Google Sign-In flow
      // Always sign out first to force account selection
      await _googleSignIn.signOut();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // User cancelled sign-in
      if (googleUser == null) {
        throw AuthException(
          code: 'sign-in-cancelled',
          message: 'auth.social_auth_cancelled',
        );
      }

      // Obtain Google Sign-In authentication details
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create Firebase credential
      final credential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with Google credential
      final userCredential = await auth.signInWithCredential(credential);

      return userCredential.user;
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    } catch (e) {
      throw AuthException(
        code: 'google-sign-in-failed',
        message: 'errors.server_error',
      );
    }
  }

  // ============================================================================
  // Common Methods
  // ============================================================================

  /// Get current Firebase user
  firebase_auth.User? getCurrentUser() {
    return _firebaseAuth?.currentUser;
  }

  /// Get Firebase ID token for backend authentication
  Future<String?> getIdToken() async {
    final auth = _firebaseAuth;
    if (auth == null) return null;
    try {
      final user = auth.currentUser;
      if (user == null) return null;

      return await user.getIdToken();
    } catch (e) {
      return null;
    }
  }

  /// Sign out from Firebase and Google
  Future<void> signOut() async {
    final auth = _firebaseAuth;
    try {
      await Future.wait([
        if (auth != null) auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      // Continue with sign out even if one fails
    }
  }

  /// Delete current Firebase user
  Future<void> deleteUser() async {
    final auth = _firebaseAuth;
    if (auth == null) return;
    try {
      final user = auth.currentUser;
      if (user != null) {
        await user.delete();
      }
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthException(e);
    }
  }

  /// Listen to authentication state changes
  Stream<firebase_auth.User?> authStateChanges() {
    final auth = _firebaseAuth;
    if (auth == null) return Stream.value(null);
    return auth.authStateChanges();
  }

  // ============================================================================
  // Error Handling
  // ============================================================================

  /// Map Firebase Auth exceptions to localization keys
  AuthException _handleFirebaseAuthException(
    firebase_auth.FirebaseAuthException e,
  ) {
    String key;

    switch (e.code) {
      // Email/Password Errors
      case 'email-already-in-use':
        key = 'errors.email_already_in_use';
        break;
      case 'wrong-password':
        key = 'errors.wrong_password';
        break;
      case 'user-not-found':
        key = 'errors.user_not_found';
        break;
      case 'weak-password':
        key = 'errors.weak_password';
        break;
      case 'invalid-email':
        key = 'errors.invalid_email';
        break;
      case 'user-disabled':
        key = 'errors.user_disabled';
        break;
      case 'too-many-requests':
        key = 'errors.too_many_requests';
        break;
      case 'operation-not-allowed':
        key = 'errors.operation_not_allowed';
        break;

      // Network & Token Errors
      case 'network-request-failed':
        key = 'errors.network_error';
        break;
      case 'invalid-credential':
        key = 'errors.unauthorized';
        break;
      case 'account-exists-with-different-credential':
        key = 'errors.account_exists_different_credential';
        break;

      // Default
      default:
        key = 'errors.server_error';
    }

    return AuthException(code: e.code, message: key, originalException: e);
  }
}

/// Custom Authentication Exception
class AuthException implements Exception {
  final String code;
  final String message;
  final Exception? originalException;

  AuthException({
    required this.code,
    required this.message,
    this.originalException,
  });

  @override
  String toString() => message;
}
