import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';
import '../pages/bp_history_page.dart';

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
              Icon(
                Icons.favorite_border,
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
                    _showAddReadingDialog(context, ref);
                  },
                  icon: const Icon(Icons.add),
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
                  if (bp.heartRate != null)
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
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

  void _showAddReadingDialog(BuildContext context, WidgetRef ref) {
    final systolicController = TextEditingController();
    final diastolicController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              final systolic = int.tryParse(systolicController.text);
              final diastolic = int.tryParse(diastolicController.text);

              if (systolic != null && diastolic != null) {
                await ref
                    .read(vitalsNotifierProvider.notifier)
                    .createBPReading(systolic: systolic, diastolic: diastolic);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(LocaleKeys.save.tr()),
          ),
        ],
      ),
    );
  }
}
