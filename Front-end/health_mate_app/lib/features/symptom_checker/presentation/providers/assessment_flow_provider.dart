import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';
import 'package:health_mate_app/features/symptom_checker/data/repositories/symptom_checker_repository_impl.dart';

class AssessmentFlowState {
  final String? sourceVitalId;
  final SymptomCategoryEntity? category;
  final List<SymptomEntity> symptoms;
  final Map<String, SelectedSymptomEntity> selectedSymptoms;
  final int? durationDays;
  final String? ageGroup;
  final List<String> knownConditions;
  final AssessmentVitalsEntity? vitals;
  final bool isLoadingSymptoms;
  final String? error;

  const AssessmentFlowState({
    this.sourceVitalId,
    this.category,
    this.symptoms = const [],
    this.selectedSymptoms = const {},
    this.durationDays,
    this.ageGroup,
    this.knownConditions = const [],
    this.vitals,
    this.isLoadingSymptoms = false,
    this.error,
  });

  AssessmentInputEntity toInput() {
    return AssessmentInputEntity(
      sourceVitalId: sourceVitalId,
      categoryId: category?.id,
      symptoms: selectedSymptoms.values.toList(),
      durationDays: durationDays,
      ageGroup: ageGroup,
      knownConditions: knownConditions,
      vitals: vitals,
    );
  }

  AssessmentFlowState copyWith({
    String? sourceVitalId,
    SymptomCategoryEntity? category,
    List<SymptomEntity>? symptoms,
    Map<String, SelectedSymptomEntity>? selectedSymptoms,
    int? durationDays,
    String? ageGroup,
    List<String>? knownConditions,
    AssessmentVitalsEntity? vitals,
    bool? isLoadingSymptoms,
    String? error,
    bool clearCategory = false,
    bool clearSourceVital = false,
    bool clearDuration = false,
    bool clearAgeGroup = false,
    bool clearVitals = false,
  }) {
    return AssessmentFlowState(
      sourceVitalId:
          clearSourceVital ? null : sourceVitalId ?? this.sourceVitalId,
      category: clearCategory ? null : category ?? this.category,
      symptoms: symptoms ?? this.symptoms,
      selectedSymptoms: selectedSymptoms ?? this.selectedSymptoms,
      durationDays: clearDuration ? null : durationDays ?? this.durationDays,
      ageGroup: clearAgeGroup ? null : ageGroup ?? this.ageGroup,
      knownConditions: knownConditions ?? this.knownConditions,
      vitals: clearVitals ? null : vitals ?? this.vitals,
      isLoadingSymptoms: isLoadingSymptoms ?? this.isLoadingSymptoms,
      error: error,
    );
  }
}

class AssessmentFlowNotifier extends StateNotifier<AssessmentFlowState> {
  AssessmentFlowNotifier(this._ref) : super(const AssessmentFlowState());

  final Ref _ref;

  Future<void> selectCategory(
      SymptomCategoryEntity category, String lang) async {
    state = state.copyWith(
      category: category,
      symptoms: [],
      selectedSymptoms: {},
      isLoadingSymptoms: true,
      error: null,
      clearSourceVital: true,
      clearVitals: true,
    );
    try {
      final symptoms = await _ref
          .read(symptomCheckerRepositoryProvider)
          .getSymptoms(categoryId: category.id, lang: lang);
      state = state.copyWith(symptoms: symptoms, isLoadingSymptoms: false);
    } catch (e) {
      state = state.copyWith(isLoadingSymptoms: false, error: e.toString());
    }
  }

  Future<bool> startBpTriage({
    required String lang,
    required String sourceVitalId,
    required AssessmentVitalsEntity vitals,
  }) async {
    state = state.copyWith(
      sourceVitalId: sourceVitalId,
      category: null,
      symptoms: [],
      selectedSymptoms: {},
      vitals: vitals,
      isLoadingSymptoms: true,
      error: null,
    );
    try {
      final categories =
          await _ref.read(symptomCheckerRepositoryProvider).getCategories(lang);
      final heartCategory = categories.firstWhere(
        (category) => category.id == 'heart_bp',
      );
      final symptoms = await _ref
          .read(symptomCheckerRepositoryProvider)
          .getSymptoms(categoryId: heartCategory.id, lang: lang);
      state = state.copyWith(
        sourceVitalId: sourceVitalId,
        category: heartCategory,
        symptoms: symptoms,
        selectedSymptoms: {},
        vitals: vitals,
        isLoadingSymptoms: false,
        error: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoadingSymptoms: false, error: e.toString());
      return false;
    }
  }

  void toggleSymptom(SymptomEntity symptom) {
    final next =
        Map<String, SelectedSymptomEntity>.from(state.selectedSymptoms);
    if (next.containsKey(symptom.id)) {
      next.remove(symptom.id);
    } else {
      next[symptom.id] = SelectedSymptomEntity(
        id: symptom.id,
        name: symptom.name,
        severity: symptom.redFlag ? 3 : 2,
        redFlag: symptom.redFlag,
      );
    }
    state = state.copyWith(selectedSymptoms: next);
  }

  void setSeverity(String symptomId, int severity) {
    final selected = state.selectedSymptoms[symptomId];
    if (selected == null) return;
    final next =
        Map<String, SelectedSymptomEntity>.from(state.selectedSymptoms);
    next[symptomId] = selected.copyWith(severity: severity);
    state = state.copyWith(selectedSymptoms: next);
  }

  void setFollowUp({
    int? durationDays,
    String? ageGroup,
    List<String>? knownConditions,
    AssessmentVitalsEntity? vitals,
  }) {
    state = state.copyWith(
      durationDays: durationDays,
      ageGroup: ageGroup,
      knownConditions: knownConditions,
      vitals: vitals,
      clearDuration: durationDays == null,
      clearAgeGroup: ageGroup == null,
      clearVitals: vitals == null,
    );
  }

  void reset() {
    state = const AssessmentFlowState();
  }
}

final assessmentFlowProvider =
    StateNotifierProvider<AssessmentFlowNotifier, AssessmentFlowState>((ref) {
  return AssessmentFlowNotifier(ref);
});
