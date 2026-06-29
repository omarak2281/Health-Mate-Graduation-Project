import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// Hive Cache Service
/// For complex offline data (BP history, medications, etc.)

class HiveCache {
  late Box _vitalBox;
  late Box _medicationsBox;
  late Box _userBox;
  late Box _notificationsBox;

  Future<void> init() async {
    await Hive.initFlutter();

    _vitalBox = await Hive.openBox(AppConstants.hiveBoxVitals);
    _medicationsBox = await Hive.openBox(AppConstants.hiveBoxMedications);
    _userBox = await Hive.openBox(AppConstants.hiveBoxUser);
    _notificationsBox = await Hive.openBox(AppConstants.hiveBoxNotifications);
  }

  // BP History
  Future<void> cacheBPHistory(List<Map<String, dynamic>> history) async {
    await _vitalBox.put('bp_history', history);
  }

  List<Map<String, dynamic>>? getCachedBPHistory() {
    final data = _vitalBox.get('bp_history');
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return null;
  }

  // Latest BP
  Future<void> cacheLatestBP(Map<String, dynamic> bp) async {
    await _vitalBox.put('latest_bp', bp);
  }

  Map<String, dynamic>? getCachedLatestBP() {
    return _vitalBox.get('latest_bp');
  }

  // Medications
  Future<void> cacheMedications(List<Map<String, dynamic>> medications) async {
    await _medicationsBox.put('medications', medications);
  }

  List<Map<String, dynamic>>? getCachedMedications() {
    final data = _medicationsBox.get('medications');
    if (data != null) {
      return List<Map<String, dynamic>>.from(data);
    }
    return null;
  }

  // User Profile
  Future<void> cacheUser(Map<String, dynamic> user) async {
    await _userBox.put('user', user);
  }

  Map<String, dynamic>? getCachedUser() {
    final data = _userBox.get('user');
    if (data != null) {
      return Map<String, dynamic>.from(data as Map);
    }
    return null;
  }

  // Clear all
  Future<void> clearAll() async {
    await Future.wait([
      _vitalBox.clear(),
      _medicationsBox.clear(),
      _userBox.clear(),
      _notificationsBox.clear(),
    ]);
  }

  // Clear specific box
  Future<void> clearVitals() async => await _vitalBox.clear();
  Future<void> clearMedications() async => await _medicationsBox.clear();
  Future<void> clearUser() async => await _userBox.clear();
}

// Provider
final hiveCacheProvider = Provider<HiveCache>((ref) => HiveCache());
