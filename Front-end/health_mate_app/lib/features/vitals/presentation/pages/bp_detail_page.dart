import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/vital_sign.dart';

class BPDetailPage extends StatelessWidget {
  final VitalSign bp;

  const BPDetailPage({super.key, required this.bp});

  @override
  Widget build(BuildContext context) {
    final systolic = bp.displaySystolic;
    final diastolic = bp.displayDiastolic;
    final hasBp = systolic != null && diastolic != null;
    final bool isHigh = (systolic ?? 0) >= 140 || (diastolic ?? 0) >= 90;
    final statusColor = bp.isPending
        ? AppColors.primary
        : (isHigh ? AppColors.error : AppColors.success);

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
              color: bp.isPending
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : (isHigh
                      ? AppColors.error.withValues(alpha: 0.1)
                      : AppColors.success.withValues(alpha: 0.1)),
              child: Padding(
                padding: EdgeInsets.all(context.w(8)),
                child: Column(
                  children: [
                    Icon(
                      bp.isPending
                          ? Icons.hourglass_empty_rounded
                          : (isHigh
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline),
                      size: context.sp(64),
                      color: bp.isPending
                          ? AppColors.primary
                          : (isHigh ? AppColors.error : AppColors.success),
                    ),
                    SizedBox(height: context.h(2)),
                    Directionality(
                      textDirection: ui.TextDirection.ltr,
                      child: Text(
                        hasBp
                            ? LocaleKeys.vitalsBpReadingWithUnit.tr(
                                namedArgs: {
                                  'systolic': systolic.toString(),
                                  'diastolic': diastolic.toString(),
                                  'unit': LocaleKeys.homeMmHg.tr(),
                                },
                              )
                            : '-- / -- ${LocaleKeys.homeMmHg.tr()}',
                        style: TextStyle(
                          fontSize: context.sp(28),
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(1)),
                    Text(
                      bp.isPending
                          ? LocaleKeys.pending.tr()
                          : (isHigh
                              ? LocaleKeys.vitalsHighBpStatus.tr()
                              : LocaleKeys.vitalsNormalBpStatus.tr()),
                      style: TextStyle(
                        fontSize: context.sp(18),
                        color: statusColor,
                      ),
                    ),
                    if (bp.isEstimatedBP) ...[
                      SizedBox(height: context.h(0.8)),
                      Text(
                        'vitals.bp_guide_estimated_note'.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: context.sp(12),
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
              bp.heartRate != null
                  ? LocaleKeys.vitalsHeartRateValue
                      .tr(args: [bp.heartRate.toString()])
                  : LocaleKeys.commonNotAvailable.tr(),
              forceLtrValue: bp.heartRate != null,
            ),
            _detailTile(
              context,
              Icons.water_drop,
              'vitals.spo2'.tr(),
              bp.spo2 != null
                  ? 'vitals.spo2_value'.tr(args: [bp.spo2.toString()])
                  : LocaleKeys.commonNotAvailable.tr(),
              forceLtrValue: bp.spo2 != null,
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
    String value, {
    bool forceLtrValue = false,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: context.w(2)),
          leading: Icon(icon, color: AppColors.primary, size: context.sp(24)),
          title: Text(label, style: TextStyle(fontSize: context.sp(16))),
          trailing: Directionality(
            textDirection: forceLtrValue
                ? ui.TextDirection.ltr
                : Directionality.of(context),
            child: Text(
              value,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: context.sp(16)),
            ),
          ),
        ),
        const Divider(),
      ],
    );
  }
}
