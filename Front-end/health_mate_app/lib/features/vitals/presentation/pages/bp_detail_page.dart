import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/vital_sign.dart';

class BPDetailPage extends StatelessWidget {
  final VitalSign bp;

  const BPDetailPage({super.key, required this.bp});

  @override
  Widget build(BuildContext context) {
    final bool isHigh = bp.systolic >= 140 || bp.diastolic >= 90;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.vitalsBloodPressure.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(context.w(6)),
        child: Column(
          children: [
            // Status Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: isHigh
                  ? AppColors.error.withValues(alpha: 0.1)
                  : AppColors.success.withValues(alpha: 0.1),
              child: Padding(
                padding: EdgeInsets.all(context.w(8)),
                child: Column(
                  children: [
                    Icon(
                      isHigh
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      size: context.sp(64),
                      color: isHigh ? AppColors.error : AppColors.success,
                    ),
                    SizedBox(height: context.h(2)),
                    Text(
                      '${bp.systolic}/${bp.diastolic} mmHg',
                      style: TextStyle(
                        fontSize: context.sp(28),
                        fontWeight: FontWeight.bold,
                        color: isHigh ? AppColors.error : AppColors.success,
                      ),
                    ),
                    SizedBox(height: context.h(1)),
                    Text(
                      isHigh
                          ? LocaleKeys.vitalsHighBpStatus.tr()
                          : LocaleKeys.vitalsNormalBpStatus.tr(),
                      style: TextStyle(
                        fontSize: context.sp(18),
                        color: isHigh ? AppColors.error : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: context.h(4)),

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
            SizedBox(height: context.h(3)),

            // Recommendation Card
            Card(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(context.w(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.vitalsHealthTip.tr(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: context.sp(18),
                      ),
                    ),
                    SizedBox(height: context.h(1)),
                    Text(
                      isHigh
                          ? LocaleKeys.vitalsHighBpRec.tr()
                          : LocaleKeys.vitalsNormalBpRec.tr(),
                      style: TextStyle(
                          fontSize: context.sp(14),
                          color: AppColors.textSecondary),
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
          contentPadding: EdgeInsets.symmetric(horizontal: context.w(2)),
          leading: Icon(icon, color: AppColors.primary, size: context.sp(24)),
          title: Text(label, style: TextStyle(fontSize: context.sp(16))),
          trailing: Text(
            value,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: context.sp(16)),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
