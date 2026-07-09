import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../ai/presentation/pages/ai_symptom_chat_page.dart';
import '../../domain/entities/assessment_entities.dart';
import '../providers/assessment_flow_provider.dart';
import '../providers/assessment_result_provider.dart';
import '../widgets/red_flag_banner.dart';
import '../widgets/urgency_badge.dart';

class AssessmentResultPage extends ConsumerWidget {
  final String lang;
  final VoidCallback onRestart;

  const AssessmentResultPage({
    super.key,
    required this.lang,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resultState = ref.watch(assessmentResultProvider);
    final result = resultState.result;

    if (resultState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (resultState.error != null) {
      return Center(
          child: Text(resultState.error!, textAlign: TextAlign.center));
    }
    if (result == null) {
      return Center(child: Text('symptom_checker_v2.no_result'.tr()));
    }

    return ListView(
      padding: EdgeInsets.all(context.w(5)),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'symptom_checker_v2.result_title'.tr(),
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            UrgencyBadge(urgency: result.urgency, label: result.urgencyLabel),
          ],
        ),
        const SizedBox(height: 14),
        RedFlagBanner(redFlags: result.redFlags),
        const SizedBox(height: 14),
        _Panel(
          child:
              Text(result.patientMessage, style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'symptom_checker_v2.top_conditions'.tr(),
          child: Column(
            children: result.topPredictions.map((prediction) {
              return ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(prediction.name,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  prediction.whyNames.isEmpty
                      ? 'symptom_checker_v2.no_why'.tr()
                      : prediction.whyNames.join(', '),
                ),
                trailing: Text(
                    '${(prediction.confidence * 100).toStringAsFixed(0)}%'),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        _Panel(
          title: 'symptom_checker_v2.recommended_action'.tr(),
          child: Text(result.recommendedActionText,
              style: const TextStyle(height: 1.5)),
        ),
        const SizedBox(height: 12),
        _Panel(
          child: Text(
            result.disclaimer,
            style: const TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ),
        const SizedBox(height: 18),
        if (result.shouldNotifyCaregiver) ...[
          // The backend already auto-notified caregivers for high/critical
          // urgency results (see `_should_notify_from_result` server-side).
          // Showing the manual button below too would send a second,
          // duplicate notification for the same assessment -- this banner
          // replaces it. A full-width banner (not a Chip) so the sentence
          // can wrap instead of getting clipped.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle, color: AppColors.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'symptom_checker_v2.caregiver_already_notified'.tr(),
                    style: const TextStyle(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ElevatedButton.icon(
              onPressed: () => _openChat(context, ref),
              icon: const Icon(Icons.forum_rounded),
              label: Text('symptom_checker_v2.open_ai_chat'.tr()),
            ),
            if (!result.shouldNotifyCaregiver)
              OutlinedButton.icon(
                onPressed: resultState.isNotifyingCaregiver
                    ? null
                    : () => _notifyCaregiver(context, ref),
                icon: const Icon(Icons.notifications_active_rounded),
                label: Text(resultState.isNotifyingCaregiver
                    ? 'common.loading'.tr()
                    : 'symptom_checker_v2.notify_caregiver'.tr()),
              ),
            TextButton.icon(
              onPressed: onRestart,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('symptom_checker_v2.new_assessment'.tr()),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openChat(BuildContext context, WidgetRef ref) async {
    final input = ref.read(assessmentFlowProvider).toInput();
    final result = ref.read(assessmentResultProvider).result;
    final sessionId = await ref
        .read(assessmentResultProvider.notifier)
        .startChat(input, lang);
    if (sessionId == null || !context.mounted || result == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AiSymptomChatPage(
          initialSessionId: sessionId,
          initialContextMessage: _chatSeedMessage(input, result),
          onBackToStart: onRestart,
        ),
      ),
    );
  }

  Future<void> _notifyCaregiver(BuildContext context, WidgetRef ref) async {
    final input = ref.read(assessmentFlowProvider).toInput();
    final count = await ref
        .read(assessmentResultProvider.notifier)
        .notifyCaregiver(input, lang);
    if (!context.mounted || count == null) return;
    final message = count > 0
        ? 'symptom_checker_v2.caregiver_notified'.tr(args: ['$count'])
        : 'symptom_checker_v2.no_linked_caregiver'.tr();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: count > 0 ? AppColors.success : AppColors.warning,
      ),
    );
  }

  String _chatSeedMessage(
    AssessmentInputEntity input,
    AssessmentResultEntity result,
  ) {
    final symptoms = input.symptoms
        .map((symptom) => '${symptom.name} (${symptom.severity}/4)')
        .join(', ');
    final redFlags = result.redFlags.isEmpty
        ? 'symptom_checker_v2.none'.tr()
        : result.redFlags.map((flag) => flag.name).join(', ');

    return [
      'symptom_checker_v2.chat_seed_intro'.tr(),
      '',
      result.patientMessage,
      '',
      '${'symptom_checker_v2.selected_symptoms'.tr()}: $symptoms',
      '${'symptom_checker_v2.urgency'.tr()}: ${result.urgencyLabel}',
      '${'symptom_checker_v2.red_flags'.tr()}: $redFlags',
      '${'symptom_checker_v2.recommended_action'.tr()}: ${result.recommendedActionText}',
    ].join('\n');
  }
}

class _Panel extends StatelessWidget {
  final String? title;
  final Widget child;

  const _Panel({this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}
