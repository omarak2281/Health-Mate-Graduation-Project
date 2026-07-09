import 'package:health_mate_app/core/constants/api_constants.dart';
import 'package:health_mate_app/core/network/dio_client.dart';

class SymptomCheckerRemoteDataSource {
  final DioClient _dioClient;

  SymptomCheckerRemoteDataSource(this._dioClient);

  Future<List<dynamic>> getCategories(String lang) async {
    final response = await _dioClient.dio.get(
      ApiConstants.aiCategories,
      queryParameters: {'lang': lang},
    );
    return response.data as List<dynamic>;
  }

  Future<List<dynamic>> getSymptoms(
      {String? categoryId, required String lang}) async {
    final response = await _dioClient.dio.get(
      ApiConstants.aiTaxonomySymptoms,
      queryParameters: {
        'lang': lang,
        if (categoryId != null) 'category_id': categoryId,
      },
    );
    return response.data as List<dynamic>;
  }

  Future<Map<String, dynamic>> runAssessment(
      Map<String, dynamic> body, String lang) async {
    final response = await _dioClient.dio.post(
      ApiConstants.aiAssessment,
      queryParameters: {'lang': lang},
      data: body,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> runBpTriage(
      Map<String, dynamic> body, String lang) async {
    final response = await _dioClient.dio.post(
      ApiConstants.aiBpTriage,
      queryParameters: {'lang': lang},
      data: body,
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<String> startChatFromAssessment(
      Map<String, dynamic> body, String lang) async {
    final response = await _dioClient.dio.post(
      ApiConstants.aiChatFromAssessment,
      queryParameters: {'lang': lang},
      data: body,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['assessment_id'] as String;
  }

  Future<int> notifyCaregiver(Map<String, dynamic> body, String lang) async {
    final response = await _dioClient.dio.post(
      ApiConstants.aiAssessmentNotifyCaregiver,
      queryParameters: {'lang': lang},
      data: body,
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    return data['notified_count'] as int? ?? 0;
  }
}
