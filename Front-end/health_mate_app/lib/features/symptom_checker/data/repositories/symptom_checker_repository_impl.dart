import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:health_mate_app/core/network/dio_client.dart';
import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';
import 'package:health_mate_app/features/symptom_checker/domain/repositories/symptom_checker_repository.dart';
import 'package:health_mate_app/features/symptom_checker/data/datasources/symptom_checker_remote_datasource.dart';
import 'package:health_mate_app/features/symptom_checker/data/models/symptom_checker_models.dart';

class SymptomCheckerRepositoryImpl implements SymptomCheckerRepository {
  final SymptomCheckerRemoteDataSource _remote;

  SymptomCheckerRepositoryImpl(this._remote);

  @override
  Future<List<SymptomCategoryEntity>> getCategories(String lang) async {
    final data = await _remote.getCategories(lang);
    return data
        .map((item) => SymptomCategoryModel.fromJson(
            Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<List<SymptomEntity>> getSymptoms(
      {String? categoryId, required String lang}) async {
    final data = await _remote.getSymptoms(categoryId: categoryId, lang: lang);
    return data
        .map((item) =>
            SymptomModel.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Future<AssessmentResultEntity> runAssessment(
      AssessmentInputEntity input, String lang) async {
    final data = await _remote.runAssessment(input.toJson(), lang);
    return AssessmentResultModel.fromJson(data);
  }

  @override
  Future<AssessmentResultEntity> runBpTriage(
      AssessmentInputEntity input, String lang) async {
    final data = await _remote.runBpTriage(input.toJson(), lang);
    return AssessmentResultModel.fromJson(data);
  }

  @override
  Future<String> startChatFromAssessment(
      AssessmentInputEntity input, String lang) {
    return _remote.startChatFromAssessment(input.toJson(), lang);
  }

  @override
  Future<int> notifyCaregiver(AssessmentInputEntity input, String lang) {
    return _remote.notifyCaregiver(input.toJson(), lang);
  }
}

final symptomCheckerRepositoryProvider =
    Provider<SymptomCheckerRepository>((ref) {
  final dioClient = ref.watch(dioClientProvider);
  return SymptomCheckerRepositoryImpl(
      SymptomCheckerRemoteDataSource(dioClient));
});
