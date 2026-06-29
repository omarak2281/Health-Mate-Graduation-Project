import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

// /**
//  * SharedPreferences Cache Service
//  * For simple key-value storage and fallback caching
//  */

class SharedPrefsCache {
  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Language
  Future<void> setLanguage(String languageCode) async {
    await _prefs.setString(AppConstants.cacheKeyLanguage, languageCode);
  }

  String getLanguage() {
    return _prefs.getString(AppConstants.cacheKeyLanguage) ??
        AppConstants.englishCode;
  }

  // Theme Mode
  Future<void> setThemeMode(String themeMode) async {
    await _prefs.setString(AppConstants.cacheKeyThemeMode, themeMode);
  }

  String getThemeMode() {
    return _prefs.getString(AppConstants.cacheKeyThemeMode) ?? 'light';
  }

  // Latest BP (Fallback - simple string)
  Future<void> setLatestBP(String systolic, String diastolic) async {
    await Future.wait([
      _prefs.setString('latest_bp_systolic', systolic),
      _prefs.setString('latest_bp_diastolic', diastolic),
      _prefs.setString('latest_bp_timestamp', DateTime.now().toIso8601String()),
    ]);
  }

  Map<String, String>? getLatestBP() {
    final systolic = _prefs.getString('latest_bp_systolic');
    final diastolic = _prefs.getString('latest_bp_diastolic');
    final timestamp = _prefs.getString('latest_bp_timestamp');

    if (systolic != null && diastolic != null) {
      return {
        'systolic': systolic,
        'diastolic': diastolic,
        'timestamp': timestamp ?? '',
      };
    }
    return null;
  }

  // First Launch Flag
  Future<void> setFirstLaunch(bool isFirst) async {
    await _prefs.setBool('is_first_launch', isFirst);
  }

  bool isFirstLaunch() {
    return _prefs.getBool('is_first_launch') ?? true;
  }

  // Onboarding Completed
  Future<void> setOnboardingCompleted(bool completed) async {
    await _prefs.setBool('onboarding_completed', completed);
  }

  bool isOnboardingCompleted() {
    return _prefs.getBool('onboarding_completed') ?? false;
  }

  // Last Selected Role
  Future<void> setLastSelectedRole(String role) async {
    await _prefs.setString(AppConstants.cacheKeyLastRole, role);
  }

  String? getLastSelectedRole() {
    return _prefs.getString(AppConstants.cacheKeyLastRole);
  }

  // Medicine Tutorial Completed
  Future<void> setMedicineTutorialCompleted(bool completed) async {
    await _prefs.setBool('medicine_tutorial_completed', completed);
  }

  bool hasSeenMedicineTutorial() {
    return _prefs.getBool('medicine_tutorial_completed') ?? false;
  }

  // Clear all
  Future<void> clearAll() async {
    await _prefs.clear();
  }

  // Remove specific key
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }
}

// Provider
final sharedPrefsCacheProvider = Provider<SharedPrefsCache>(
  (ref) => SharedPrefsCache(),
);
