import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../storage/shared_prefs_cache.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  final SharedPrefsCache _prefs;

  ThemeNotifier(this._prefs) : super(ThemeMode.light) {
    _loadTheme();
  }

  void _loadTheme() {
    final mode = _prefs.getThemeMode();
    if (mode == 'dark') {
      state = ThemeMode.dark;
    } else {
      state = ThemeMode.light;
    }
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.light) {
      state = ThemeMode.dark;
      await _prefs.setThemeMode('dark');
    } else {
      state = ThemeMode.light;
      await _prefs.setThemeMode('light');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    await _prefs.setThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((ref) {
  final prefs = ref.watch(sharedPrefsCacheProvider);
  return ThemeNotifier(prefs);
});
