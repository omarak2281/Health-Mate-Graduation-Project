import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/vital_sign.dart';
import '../../../../core/widgets/expert_app_bar.dart';
import '../../domain/entities/assessment_entities.dart';
import '../providers/assessment_flow_provider.dart';
import '../providers/assessment_result_provider.dart';
import 'assessment_result_page.dart';
import 'category_selection_page.dart';
import 'followup_questions_page.dart';
import 'symptom_selection_page.dart';
import 'symptom_severity_page.dart';

class SymptomCheckerWizardPage extends ConsumerStatefulWidget {
  final VitalSign? initialBpReading;

  const SymptomCheckerWizardPage({super.key, this.initialBpReading});

  @override
  ConsumerState<SymptomCheckerWizardPage> createState() =>
      _SymptomCheckerWizardPageState();
}

class _SymptomCheckerWizardPageState
    extends ConsumerState<SymptomCheckerWizardPage> {
  final _controller = PageController();
  int _step = 0;
  bool _startedBpFlow = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_startedBpFlow || widget.initialBpReading == null) return;
    _startedBpFlow = true;
    WidgetsBinding.instance.addPostFrameCallback((_) => _startBpFlow());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.locale.languageCode == 'ar' ? 'ar' : 'en';
    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF0a0e14)
          : const Color(0xFFF8FBFC),
      appBar: ExpertAppBar(
        title: 'symptom_checker_v2.title'.tr(),
      ),
      body: Column(
        children: [
          _Progress(step: _step),
          Expanded(
            child: PageView(
              controller: _controller,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                CategorySelectionPage(lang: lang, onNext: _next),
                SymptomSelectionPage(onNext: _next, onBack: _back),
                SymptomSeverityPage(onNext: _next, onBack: _back),
                FollowupQuestionsPage(
                  onBack: _back,
                  onSubmit: () async {
                    final input = ref.read(assessmentFlowProvider).toInput();
                    final ok = await ref
                        .read(assessmentResultProvider.notifier)
                        .submit(input, lang);
                    if (ok) _next();
                  },
                ),
                AssessmentResultPage(
                  lang: lang,
                  onRestart: () {
                    ref.read(assessmentFlowProvider.notifier).reset();
                    ref.read(assessmentResultProvider.notifier).reset();
                    _goTo(0);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _next() => _goTo((_step + 1).clamp(0, 4));
  void _back() => _goTo((_step - 1).clamp(0, 4));

  void _goTo(int page) {
    setState(() => _step = page);
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _startBpFlow() async {
    final bp = widget.initialBpReading;
    if (bp == null || !mounted) return;
    final lang = context.locale.languageCode == 'ar' ? 'ar' : 'en';
    final ok = await ref.read(assessmentFlowProvider.notifier).startBpTriage(
          lang: lang,
          sourceVitalId: bp.id,
          vitals: AssessmentVitalsEntity(
            systolic: bp.systolic,
            diastolic: bp.diastolic,
            heartRate: bp.heartRate,
          ),
        );
    if (ok && mounted) {
      _goTo(1);
    }
  }
}

class _Progress extends StatelessWidget {
  final int step;

  const _Progress({required this.step});

  @override
  Widget build(BuildContext context) {
    final labels = [
      'symptom_checker_v2.step_category'.tr(),
      'symptom_checker_v2.step_symptoms'.tr(),
      'symptom_checker_v2.step_severity'.tr(),
      'symptom_checker_v2.step_followup'.tr(),
      'symptom_checker_v2.step_result'.tr(),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
      child: Row(
        children: labels.asMap().entries.map((entry) {
          final active = entry.key <= step;
          return Expanded(
            child: Container(
              height: 34,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.border.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Center(
                child: Text(
                  entry.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
