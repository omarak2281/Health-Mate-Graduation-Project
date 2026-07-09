import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/assessment_flow_provider.dart';
import '../widgets/wizard_bottom_actions.dart';

class SymptomSelectionPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;

  const SymptomSelectionPage({
    super.key,
    required this.onNext,
    required this.onBack,
  });

  @override
  ConsumerState<SymptomSelectionPage> createState() =>
      _SymptomSelectionPageState();
}

class _SymptomSelectionPageState extends ConsumerState<SymptomSelectionPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final flow = ref.watch(assessmentFlowProvider);
    final normalizedQuery = _query.toLowerCase().trim();
    final filtered = flow.symptoms.where((symptom) {
      if (normalizedQuery.isEmpty) return true;
      return symptom.name.toLowerCase().contains(normalizedQuery) ||
          symptom.id.toLowerCase().contains(normalizedQuery) ||
          symptom.synonyms.any(
            (synonym) => synonym.toLowerCase().contains(normalizedQuery),
          );
    }).toList();

    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(context.w(5), context.h(2), context.w(5), 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'symptom_checker_v2.symptoms_title'.tr(),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'symptom_checker_v2.search_symptoms'.tr(),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
            ],
          ),
        ),
        if (flow.isLoadingSymptoms)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: context.w(5)),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final symptom = filtered[index];
                final selected = flow.selectedSymptoms.containsKey(symptom.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: (_) {
                    ref
                        .read(assessmentFlowProvider.notifier)
                        .toggleSymptom(symptom);
                  },
                  title: Text(symptom.name,
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: symptom.description == null ||
                          symptom.description!.isEmpty
                      ? null
                      : Text(symptom.description!,
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                  secondary: symptom.redFlag
                      ? const Icon(Icons.warning_amber_rounded,
                          color: AppColors.riskCritical)
                      : const Icon(Icons.check_circle_outline_rounded),
                  controlAffinity: ListTileControlAffinity.trailing,
                );
              },
            ),
          ),
        WizardBottomActions(
          onBack: widget.onBack,
          onNext: flow.selectedSymptoms.isEmpty ? null : widget.onNext,
          nextLabel: 'common.next'.tr(),
        ),
      ],
    );
  }
}
