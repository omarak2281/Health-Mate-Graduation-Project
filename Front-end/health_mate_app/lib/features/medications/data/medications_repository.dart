import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../core/models/medication.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/services/iot_service.dart';

/// Medications Repository
/// Clean Architecture - Data Layer

class MedicationsRepository {
  final DioClient _dioClient;
  final HiveCache _hiveCache;
  final IoTService _iotService;

  MedicationsRepository(this._dioClient, this._hiveCache, this._iotService);

  // Get all medications
  Future<List<Medication>> getMedications({String? patientId}) async {
    try {
      final url = patientId != null
          ? ApiConstants.patientMedications(patientId)
          : ApiConstants.medications;
      final response = await _dioClient.dio.get(url);

      final List<Medication> medications = (response.data as List)
          .map((json) => Medication.fromJson(json))
          .toList();

      // Cache medications
      await _hiveCache.cacheMedications(
        medications.map((m) => m.toJson()).toList(),
      );

      return medications;
    } catch (e) {
      // Try cache
      final cachedMeds = _hiveCache.getCachedMedications();
      if (cachedMeds != null) {
        return cachedMeds.map((json) => Medication.fromJson(json)).toList();
      }
      rethrow;
    }
  }

  // Create medication
  Future<Medication> createMedication({
    required String name,
    required String dosage,
    required int timesPerDay,
    required List<String> scheduledTimes,
    String? instructions,
    bool useSmartBox = false,
    int? drawerNumber,
    String? imageUrl,
    String? patientId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'name': name,
        'dosage': dosage,
        'times_per_day': timesPerDay,
        'scheduled_times': scheduledTimes,
        'instructions': instructions,
        'use_smart_box': useSmartBox,
        'drawer_number': drawerNumber,
        'image_url': imageUrl,
      };

      if (patientId != null) {
        data['patient_id'] = patientId;
      }

      final response = await _dioClient.dio.post(
        ApiConstants.medications,
        data: data,
      );

      return Medication.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Update medication
  Future<Medication> updateMedication(
    String id,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dioClient.dio.put(
        ApiConstants.medication(id),
        data: updates,
      );

      return Medication.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  // Delete medication
  Future<void> deleteMedication(String id) async {
    try {
      await _dioClient.dio.delete(
        ApiConstants.medication(id),
        options: Options(
          // Explicitly accept 204 No Content as a valid success response
          validateStatus: (status) => status != null && status < 300,
        ),
      );

      // Refresh cache after deletion
      final currentMeds = await getMedications();
      await _hiveCache.cacheMedications(
        currentMeds.map((m) => m.toJson()).toList(),
      );
    } catch (e) {
      rethrow;
    }
  }

  // Confirm medication taken
  Future<void> confirmMedication(String id) async {
    try {
      await _dioClient.dio.post(ApiConstants.medicationConfirm(id));
    } catch (e) {
      rethrow;
    }
  }

  // Confirm multiple medications taken (Bulk)
  Future<void> confirmMultipleMedications(List<String> ids) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.medicationsTaken,
        data: ids,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Request cloud snooze from backend
  Future<void> snoozeMedications(List<String> ids) async {
    try {
      await _dioClient.dio.post(
        ApiConstants.medicationsSnooze,
        data: ids,
      );
    } catch (e) {
      rethrow;
    }
  }

  // Upload medication image
  Future<String> uploadMedicationImage(dynamic file) async {
    try {
      final formData = FormData.fromMap({'file': file});
      final response = await _dioClient.dio.post(
        ApiConstants.uploadMedicationImage,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout:
              const Duration(seconds: 60), // Allow more time for Cloudinary
          sendTimeout: const Duration(seconds: 60),
        ),
      );
      return response.data['url'];
    } catch (e) {
      rethrow;
    }
  }

  // Get cached medications (offline)
  List<Medication>? getCachedMedications() {
    final cachedMeds = _hiveCache.getCachedMedications();
    if (cachedMeds != null) {
      return cachedMeds.map((json) => Medication.fromJson(json)).toList();
    }
    return null;
  }

  /// Silence the hardware immediately by sending an empty drawers payload.
  /// Used during snooze to turn off all LEDs and the buzzer without
  /// marking the medication as taken.
  ///
  /// Payload sent to ESP32: `{"drawers": []}`
  Future<void> snoozeHardware() => _iotService.controlDrawers([]);
}

// Provider
final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final hiveCache = ref.watch(hiveCacheProvider);
  final iotService = ref.watch(iotServiceProvider);

  return MedicationsRepository(dioClient, hiveCache, iotService);
});
