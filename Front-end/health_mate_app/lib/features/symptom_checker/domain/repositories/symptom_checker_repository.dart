import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';

abstract class SymptomCheckerRepository {
  Future<List<SymptomCategoryEntity>> getCategories(String lang);
  Future<List<SymptomEntity>> getSymptoms(
      {String? categoryId, required String lang});
  Future<AssessmentResultEntity> runAssessment(
      AssessmentInputEntity input, String lang);
  Future<AssessmentResultEntity> runBpTriage(
      AssessmentInputEntity input, String lang);
  Future<String> startChatFromAssessment(
      AssessmentInputEntity input, String lang);
  Future<int> notifyCaregiver(AssessmentInputEntity input, String lang);
}
