import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

// /**
//  * Secure Storage Service
//  * Uses FlutterSecureStorage for sensitive data (tokens)
//  */

class SecureStorage {
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Save tokens
  Future<void> saveTokens(String accessToken, String refreshToken) async {
    await Future.wait([
      _storage.write(key: AppConstants.cacheKeyToken, value: accessToken),
      _storage.write(
        key: AppConstants.cacheKeyRefreshToken,
        value: refreshToken,
      ),
    ]);
  }

  // Get access token
  Future<String?> getAccessToken() async {
    return await _storage.read(key: AppConstants.cacheKeyToken);
  }

  // Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: AppConstants.cacheKeyRefreshToken);
  }

  // Delete tokens (logout)
  Future<void> deleteTokens() async {
    await Future.wait([
      _storage.delete(key: AppConstants.cacheKeyToken),
      _storage.delete(key: AppConstants.cacheKeyRefreshToken),
    ]);
  }

  // Clear all secure storage
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}

// Provider
final secureStorageProvider = Provider<SecureStorage>((ref) => SecureStorage());
