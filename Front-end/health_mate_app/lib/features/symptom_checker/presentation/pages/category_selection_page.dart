import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/assessment_flow_provider.dart';
import '../providers/category_provider.dart';

class CategorySelectionPage extends ConsumerWidget {
  final String lang;
  final VoidCallback onNext;

  const CategorySelectionPage({
    super.key,
    required this.lang,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(symptomCategoriesProvider(lang));
    final flow = ref.watch(assessmentFlowProvider);

    return categories.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _ErrorState(message: error.toString()),
      data: (items) => ListView(
        padding: EdgeInsets.all(context.w(5)),
        children: [
          _StepHeader(
            title: 'symptom_checker_v2.category_title'.tr(),
            subtitle: 'symptom_checker_v2.category_subtitle'.tr(),
          ),
          SizedBox(height: context.h(2)),
          ...items.map((category) {
            final selected = flow.category?.id == category.id;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () async {
                  await ref
                      .read(assessmentFlowProvider.notifier)
                      .selectCategory(category, lang);
                  onNext();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : Theme.of(context).cardColor,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(_iconForCategory(category.id), color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  IconData _iconForCategory(String id) {
    return switch (id) {
      'heart_bp' => Icons.favorite_rounded,
      'respiratory' => Icons.air_rounded,
      'neurological' => Icons.psychology_rounded,
      'digestive' => Icons.restaurant_rounded,
      'muscles_joints' => Icons.accessibility_new_rounded,
      'skin' => Icons.healing_rounded,
      'urinary_kidney' => Icons.water_drop_rounded,
      'mental_health' => Icons.self_improvement_rounded,
      _ => Icons.medical_services_rounded,
    };
  }
}

class _StepHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StepHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(subtitle, style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;

  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
