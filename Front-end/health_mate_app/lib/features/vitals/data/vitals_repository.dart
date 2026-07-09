import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../core/storage/shared_prefs_cache.dart';
import '../../../core/models/vital_sign.dart';
import '../../../core/constants/api_constants.dart';

/// Vitals Repository
/// Handles all vitals/BP operations with offline support
/// Clean Architecture - Data Layer

class VitalsRepository {
  final DioClient _dioClient;
  final HiveCache _hiveCache;
  final SharedPrefsCache _sharedPrefsCache;

  VitalsRepository(this._dioClient, this._hiveCache, this._sharedPrefsCache);

  // Create BP reading
  Future<VitalSign> createBPReading({
    required int systolic,
    required int diastolic,
    int? heartRate,
    int? spo2,
    String source = 'manual',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.bpCreate,
        data: {
          'systolic': systolic,
          'diastolic': diastolic,
          'heart_rate': heartRate,
          'spo2': spo2,
          'source': source,
        },
      );

      final vitalSign = VitalSign.fromJson(response.data);

      // Cache latest reading
      await _hiveCache.cacheLatestBP(vitalSign.toJson());
      await _sharedPrefsCache.setLatestBP(
        systolic.toString(),
        diastolic.toString(),
      );

      return vitalSign;
    } catch (e) {
      rethrow;
    }
  }

  // Submit device signal reading
  Future<VitalSign> submitDeviceReading({
    required String userId,
    required String deviceId,
    required List<double> ppgSignal,
    required List<double> ecgSignal,
    int? heartRate,
    int? spo2,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.bpSubmit,
        data: {
          'user_id': userId,
          'device_id': deviceId,
          'ppg_signal': ppgSignal,
          'ecg_signal': ecgSignal,
          'heart_rate': heartRate,
          'spo2': spo2,
        },
      );
      return VitalSign.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Complete pending BP reading with manual cuff measurement
  Future<VitalSign> completeReading({
    required String vitalSignId,
    required int systolic,
    required int diastolic,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.bpComplete,
        data: {
          'vital_sign_id': vitalSignId,
          'systolic': systolic,
          'diastolic': diastolic,
        },
      );

      final vitalSign = VitalSign.fromJson(response.data);

      // Cache latest reading
      await _hiveCache.cacheLatestBP(vitalSign.toJson());
      await _sharedPrefsCache.setLatestBP(
        systolic.toString(),
        diastolic.toString(),
      );

      return vitalSign;
    } catch (e) {
      rethrow;
    }
  }

  // Get current BP
  Future<VitalSign?> getCurrentBP({String? patientId}) async {
    try {
      final url = patientId != null
          ? ApiConstants.patientBPCurrent(patientId)
          : ApiConstants.bpCurrent;
      final response = await _dioClient.dio.get(url);

      if (response.data != null) {
        final vitalSign = VitalSign.fromJson(response.data);

        if (patientId == null) {
          await _hiveCache.cacheLatestBP(vitalSign.toJson());
        }

        return vitalSign;
      }
      return null;
    } catch (e) {
      if (patientId != null) {
        return null;
      }

      // Try cache
      final cachedBP = _hiveCache.getCachedLatestBP();
      if (cachedBP != null) {
        return VitalSign.fromJson(cachedBP);
      }
      return null;
    }
  }

  // Get BP history
  Future<List<VitalSign>> getBPHistory({
    int skip = 0,
    int limit = 20,
    String? patientId,
  }) async {
    try {
      final url = patientId != null
          ? ApiConstants.patientBPHistory(patientId)
          : ApiConstants.bpHistory;
      final response = await _dioClient.dio.get(
        url,
        queryParameters: {'offset': skip, 'limit': limit},
      );

      final List<VitalSign> history = (response.data as List)
          .map((json) => VitalSign.fromJson(json))
          .toList();

      if (patientId == null) {
        await _hiveCache
            .cacheBPHistory(history.map((v) => v.toJson()).toList());
      }

      return history;
    } catch (e) {
      if (patientId != null) {
        rethrow;
      }

      // Try cache
      final cachedHistory = _hiveCache.getCachedBPHistory();
      if (cachedHistory != null) {
        return cachedHistory.map((json) => VitalSign.fromJson(json)).toList();
      }
      rethrow;
    }
  }

  // Get BP statistics
  Future<Map<String, dynamic>> getBPStats() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.bpStats);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get calibration status (drives whether the cuff-entry step is shown)
  Future<Map<String, dynamic>> getCalibrationStatus() async {
    try {
      final response =
          await _dioClient.dio.get(ApiConstants.bpCalibrationStatus);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  // Schedule the 3 fixed daily BP reminders from one chosen start time
  Future<List<Map<String, dynamic>>> scheduleDailyBPReminders(
      String startTime) async {
    final response = await _dioClient.dio.post(
      ApiConstants.bpRemindersScheduleDaily,
      data: {'start_time': startTime},
    );
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  // Fetch the currently scheduled daily BP reminders (read-only display)
  Future<List<Map<String, dynamic>>> getBPReminders() async {
    final response = await _dioClient.dio.get(ApiConstants.bpReminders);
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  // Get cached BP (offline)
  VitalSign? getCachedLatestBP() {
    final cachedBP = _hiveCache.getCachedLatestBP();
    if (cachedBP != null) {
      return VitalSign.fromJson(cachedBP);
    }
    return null;
  }
}

// Provider
final vitalsRepositoryProvider = Provider<VitalsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final hiveCache = ref.watch(hiveCacheProvider);
  final sharedPrefsCache = ref.watch(sharedPrefsCacheProvider);

  return VitalsRepository(dioClient, hiveCache, sharedPrefsCache);
});
