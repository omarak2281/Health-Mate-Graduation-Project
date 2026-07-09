import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:health_mate_app/features/symptom_checker/data/repositories/symptom_checker_repository_impl.dart';
import 'package:health_mate_app/features/symptom_checker/domain/entities/assessment_entities.dart';

final symptomCategoriesProvider =
    FutureProvider.family<List<SymptomCategoryEntity>, String>((ref, lang) {
  return ref.read(symptomCheckerRepositoryProvider).getCategories(lang);
});
