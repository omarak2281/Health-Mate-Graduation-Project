import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';

class SymptomCategoryModel extends SymptomCategoryEntity {
  const SymptomCategoryModel({
    required super.id,
    required super.name,
    required super.order,
  });

  factory SymptomCategoryModel.fromJson(Map<String, dynamic> json) {
    return SymptomCategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      order: (json['order'] as num).toInt(),
    );
  }
}

class SymptomModel extends SymptomEntity {
  const SymptomModel({
    required super.id,
    required super.name,
    super.description,
    required super.redFlag,
    super.synonyms,
  });

  factory SymptomModel.fromJson(Map<String, dynamic> json) {
    return SymptomModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      redFlag: json['red_flag'] as bool? ?? false,
      synonyms:
          List<String>.from(json['synonyms'] as List<dynamic>? ?? const []),
    );
  }
}

class AssessmentResultModel extends AssessmentResultEntity {
  const AssessmentResultModel({
    required super.topPredictions,
    required super.urgency,
    required super.urgencyLabel,
    required super.redFlags,
    required super.patientMessage,
    required super.recommendedActionCode,
    required super.recommendedActionText,
    required super.caregiverSummary,
    required super.shouldNotifyCaregiver,
    required super.shouldRemeasure,
    required super.disclaimer,
  });

  factory AssessmentResultModel.fromJson(Map<String, dynamic> json) {
    return AssessmentResultModel(
      topPredictions: (json['top_predictions'] as List<dynamic>? ?? [])
          .map(
            (item) => TopPredictionEntity(
              diseaseId: item['disease_id'] as String,
              name: item['name'] as String,
              confidence: (item['confidence'] as num).toDouble(),
              why: List<String>.from(item['why'] as List<dynamic>? ?? const []),
              whyNames: List<String>.from(item['why_names'] as List<dynamic>? ?? const []),
            ),
          )
          .toList(),
      urgency: json['urgency'] as String,
      urgencyLabel: json['urgency_label'] as String,
      redFlags: (json['red_flags'] as List<dynamic>? ?? [])
          .map(
            (item) => RedFlagEntity(
              code: item['code'] as String,
              name: item['name'] as String? ?? item['code'] as String,
              severity: (item['severity'] as num).toInt(),
            ),
          )
          .toList(),
      patientMessage: json['patient_message'] as String,
      recommendedActionCode: json['recommended_action_code'] as String,
      recommendedActionText: json['recommended_action_text'] as String,
      caregiverSummary: json['caregiver_summary'] as String,
      shouldNotifyCaregiver: json['should_notify_caregiver'] as bool? ?? false,
      shouldRemeasure: json['should_remeasure'] as bool? ?? false,
      disclaimer: json['disclaimer'] as String,
    );
  }
}
