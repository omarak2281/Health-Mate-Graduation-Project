import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/constants/api_constants.dart';

// /**
//  * AI Repository
//  * Handles symptom checker chat
//  */

class AIRepository {
  final DioClient _dioClient;

  AIRepository(this._dioClient);

  // Send message to AI symptom checker
  Future<Map<String, dynamic>> sendMessage({
    required String message,
    String? sessionId,
  }) async {
    try {
      final response = await _dioClient.dio.post(
        ApiConstants.aiSymptomCheck,
        data: {'message': message, 'session_id': sessionId},
      );
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
