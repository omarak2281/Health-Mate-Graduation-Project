import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

/// AI Repository
/// Handles symptom checker chat and analysis

class AIRepository {
  final DioClient _dioClient;

  AIRepository(this._dioClient);

  // Send message to AI symptom checker
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
    String lang = 'en',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.aiChat,
        queryParameters: {'lang': lang},
        data: {
          'message': message,
          'session_id': sessionId,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Analyze symptoms with selected categories and symptoms
  Future<Map<String, dynamic>> analyzeSymptoms({
    required String category,
    required String subCategory,
    required List<String> symptomIds,
    String language = 'en',
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.aiSymptomCheck,
        data: {
          'category': category,
          'sub_category': subCategory,
          'symptoms': symptomIds,
          'language': language,
        },
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get available symptoms and categories
  Future<Map<String, dynamic>> getAvailableSymptoms() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.availableSymptoms);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get model information and metrics
  Future<Map<String, dynamic>> getModelInfo() async {
    try {
      final response = await _dioClient.dio.get(ApiConstants.aiModelInfo);
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  // Get chat history (if needed)
  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    try {
      final response = await _dioClient.dio.get(
        '${ApiConstants.aiSymptomCheck}/history/$sessionId',
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      return [];
    }
  }
}

// Provider
final aiRepositoryProvider = Provider<AIRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return AIRepository(dioClient);
});
