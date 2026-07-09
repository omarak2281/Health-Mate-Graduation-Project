import 'package:flutter_test/flutter_test.dart';
import 'package:health_mate_app/features/symptom_checker/data/models/symptom_checker_models.dart';
import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';

void main() {
  test('structured assessment input serializes to the backend contract', () {
    const input = AssessmentInputEntity(
      sourceVitalId: '11111111-1111-1111-1111-111111111111',
      categoryId: 'heart_bp',
      symptoms: [
        SelectedSymptomEntity(
          id: 'chest_pain',
          name: 'Chest Pain',
          severity: 3,
          redFlag: true,
        ),
      ],
      durationDays: 1,
      ageGroup: 'adult',
      knownConditions: ['hypertension'],
      vitals: AssessmentVitalsEntity(systolic: 150, diastolic: 95),
    );

    expect(input.toJson(), {
      'source_vital_id': '11111111-1111-1111-1111-111111111111',
      'category_id': 'heart_bp',
      'symptoms': [
        {'id': 'chest_pain', 'severity': 3},
      ],
      'duration_days': 1,
      'age_group': 'adult',
      'known_conditions': ['hypertension'],
      'vitals': {'systolic': 150, 'diastolic': 95},
    });
  });

  test('symptom model parses synonyms for local search', () {
    final symptom = SymptomModel.fromJson({
      'id': 'cough',
      'name': 'Cough',
      'description': 'Airway clearing cough',
      'red_flag': false,
      'synonyms': ['coughing', 'كحة'],
    });

    expect(symptom.synonyms, contains('coughing'));
    expect(symptom.synonyms, contains('كحة'));
  });
}
