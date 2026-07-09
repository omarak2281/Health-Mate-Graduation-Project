import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:health_mate_app/features/symptom_checker/data/repositories/symptom_checker_repository_impl.dart';
import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';

class AssessmentResultState {
  final AssessmentResultEntity? result;
  final bool isLoading;
  final bool isNotifyingCaregiver;
  final String? error;

  const AssessmentResultState({
    this.result,
    this.isLoading = false,
    this.isNotifyingCaregiver = false,
    this.error,
  });

  AssessmentResultState copyWith({
    AssessmentResultEntity? result,
    bool? isLoading,
    bool? isNotifyingCaregiver,
    String? error,
    bool clearResult = false,
    bool clearError = false,
  }) {
    return AssessmentResultState(
      result: clearResult ? null : result ?? this.result,
      isLoading: isLoading ?? this.isLoading,
      isNotifyingCaregiver: isNotifyingCaregiver ?? this.isNotifyingCaregiver,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class AssessmentResultNotifier extends StateNotifier<AssessmentResultState> {
  AssessmentResultNotifier(this._ref) : super(const AssessmentResultState());

  final Ref _ref;

  Future<bool> submit(AssessmentInputEntity input, String lang) async {
    state =
        state.copyWith(isLoading: true, clearError: true, clearResult: true);
    try {
      final repository = _ref.read(symptomCheckerRepositoryProvider);
      final result = input.sourceVitalId == null
          ? await repository.runAssessment(input, lang)
          : await repository.runBpTriage(input, lang);
      state = AssessmentResultState(result: result);
      return true;
    } catch (e) {
      state = AssessmentResultState(error: e.toString());
      return false;
    }
  }

  Future<String?> startChat(AssessmentInputEntity input, String lang) async {
    try {
      return await _ref
          .read(symptomCheckerRepositoryProvider)
          .startChatFromAssessment(input, lang);
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return null;
    }
  }

  Future<int?> notifyCaregiver(AssessmentInputEntity input, String lang) async {
    state = state.copyWith(isNotifyingCaregiver: true, clearError: true);
    try {
      final count = await _ref
          .read(symptomCheckerRepositoryProvider)
          .notifyCaregiver(input, lang);
      state = state.copyWith(isNotifyingCaregiver: false);
      return count;
    } catch (e) {
      state = state.copyWith(isNotifyingCaregiver: false, error: e.toString());
      return null;
    }
  }

  void reset() {
    state = const AssessmentResultState();
  }
}

final assessmentResultProvider =
    StateNotifierProvider<AssessmentResultNotifier, AssessmentResultState>(
        (ref) {
  return AssessmentResultNotifier(ref);
});
