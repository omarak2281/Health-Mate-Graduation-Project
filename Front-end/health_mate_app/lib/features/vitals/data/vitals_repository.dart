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
    String source = 'manual',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.bpCreate,
        data: {
          'systolic': systolic,
          'diastolic': diastolic,
          'heart_rate': heartRate,
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

  // Get current BP
  Future<VitalSign?> getCurrentBP({String? patientId}) async {
    try {
      final url = patientId != null
          ? ApiConstants.patientBPCurrent(patientId)
          : ApiConstants.bpCurrent;
      final response = await _dioClient.dio.get(url);

      if (response.data != null) {
        final vitalSign = VitalSign.fromJson(response.data);

        // Cache it
        await _hiveCache.cacheLatestBP(vitalSign.toJson());

        return vitalSign;
      }
      return null;
    } catch (e) {
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
        queryParameters: {'skip': skip, 'limit': limit},
      );

      final List<VitalSign> history = (response.data as List)
          .map((json) => VitalSign.fromJson(json))
          .toList();

      // Cache history
      await _hiveCache.cacheBPHistory(history.map((v) => v.toJson()).toList());

      return history;
    } catch (e) {
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
