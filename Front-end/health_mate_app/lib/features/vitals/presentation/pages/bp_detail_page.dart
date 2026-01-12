import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/vital_sign.dart';

class BPDetailPage extends StatelessWidget {
  final VitalSign bp;

  const BPDetailPage({super.key, required this.bp});

  @override
  Widget build(BuildContext context) {
    final bool isHigh = bp.systolic >= 140 || bp.diastolic >= 90;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.vitalsBloodPressure.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Status Card
            Card(
              color: isHigh
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      isHigh
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: 64,
                      color: isHigh ? AppColors.error : AppColors.success,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${bp.systolic}/${bp.diastolic} mmHg',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isHigh ? AppColors.error : AppColors.success,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHigh
                          ? LocaleKeys.vitalsHighBpStatus.tr()
                          : LocaleKeys.vitalsNormalBpStatus.tr(),
                      style: TextStyle(
                        fontSize: 18,
                        color: isHigh ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Details
            _detailTile(
              context,
              Icons.calendar_today,
              LocaleKeys.vitalsDate.tr(),
              DateFormat('yyyy-MM-dd').format(bp.measuredAt),
            ),
            _detailTile(
              context,
              Icons.access_time,
              LocaleKeys.vitalsReadingTime.tr(),
              DateFormat('HH:mm').format(bp.measuredAt),
            ),
            _detailTile(
              context,
              Icons.favorite,
              LocaleKeys.vitalsHeartRate.tr(),
              bp.heartRate != null ? '${bp.heartRate} bpm' : 'N/A',
            ),
            const SizedBox(height: 24),

            // Recommendation Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.vitalsHealthTip.tr(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isHigh
                          ? LocaleKeys.vitalsHighBpRec.tr()
                          : LocaleKeys.vitalsNormalBpRec.tr(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailTile(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: AppColors.primary),
          title: Text(label),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
