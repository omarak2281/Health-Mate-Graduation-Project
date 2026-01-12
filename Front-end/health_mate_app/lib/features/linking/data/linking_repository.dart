import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

/// Linking Repository
/// Handles linking patients and caregivers

class LinkingRepository {
  final DioClient _dioClient;

  LinkingRepository(this._dioClient);

  // Link patient (Caregiver scans Patient)
  Future<void> linkPatient({required String patientId}) async {
    try {
      await _dioClient.dio.post(ApiConstants.userLink(patientId));
    } catch (e) {
      rethrow;
    }
  }

  // Get linked users
  Future<List<dynamic>> getLinkedUsers() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.userLinked);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Unlink user
  Future<void> unlinkUser(String userId) async {
    try {
      await _dioClient.dio.delete(ApiConstants.userUnlink(userId));
    } catch (e) {
      rethrow;
    }
  }
}

// Provider
final linkingRepositoryProvider = Provider<LinkingRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return LinkingRepository(dioClient);
});
