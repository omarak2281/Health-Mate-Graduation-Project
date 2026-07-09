class SymptomCategoryEntity {
  final String id;
  final String name;
  final int order;

  const SymptomCategoryEntity({
    required this.id,
    required this.name,
    required this.order,
  });
}

class SymptomEntity {
  final String id;
  final String name;
  final String? description;
  final bool redFlag;
  final List<String> synonyms;

  const SymptomEntity({
    required this.id,
    required this.name,
    this.description,
    required this.redFlag,
    this.synonyms = const [],
  });
}

class SelectedSymptomEntity {
  final String id;
  final String name;
  final int severity;
  final bool redFlag;

  const SelectedSymptomEntity({
    required this.id,
    required this.name,
    required this.severity,
    required this.redFlag,
  });

  SelectedSymptomEntity copyWith({int? severity}) {
    return SelectedSymptomEntity(
      id: id,
      name: name,
      severity: severity ?? this.severity,
      redFlag: redFlag,
    );
  }
}

class AssessmentVitalsEntity {
  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final double? spo2;

  const AssessmentVitalsEntity({
    this.systolic,
    this.diastolic,
    this.heartRate,
    this.spo2,
  });

  Map<String, dynamic> toJson() => {
        if (systolic != null) 'systolic': systolic,
        if (diastolic != null) 'diastolic': diastolic,
        if (heartRate != null) 'heart_rate': heartRate,
        if (spo2 != null) 'spo2': spo2,
      };
}

class AssessmentInputEntity {
  final String? sourceVitalId;
  final String? categoryId;
  final List<SelectedSymptomEntity> symptoms;
  final int? durationDays;
  final String? ageGroup;
  final List<String> knownConditions;
  final AssessmentVitalsEntity? vitals;

  const AssessmentInputEntity({
    this.sourceVitalId,
    this.categoryId,
    required this.symptoms,
    this.durationDays,
    this.ageGroup,
    this.knownConditions = const [],
    this.vitals,
  });

  Map<String, dynamic> toJson() => {
        if (sourceVitalId != null) 'source_vital_id': sourceVitalId,
        'category_id': categoryId,
        'symptoms': symptoms
            .map((symptom) => {
                  'id': symptom.id,
                  'severity': symptom.severity,
                })
            .toList(),
        if (durationDays != null) 'duration_days': durationDays,
        if (ageGroup != null) 'age_group': ageGroup,
        'known_conditions': knownConditions,
        if (vitals != null && vitals!.toJson().isNotEmpty)
          'vitals': vitals!.toJson(),
      };
}

class TopPredictionEntity {
  final String diseaseId;
  final String name;
  final double confidence;
  final List<String> why;
  /// Localized, human-readable labels for [why] (same order/length) -- [why]
  /// itself holds raw taxonomy symptom ids and must never be shown directly.
  final List<String> whyNames;

  const TopPredictionEntity({
    required this.diseaseId,
    required this.name,
    required this.confidence,
    required this.why,
    this.whyNames = const [],
  });
}

class RedFlagEntity {
  final String code;
  final String name;
  final int severity;

  const RedFlagEntity({required this.code, required this.name, required this.severity});
}

class AssessmentResultEntity {
  final List<TopPredictionEntity> topPredictions;
  final String urgency;
  final String urgencyLabel;
  final List<RedFlagEntity> redFlags;
  final String patientMessage;
  final String recommendedActionCode;
  final String recommendedActionText;
  final String caregiverSummary;
  final bool shouldNotifyCaregiver;
  final bool shouldRemeasure;
  final String disclaimer;

  const AssessmentResultEntity({
    required this.topPredictions,
    required this.urgency,
    required this.urgencyLabel,
    required this.redFlags,
    required this.patientMessage,
    required this.recommendedActionCode,
    required this.recommendedActionText,
    required this.caregiverSummary,
    required this.shouldNotifyCaregiver,
    required this.shouldRemeasure,
    required this.disclaimer,
  });
}
