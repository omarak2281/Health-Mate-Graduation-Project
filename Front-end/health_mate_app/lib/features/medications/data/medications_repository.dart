import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/hive_cache.dart';
import '../../../core/models/medication.dart';
import '../../../core/constants/api_constants.dart';

/// Medications Repository
/// Clean Architecture - Data Layer

class MedicationsRepository {
  final DioClient _dioClient;
  final HiveCache _hiveCache;

  MedicationsRepository(this._dioClient, this._hiveCache);

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
    required String frequency,
    required List<String> timeSlots,
    String? instructions,
    int? drawerNumber,
    bool enableLed = true,
    bool enableBuzzer = true,
    bool enableNotification = true,
    String? imageUrl,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.medications,
        data: {
          'name': name,
          'dosage': dosage,
          'frequency': frequency,
          'time_slots': timeSlots,
          'instructions': instructions,
          'drawer_number': drawerNumber,
          'enable_led': enableLed,
          'enable_buzzer': enableBuzzer,
          'enable_notification': enableNotification,
          'image_url': imageUrl,
        },
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
      await _dioClient.dio.delete(ApiConstants.medication(id));
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

  // Upload medication image
  Future<String> uploadMedicationImage(dynamic file) async {
    try {
      final formData = FormData.fromMap({'file': file});
      final response = await _dioClient.dio.post(
        ApiConstants.upload,
        data: formData,
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
}

// Provider
final medicationsRepositoryProvider = Provider<MedicationsRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  final hiveCache = ref.watch(hiveCacheProvider);

  return MedicationsRepository(dioClient, hiveCache);
});
