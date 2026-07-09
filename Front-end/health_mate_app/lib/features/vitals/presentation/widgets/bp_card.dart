import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';
import '../../../ai/presentation/pages/symptom_checker_page.dart';
import '../../../symptom_checker/presentation/pages/symptom_checker_wizard_page.dart';
import '../pages/bp_history_page.dart';
import '../pages/bp_measurement_guide_page.dart';

/// BP Card Widget
/// Shows latest blood pressure reading with risk indicator

class BPCard extends ConsumerWidget {
  final String? patientId;
  const BPCard({super.key, this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vitalsState = patientId != null
        ? ref.watch(patientVitalsNotifierProvider(patientId!))
        : ref.watch(vitalsNotifierProvider);

    if (vitalsState.isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (vitalsState.currentBP == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              AppIcons.bloodPressure(
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                LocaleKeys.vitalsNoReadings.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (patientId == null)
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddReadingOptions(context, ref);
                  },
                  icon: Icon(AppIcons.add),
                  label: Text(LocaleKeys.vitalsAddReading.tr()),
                ),
            ],
          ),
        ),
      );
    }

    final bp = vitalsState.currentBP!;
    final riskColor = _getRiskColor(bp.riskLevel);
    final riskText = _getRiskText(bp.riskLevel);

    return Card(
      child: InkWell(
        onTap: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const BPHistoryPage()));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocaleKeys.vitalsLastReading.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (patientId == null) ...[
                    IconButton(
                      icon: const Icon(Icons.add, color: AppColors.primary),
                      onPressed: () {
                        _showAddReadingOptions(context, ref);
                      },
                    ),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: riskColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: riskColor),
                      ),
                      child: Text(
                        riskText,
                        style: TextStyle(
                          color: riskColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          bp.systolic.toString(),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        Text(LocaleKeys.vitalsSystolic.tr()),
                      ],
                    ),
                  ),
                  Text(
                    '/',
                    style: TextStyle(
                      fontSize: 36,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          bp.diastolic.toString(),
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: riskColor,
                          ),
                        ),
                        Text(LocaleKeys.vitalsDiastolic.tr()),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    DateFormat.yMMMd().add_jm().format(bp.measuredAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  Row(
                    children: [
                      if (bp.heartRate != null) ...[
                        AppIcons.heartRate(
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          LocaleKeys.vitalsHeartRateValue.tr(
                            args: [bp.heartRate.toString()],
                          ),
                        ),
                      ],
                      if (bp.spo2 != null) ...[
                        if (bp.heartRate != null) const SizedBox(width: 12),
                        Icon(
                          Icons.water_drop,
                          size: 16,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'vitals.spo2_value'.tr(
                            args: [bp.spo2.toString()],
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
        return AppColors.riskNormal;
      case 'low':
        return AppColors.riskLow;
      case 'moderate':
        return AppColors.riskModerate;
      case 'high':
        return AppColors.riskHigh;
      case 'critical':
        return AppColors.riskCritical;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getRiskText(String riskLevel) {
    switch (riskLevel.toLowerCase()) {
      case 'normal':
        return LocaleKeys.vitalsRiskNormal.tr();
      case 'low':
        return LocaleKeys.vitalsRiskLow.tr();
      case 'moderate':
        return LocaleKeys.vitalsRiskModerate.tr();
      case 'high':
        return LocaleKeys.vitalsRiskHigh.tr();
      case 'critical':
        return LocaleKeys.vitalsRiskCritical.tr();
      default:
        return riskLevel;
    }
  }

  void _showAddReadingDialog(BuildContext pageContext, WidgetRef ref) {
    final systolicController = TextEditingController();
    final diastolicController = TextEditingController();

    showDialog(
      context: pageContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(LocaleKeys.vitalsAddReading.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: systolicController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: LocaleKeys.vitalsSystolic.tr(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: diastolicController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: LocaleKeys.vitalsDiastolic.tr(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final systolic = int.tryParse(systolicController.text.trim());
              final diastolic = int.tryParse(diastolicController.text.trim());

              if (systolic == null ||
                  diastolic == null ||
                  systolic <= 0 ||
                  diastolic <= 0) {
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(LocaleKeys.errorsRequiredField.tr()),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              if (systolic <= diastolic) {
                ScaffoldMessenger.of(pageContext).showSnackBar(
                  SnackBar(
                    content: Text(LocaleKeys.errorsPasswordsDontMatch.tr()),
                    backgroundColor: AppColors.error,
                  ),
                );
                return;
              }

              final reading = await ref
                  .read(vitalsNotifierProvider.notifier)
                  .createBPReading(systolic: systolic, diastolic: diastolic);
              if (!dialogContext.mounted) return;
              // Close the dialog first, using ITS OWN context. Navigating afterwards must
              // use pageContext (the card's context), not dialogContext — dialogContext
              // belongs to the route we just popped, so pushing a new page on it is relying
              // on undefined timing (it happens to still be attached during the pop
              // animation today, but is not a safe navigation target).
              Navigator.pop(dialogContext);
              if (reading != null &&
                  reading.isEmergency &&
                  pageContext.mounted) {
                Navigator.of(pageContext).push(
                  MaterialPageRoute(
                    builder: (_) => ApiConstants.symptomCheckerV2Enabled
                        ? SymptomCheckerWizardPage(initialBpReading: reading)
                        : const SymptomCheckerPage(),
                  ),
                );
              }
            },
            child: Text(LocaleKeys.save.tr()),
          ),
        ],
      ),
    );
  }

  void _showAddReadingOptions(BuildContext pageContext, WidgetRef ref) {
    showModalBottomSheet(
      context: pageContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading:
                  const Icon(Icons.wifi_tethering, color: AppColors.primary),
              title: Text(LocaleKeys.vitalsBpGuideTitle.tr()),
              subtitle: Text(LocaleKeys.vitalsBpGuideSubtitle.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.of(pageContext).push(
                  MaterialPageRoute(
                    builder: (_) => const BPMeasurementGuidePage(),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.primary),
              title: Text(LocaleKeys.vitalsAddReading.tr()),
              subtitle: Text(LocaleKeys.vitalsManual.tr()),
              onTap: () {
                Navigator.pop(sheetContext);
                _showAddReadingDialog(pageContext, ref);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
