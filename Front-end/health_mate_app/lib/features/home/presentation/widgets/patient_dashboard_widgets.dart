import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

/// Prominent quick-action card for the patient home page (e.g. "Check Now"),
/// matching the visual style of CaregiverQuickActionCard for consistency.
class PatientQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const PatientQuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.25 : 0.12),
              color.withValues(alpha: isDark ? 0.15 : 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(3)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: context.sp(22)),
            ),
            SizedBox(width: context.w(3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: context.h(0.3)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.sp(11),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              color: color.withValues(alpha: 0.7),
              size: context.sp(18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Heart Rate Card Widget
/// Displays current heart rate with circular progress indicator
/// Shows average and max values for today
class HeartRateCard extends StatelessWidget {
  final int? heartRate;
  final int? avgToday;
  final int? maxToday;
  final String? riskLevel;
  final bool compact;

  const HeartRateCard({
    super.key,
    this.heartRate,
    this.avgToday,
    this.maxToday,
    this.riskLevel,
    this.compact = false,
  });

  Color get _ringColor {
    switch (riskLevel) {
      case 'low':
        return Colors.blue[400]!;
      case 'moderate':
        return AppColors.warning;
      case 'high':
        return Colors.deepOrange[400]!;
      case 'critical':
        return AppColors.error;
      default:
        return Colors.lightGreenAccent[400]!;
    }
  }

  String? _riskLabel(BuildContext context) {
    switch (riskLevel) {
      case 'low':
        return LocaleKeys.vitalsRiskLow.tr();
      case 'moderate':
        return LocaleKeys.vitalsRiskModerate.tr();
      case 'high':
        return LocaleKeys.vitalsRiskHigh.tr();
      case 'critical':
        return LocaleKeys.vitalsRiskCritical.tr();
      case 'normal':
        return LocaleKeys.vitalsRiskNormal.tr();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = heartRate != null ? _riskLabel(context) : null;

    if (compact) {
      return CompactVitalGaugeCard(
        icon: AppIcons.heartRate(
          size: context.sp(18),
          color: isDark ? Colors.white : Theme.of(context).primaryColor,
        ),
        iconBgColor: isDark
            ? AppColors.primary.withValues(alpha: 0.2)
            : Theme.of(context).primaryColor.withValues(alpha: 0.1),
        title: LocaleKeys.vitalsHeartRate.tr(),
        valueText: heartRate?.toString() ?? '--',
        unitText: LocaleKeys.homeBpm.tr(),
        ringValue: heartRate != null
            ? (heartRate! / 200).clamp(0.0, 1.0)
            : null,
        ringColor: _ringColor,
        badgeText: label,
        avgLabel: LocaleKeys.homeAvgToday.tr(),
        avgValue: avgToday?.toString() ?? '--',
        maxLabel: LocaleKeys.homeMax.tr().toUpperCase(),
        maxValue: maxToday?.toString() ?? '--',
      );
    }

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2.5)),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: AppIcons.heartRate(
                  size: context.sp(22),
                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: context.w(3)),
              Expanded(
                child: Text(
                  LocaleKeys.vitalsHeartRate.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : null,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(3)),

          // Content
          Row(
            children: [
              // Circular Progress
              Expanded(
                flex: 5,
                child: Center(
                  child: SizedBox(
                    width: context.sp(130),
                    height: context.sp(130),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Background Circle
                        SizedBox(
                          width: context.sp(130),
                          height: context.sp(130),
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: context.w(3),
                            color: AppColors.border,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        // Progress Circle
                        if (heartRate != null)
                          SizedBox(
                            width: context.sp(130),
                            height: context.sp(130),
                            child: CircularProgressIndicator(
                              value: (heartRate! / 200).clamp(0.0, 1.0),
                              strokeWidth: context.w(3),
                              color: _ringColor,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        // Center Text
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              heartRate?.toString() ?? '--',
                              style: TextStyle(
                                fontSize: context.sp(32),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.color,
                              ),
                            ),
                            Text(
                              LocaleKeys.homeBpm.tr(),
                              style: TextStyle(
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            if (label != null) ...[
                              SizedBox(height: context.h(0.6)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.w(2.2),
                                  vertical: context.h(0.25),
                                ),
                                decoration: BoxDecoration(
                                  color: _ringColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: context.sp(10.5),
                                    fontWeight: FontWeight.w700,
                                    color: _ringColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(2)),

              // Stats
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(
                      context,
                      LocaleKeys.homeAvgToday.tr(),
                      avgToday != null
                          ? '$avgToday ${LocaleKeys.homeBpm.tr()}'
                          : '--',
                    ),
                    SizedBox(height: context.h(2.5)),
                    _buildStatItem(
                      context,
                      LocaleKeys.homeMax.tr().toUpperCase(),
                      maxToday != null
                          ? '$maxToday ${LocaleKeys.homeBpm.tr()}'
                          : '--',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(13),
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.h(0.5)),
        Text(
          value,
          style: TextStyle(
            fontSize: context.sp(17),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

/// Blood Pressure Card Widget
/// Displays current BP reading with semi-circular gauge
/// Shows risk level indicators and "Check Now" button
class BloodPressureCardExpert extends StatelessWidget {
  final String? systolic;
  final String? diastolic;
  final String? time;
  final double? signalQuality;
  final String? calibrationStatus;
  final VoidCallback onCheckNow;

  const BloodPressureCardExpert({
    super.key,
    this.systolic,
    this.diastolic,
    this.time,
    this.signalQuality,
    this.calibrationStatus,
    required this.onCheckNow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Determine risk level based on BP values
    String riskLevel = _determineRiskLevel();
    final riskColor = _getRiskColor(riskLevel);

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(context.w(2.5)),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primary.withValues(alpha: 0.2)
                          : Theme.of(context)
                              .primaryColor
                              .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcons.bloodPressure(
                      size: context.sp(22),
                      color: isDark
                          ? Colors.white
                          : Theme.of(context).primaryColor,
                    ),
                  ),
                  SizedBox(width: context.w(3)),
                  Text(
                    LocaleKeys.vitalsBloodPressure.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                  ),
                ],
              ),
              if (time != null)
                Text(
                  time!,
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    fontSize: context.sp(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          SizedBox(height: context.h(3)),

          // Gauge and Reading
          Center(
            child: Column(
              children: [
                // Semi-circular Gauge
                SizedBox(
                  width: context.w(58),
                  height: context.h(14),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(
                      begin: 0,
                      end: _calculateGaugePercentage(),
                    ),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CustomPaint(
                        painter: SemiCircleGaugePainter(
                          percentage: value,
                          markerColor: riskColor,
                          isDark: isDark,
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.h(1)),

                // BP Reading
                Directionality(
                  textDirection: ui.TextDirection.ltr,
                  child: Text(
                    systolic != null && diastolic != null
                        ? '$systolic / $diastolic'
                        : '-- / --',
                    style: TextStyle(
                      fontSize: context.sp(28),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.displayMedium?.color,
                    ),
                  ),
                ),
                Text(
                  LocaleKeys.homeMmHg.tr(),
                  style: TextStyle(
                    fontSize: context.sp(14),
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (signalQuality != null || calibrationStatus != null) ...[
                  SizedBox(height: context.h(1)),
                  VitalTrustBadge(
                    signalQuality: signalQuality,
                    calibrationStatus: calibrationStatus,
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: context.h(3)),

          _buildRiskScale(context, riskLevel),
          SizedBox(height: context.h(2)),

          // Check Now Button
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: onCheckNow,
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(4),
                  vertical: context.h(1),
                ),
              ),
              child: Text(
                LocaleKeys.homeCheckNow.tr(),
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: context.sp(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _determineRiskLevel() {
    if (systolic == null || diastolic == null) return 'normal';

    final sys = int.tryParse(systolic!) ?? 120;
    final dia = int.tryParse(diastolic!) ?? 80;

    if (sys < 90 || dia < 60) return 'low';
    if (sys >= 180 || dia >= 120) return 'critical';
    if (sys >= 140 || dia >= 90) return 'high';
    if (sys >= 120 || dia >= 80) return 'moderate';
    return 'normal';
  }

  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Colors.blue[400]!;
      case 'moderate':
        return AppColors.warning;
      case 'high':
        return Colors.deepOrange[400]!;
      case 'critical':
        return AppColors.error;
      default:
        return Colors.lightGreenAccent[400]!;
    }
  }

  double _calculateGaugePercentage() {
    if (systolic == null) return 0.5;

    final sys = int.tryParse(systolic!) ?? 120;
    // Normalize systolic (70-190 range) to 0-1.
    return ((sys - 70) / 120).clamp(0.0, 1.0);
  }

  Widget _buildRiskScale(BuildContext context, String riskLevel) {
    final items = [
      (LocaleKeys.vitalsRiskLow.tr(), 'low', Colors.blue[400]!),
      (
        LocaleKeys.vitalsRiskNormal.tr(),
        'normal',
        Colors.lightGreenAccent[400]!
      ),
      (LocaleKeys.vitalsRiskModerate.tr(), 'moderate', AppColors.warning),
      (LocaleKeys.vitalsRiskHigh.tr(), 'high', Colors.deepOrange[400]!),
    ];

    return Row(
      children: items.map((item) {
        final isSelected = riskLevel == item.$2 ||
            (riskLevel == 'critical' && item.$2 == 'high');
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(0.6)),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 260),
                  height: isSelected ? context.h(1.1) : context.h(0.65),
                  decoration: BoxDecoration(
                    color: isSelected ? item.$3 : AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: item.$3.withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                ),
                SizedBox(height: context.h(0.8)),
                Text(
                  item.$1,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.sp(10.5),
                    color: isSelected
                        ? item.$3
                        : Theme.of(context).textTheme.bodySmall?.color,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Semi-Circle Gauge Painter
/// Custom painter for blood pressure gauge visualization.
class SemiCircleGaugePainter extends CustomPainter {
  final double percentage;
  final Color markerColor;
  final bool isDark;

  SemiCircleGaugePainter({
    required this.percentage,
    required this.markerColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    const totalSweep = math.pi;
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    final muted = isDark
        ? Colors.white.withValues(alpha: 0.14)
        : Colors.black.withValues(alpha: 0.08);
    canvas.drawArc(rect, math.pi, totalSweep, false, basePaint..color = muted);

    final t = percentage.clamp(0.0, 1.0);
    canvas.drawArc(
      rect,
      math.pi,
      totalSweep * t,
      false,
      basePaint..color = markerColor,
    );

    final angle = math.pi + (totalSweep * t);
    final center = rect.center;
    final marker = Offset(
      center.dx + (rect.width / 2) * math.cos(angle),
      center.dy + (rect.height / 2) * math.sin(angle),
    );

    canvas.drawCircle(
      marker,
      10,
      Paint()
        ..color = markerColor.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(marker, 6.5, Paint()..color = markerColor);
    canvas.drawCircle(
      marker,
      3,
      Paint()..color = isDark ? AppColors.surfaceDark : Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant SemiCircleGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.markerColor != markerColor ||
        oldDelegate.isDark != isDark;
  }
}

/// Compact half-width gauge card shared by [HeartRateCard] and [SpO2Card]
/// when placed side by side (`compact: true`). The full-width layout puts
/// the ring next to an Avg/Max side column, which has no room in half the
/// screen -- this instead stacks a smaller ring above two Avg/Max stats
/// placed in a row underneath, so both cards fit one row without crowding.
class CompactVitalGaugeCard extends StatelessWidget {
  final Widget icon;
  final Color iconBgColor;
  final String title;
  final String valueText;
  final String unitText;
  final double? ringValue;
  final Color ringColor;
  final String? badgeText;
  final String avgLabel;
  final String avgValue;
  final String maxLabel;
  final String maxValue;

  const CompactVitalGaugeCard({
    super.key,
    required this.icon,
    required this.iconBgColor,
    required this.title,
    required this.valueText,
    required this.unitText,
    required this.ringValue,
    required this.ringColor,
    this.badgeText,
    required this.avgLabel,
    required this.avgValue,
    required this.maxLabel,
    required this.maxValue,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ringSize = context.sp(100);

    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2)),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: icon,
              ),
              SizedBox(width: context.w(2)),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(2)),

          // Ring
          Center(
            child: SizedBox(
              width: ringSize,
              height: ringSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: ringSize,
                    height: ringSize,
                    child: CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: context.w(2.5),
                      color: AppColors.border,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                  if (ringValue != null)
                    SizedBox(
                      width: ringSize,
                      height: ringSize,
                      child: CircularProgressIndicator(
                        value: ringValue,
                        strokeWidth: context.w(2.5),
                        color: ringColor,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        valueText,
                        style: TextStyle(
                          fontSize: context.sp(22),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.displayLarge?.color,
                        ),
                      ),
                      Text(
                        unitText,
                        style: TextStyle(
                          fontSize: context.sp(11),
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (badgeText != null) ...[
            SizedBox(height: context.h(1)),
            Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(2),
                  vertical: context.h(0.2),
                ),
                decoration: BoxDecoration(
                  color: ringColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText!,
                  style: TextStyle(
                    fontSize: context.sp(9.5),
                    fontWeight: FontWeight.w700,
                    color: ringColor,
                  ),
                ),
              ),
            ),
          ],
          SizedBox(height: context.h(1.5)),

          // Avg / Max row
          Row(
            children: [
              Expanded(child: _compactStat(context, avgLabel, avgValue)),
              Container(
                width: 1,
                height: context.h(3.2),
                color: (isDark ? AppColors.white12 : AppColors.border),
              ),
              Expanded(child: _compactStat(context, maxLabel, maxValue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _compactStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: context.sp(10.5),
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.h(0.3)),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: context.sp(13.5),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

/// SpO2 (Blood Oxygen) Card Widget
/// Matches the HeartRateCard visual pattern exactly: icon header, 130px
/// circular indicator with the value centered, plus an Avg Today / Max
/// Today stats column so the card doesn't leave the row half-empty like the
/// old bare 110px centered ring. Shows '--' when no reading is available yet.
class SpO2Card extends StatelessWidget {
  final int? spo2;
  final int? avgToday;
  final int? maxToday;
  final String? riskLevel;
  final bool compact;

  const SpO2Card({
    super.key,
    this.spo2,
    this.avgToday,
    this.maxToday,
    this.riskLevel,
    this.compact = false,
  });

  /// Mirrors HeartRateCard's _ringColor: normal is the only "safe" tier for
  /// SpO2, so only 'moderate' (mild desaturation) and 'critical' (severe)
  /// are meaningful here.
  Color get _ringColor {
    switch (riskLevel) {
      case 'moderate':
        return AppColors.warning;
      case 'critical':
        return AppColors.error;
      default:
        return AppColors.info;
    }
  }

  String? _riskLabel(BuildContext context) {
    switch (riskLevel) {
      case 'moderate':
        return LocaleKeys.vitalsRiskModerate.tr();
      case 'critical':
        return LocaleKeys.vitalsRiskCritical.tr();
      case 'normal':
        return LocaleKeys.vitalsRiskNormal.tr();
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final label = spo2 != null ? _riskLabel(context) : null;

    if (compact) {
      return CompactVitalGaugeCard(
        icon: Icon(
          Icons.water_drop,
          size: context.sp(18),
          color: isDark ? Colors.white : AppColors.info,
        ),
        iconBgColor: isDark
            ? AppColors.info.withValues(alpha: 0.2)
            : AppColors.info.withValues(alpha: 0.1),
        title: 'vitals.spo2'.tr(),
        valueText: spo2?.toString() ?? '--',
        unitText: '%',
        ringValue: spo2 != null ? (spo2! / 100).clamp(0.0, 1.0) : null,
        ringColor: _ringColor,
        badgeText: label,
        avgLabel: LocaleKeys.homeAvgToday.tr(),
        avgValue: avgToday != null ? '$avgToday%' : '--',
        maxLabel: LocaleKeys.homeMax.tr().toUpperCase(),
        maxValue: maxToday != null ? '$maxToday%' : '--',
      );
    }

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2.5)),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.info.withValues(alpha: 0.2)
                      : AppColors.info.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.water_drop,
                  size: context.sp(22),
                  color: isDark ? Colors.white : AppColors.info,
                ),
              ),
              SizedBox(width: context.w(3)),
              Expanded(
                child: Text(
                  'vitals.spo2'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : null,
                      ),
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(3)),

          // Content
          Row(
            children: [
              // Circular Progress
              Expanded(
                flex: 5,
                child: Center(
                  child: SizedBox(
                    width: context.sp(130),
                    height: context.sp(130),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: context.sp(130),
                          height: context.sp(130),
                          child: CircularProgressIndicator(
                            value: 1.0,
                            strokeWidth: context.w(3),
                            color: AppColors.border,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        if (spo2 != null)
                          SizedBox(
                            width: context.sp(130),
                            height: context.sp(130),
                            child: CircularProgressIndicator(
                              value: (spo2! / 100).clamp(0.0, 1.0),
                              strokeWidth: context.w(3),
                              color: _ringColor,
                              strokeCap: StrokeCap.round,
                            ),
                          ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              spo2?.toString() ?? '--',
                              style: TextStyle(
                                fontSize: context.sp(32),
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context)
                                    .textTheme
                                    .displayLarge
                                    ?.color,
                              ),
                            ),
                            Text(
                              '%',
                              style: TextStyle(
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.color,
                              ),
                            ),
                            if (spo2 == null) ...[
                              SizedBox(height: context.h(0.6)),
                              Text(
                                'vitals.spo2_no_data'.tr(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: context.sp(10),
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.color,
                                ),
                              ),
                            ] else if (label != null) ...[
                              SizedBox(height: context.h(0.6)),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: context.w(2.2),
                                  vertical: context.h(0.25),
                                ),
                                decoration: BoxDecoration(
                                  color: _ringColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: context.sp(10.5),
                                    fontWeight: FontWeight.w700,
                                    color: _ringColor,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(2)),

              // Stats
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatItem(
                      context,
                      LocaleKeys.homeAvgToday.tr(),
                      avgToday != null ? '$avgToday%' : '--',
                    ),
                    SizedBox(height: context.h(2.5)),
                    _buildStatItem(
                      context,
                      LocaleKeys.homeMax.tr().toUpperCase(),
                      maxToday != null ? '$maxToday%' : '--',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(13),
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: context.h(0.5)),
        Text(
          value,
          style: TextStyle(
            fontSize: context.sp(17),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
      ],
    );
  }
}

/// Small inline badge shown near a BP value telling the patient/caregiver how
/// much to trust the number: signal quality plus calibration state. Shared by
/// the patient home page and the caregiver detail page so the two views
/// cannot drift apart. Secondary by design — muted colors, small text, never
/// competing with the BP number itself.
class VitalTrustBadge extends StatelessWidget {
  final double? signalQuality;
  final String? calibrationStatus;

  const VitalTrustBadge({
    super.key,
    this.signalQuality,
    this.calibrationStatus,
  });

  static String _calibrationLabel(String? status) {
    switch (status) {
      case 'cold_start':
        // A single calibration sample already produces an active offset
        // correction (see calibration_service.fit_calibration) -- it is
        // NOT "in progress"/pending. Showing it as calibrated avoids the
        // misleading impression that nothing has happened yet right after
        // the patient completes their first (re)calibration.
      case 'additive':
      case 'linear':
        return 'vitals.calibration_calibrated'.tr();
      case 'weak':
        return 'vitals.calibration_weak'.tr();
      case 'recalibration_due':
        return 'vitals.calibration_due'.tr();
      case 'not_calibrated':
        return 'vitals.calibration_not_calibrated'.tr();
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final chips = <Widget>[];

    if (signalQuality != null) {
      final good = signalQuality! >= 0.8;
      chips.add(_buildChip(
        context,
        isDark: isDark,
        icon: good ? Icons.network_check : Icons.warning_amber,
        label: good
            ? 'vitals.signal_good_short'.tr()
            : 'vitals.signal_poor_short'.tr(),
        color: good ? AppColors.success : AppColors.warning,
      ));
    }

    final calLabel = _calibrationLabel(calibrationStatus);
    if (calLabel.isNotEmpty) {
      final needsAttention = calibrationStatus == 'not_calibrated' ||
          calibrationStatus == 'recalibration_due' ||
          calibrationStatus == 'weak';
      chips.add(_buildChip(
        context,
        isDark: isDark,
        icon: Icons.tune,
        label: calLabel,
        color: needsAttention ? AppColors.warning : AppColors.textSecondary,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: context.w(2),
      runSpacing: context.h(0.6),
      children: chips,
    );
  }

  Widget _buildChip(
    BuildContext context, {
    required bool isDark,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(2.5),
        vertical: context.h(0.5),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: context.sp(13), color: color),
          SizedBox(width: context.w(1)),
          Text(
            label,
            style: TextStyle(
              fontSize: context.sp(11),
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Measurements History Card Widget
/// Navigates to full measurements history page
class MeasurementsHistoryCard extends StatelessWidget {
  final VoidCallback onTap;

  const MeasurementsHistoryCard({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.w(5)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(2.5)),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history,
                color: isDark ? Colors.white : Theme.of(context).primaryColor,
                size: context.sp(22),
              ),
            ),
            SizedBox(width: context.w(3)),
            Expanded(
              child: Text(
                LocaleKeys.homeMeasurementsHistory.tr(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
                    ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: context.sp(18),
              color: Theme.of(context).unselectedWidgetColor,
            ),
          ],
        ),
      ),
    );
  }
}
