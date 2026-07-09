import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// A lightweight translator that works in background isolates where
/// EasyLocalization is not initialized.
class BackgroundTranslationService {
  BackgroundTranslationService._();
  static final BackgroundTranslationService instance =
      BackgroundTranslationService._();

  Map<String, dynamic>? _enMap;
  Map<String, dynamic>? _arMap;
  String? _cachedLocale;
  bool _isLoading = false;

  Future<void> init() async {
    if (_enMap != null && _arMap != null) return;
    if (_isLoading) return;
    _isLoading = true;

    try {
      final enContent = await loadAsset('assets/translations/en.json');
      final arContent = await loadAsset('assets/translations/ar.json');

      _enMap = jsonDecode(enContent);
      _arMap = jsonDecode(arContent);
      await refreshLocale();
      debugPrint(
          '[BackgroundTranslation] ✅ Successfully loaded translation maps');
    } catch (e) {
      debugPrint('[BackgroundTranslation] ❌ Error loading translations: $e');
    } finally {
      _isLoading = false;
    }
  }

  Future<String> loadAsset(String path) async {
    return await rootBundle.loadString(path);
  }

  Future<void> refreshLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedLocale = prefs.getString(AppConstants.cacheKeyLanguage);
    } catch (_) {}
  }

  /// Translate a key. Language is determined by system locale or passed manually.
  String translate(String key,
      {String? locale, Map<String, String>? namedArgs}) {
    final targetLocale = locale ?? _cachedLocale ?? 'en';
    final map = targetLocale == 'ar' ? _arMap : _enMap;

    if (map == null) return key;

    // Handle nested keys (e.g. 'medications.alarm_title')
    var value = _getNestedValue(map, key);

    if (value == null) return key;

    // Handle named arguments (e.g. {name})
    if (namedArgs != null) {
      namedArgs.forEach((k, v) {
        value = value!.replaceAll('{$k}', v);
      });
    }

    return value!;
  }

  String? _getNestedValue(Map<String, dynamic> map, String key) {
    final parts = key.split('.');
    dynamic current = map;

    for (final part in parts) {
      if (current is Map && current.containsKey(part)) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current is String ? current : null;
  }
}
