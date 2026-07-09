import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/utils/responsive.dart';
import '../providers/assessment_flow_provider.dart';
import '../widgets/severity_selector.dart';
import '../widgets/wizard_bottom_actions.dart';

class SymptomSeverityPage extends ConsumerWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SymptomSeverityPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(assessmentFlowProvider).selectedSymptoms.values.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(context.w(5)),
          child: Text(
            'symptom_checker_v2.severity_title'.tr(),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.symmetric(horizontal: context.w(5)),
            itemCount: selected.length,
            itemBuilder: (context, index) {
              final symptom = selected[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(symptom.name,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    SeveritySelector(
                      value: symptom.severity,
                      onChanged: (value) {
                        ref
                            .read(assessmentFlowProvider.notifier)
                            .setSeverity(symptom.id, value);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        WizardBottomActions(onBack: onBack, onNext: onNext),
      ],
    );
  }
}
