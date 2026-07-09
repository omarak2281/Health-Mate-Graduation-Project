import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/utils/responsive.dart';
import '../../domain/entities/assessment_entities.dart';
import '../providers/assessment_flow_provider.dart';
import '../widgets/wizard_bottom_actions.dart';

class FollowupQuestionsPage extends ConsumerStatefulWidget {
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const FollowupQuestionsPage({
    super.key,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  ConsumerState<FollowupQuestionsPage> createState() =>
      _FollowupQuestionsPageState();
}

class _FollowupQuestionsPageState extends ConsumerState<FollowupQuestionsPage> {
  final _durationController = TextEditingController(text: '1');
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _heartRateController = TextEditingController();
  String _ageGroup = 'adult';
  final Set<String> _knownConditions = {};

  @override
  void initState() {
    super.initState();
    _applyVitals(ref.read(assessmentFlowProvider).vitals);
  }

  void _applyVitals(AssessmentVitalsEntity? vitals) {
    if (vitals == null) return;
    // Only auto-fill empty fields so this never clobbers text the user already typed.
    if (_systolicController.text.isEmpty) {
      _systolicController.text = vitals.systolic?.toString() ?? '';
    }
    if (_diastolicController.text.isEmpty) {
      _diastolicController.text = vitals.diastolic?.toString() ?? '';
    }
    if (_heartRateController.text.isEmpty) {
      _heartRateController.text = vitals.heartRate?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _durationController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    _heartRateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The wizard's PageView builds every step eagerly (see
    // symptom_checker_wizard_page.dart), so for a BP-triage flow this page's initState runs
    // BEFORE SymptomCheckerWizardPage's post-frame `_startBpFlow()` has finished loading the
    // real BP reading into assessmentFlowProvider. Without this listener the vitals fields
    // stay empty and setFollowUp() below would silently submit the assessment with no vitals
    // at all, which defeats the whole point of the BP-integration hook.
    ref.listen<AssessmentFlowState>(assessmentFlowProvider, (previous, next) {
      if (previous?.vitals != next.vitals) _applyVitals(next.vitals);
    });
    return ListView(
      padding: EdgeInsets.all(context.w(5)),
      children: [
        Text(
          'symptom_checker_v2.followup_title'.tr(),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: 'symptom_checker_v2.duration_days'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _ageGroup,
          decoration: InputDecoration(
            labelText: 'symptom_checker_v2.age_group'.tr(),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
          items: const ['child', 'adult', 'elderly']
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text('symptom_checker_v2.age_$value'.tr()),
                ),
              )
              .toList(),
          onChanged: (value) => setState(() => _ageGroup = value ?? 'adult'),
        ),
        const SizedBox(height: 16),
        Text('symptom_checker_v2.known_conditions'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const ['hypertension', 'asthma', 'diabetes_mellitus_type_2']
              .map(
                (condition) => FilterChip(
                  label: Text('symptom_checker_v2.condition_$condition'.tr()),
                  selected: _knownConditions.contains(condition),
                  onSelected: (_) => setState(() {
                    if (_knownConditions.contains(condition)) {
                      _knownConditions.remove(condition);
                    } else {
                      _knownConditions.add(condition);
                    }
                  }),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 18),
        Text('symptom_checker_v2.vitals_optional'.tr()),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _numberField(
                    _systolicController, 'symptom_checker_v2.systolic'.tr())),
            const SizedBox(width: 10),
            Expanded(
                child: _numberField(
                    _diastolicController, 'symptom_checker_v2.diastolic'.tr())),
          ],
        ),
        const SizedBox(height: 10),
        _numberField(
            _heartRateController, 'symptom_checker_v2.heart_rate'.tr()),
        const SizedBox(height: 24),
        WizardBottomActions(
          onBack: widget.onBack,
          onNext: () {
            ref.read(assessmentFlowProvider.notifier).setFollowUp(
                  durationDays: int.tryParse(_durationController.text),
                  ageGroup: _ageGroup,
                  knownConditions: _knownConditions.toList(),
                  vitals: AssessmentVitalsEntity(
                    systolic: int.tryParse(_systolicController.text),
                    diastolic: int.tryParse(_diastolicController.text),
                    heartRate: int.tryParse(_heartRateController.text),
                  ),
                );
            widget.onSubmit();
          },
          nextIcon: Icons.analytics_rounded,
          nextLabel: 'symptom_checker_v2.run_assessment'.tr(),
        ),
      ],
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
