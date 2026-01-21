import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:math' as math;
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';

/// Heart Rate Card Widget
/// Displays current heart rate with circular progress indicator
/// Shows average and max values for today
class HeartRateCard extends StatelessWidget {
  final int? heartRate;
  final int? avgToday;
  final int? maxToday;

  const HeartRateCard({
    super.key,
    this.heartRate,
    this.avgToday,
    this.maxToday,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              Text(
                LocaleKeys.vitalsHeartRate.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
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
                              color: Colors.lightGreenAccent[400],
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
  final VoidCallback onCheckNow;

  const BloodPressureCardExpert({
    super.key,
    this.systolic,
    this.diastolic,
    this.time,
    required this.onCheckNow,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Determine risk level based on BP values
    String riskLevel = _determineRiskLevel();

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
                  width: context.w(50),
                  height: context.h(12),
                  child: CustomPaint(
                    painter: SemiCircleGaugePainter(
                      percentage: _calculateGaugePercentage(),
                    ),
                  ),
                ),
                SizedBox(height: context.h(1)),

                // BP Reading
                Text(
                  systolic != null && diastolic != null
                      ? '$systolic / $diastolic'
                      : '-- / --',
                  style: TextStyle(
                    fontSize: context.sp(28),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.displayMedium?.color,
                  ),
                ),
                Text(
                  LocaleKeys.homeMmHg.tr(),
                  style: TextStyle(
                    fontSize: context.sp(14),
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: context.h(3)),

          // Risk Level Indicators
          Row(
            children: [
              _buildRiskIndicator(
                context,
                LocaleKeys.vitalsRiskLow.tr(),
                Colors.blue[400]!,
                riskLevel == 'low',
              ),
              SizedBox(width: context.w(2)),
              _buildRiskIndicator(
                context,
                LocaleKeys.vitalsRiskNormal.tr(),
                Colors.lightGreenAccent[400]!,
                riskLevel == 'normal',
              ),
              SizedBox(width: context.w(2)),
              _buildRiskIndicator(
                context,
                LocaleKeys.vitalsRiskHigh.tr(),
                Colors.deepOrange[400]!,
                riskLevel == 'high',
              ),
            ],
          ),
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
    if (sys >= 140 || dia >= 90) return 'high';
    return 'normal';
  }

  double _calculateGaugePercentage() {
    if (systolic == null) return 0.5;

    final sys = int.tryParse(systolic!) ?? 120;
    // Normalize systolic (60-180 range) to 0-1
    return ((sys - 60) / 120).clamp(0.0, 1.0);
  }

  Widget _buildRiskIndicator(
    BuildContext context,
    String label,
    Color color,
    bool isSelected,
  ) {
    return Expanded(
      child: Column(
        children: [
          Container(
            height: context.h(0.8),
            decoration: BoxDecoration(
              color: isSelected ? color : AppColors.border,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SizedBox(height: context.h(0.8)),
          Text(
            label,
            style: TextStyle(
              fontSize: context.sp(12),
              color:
                  isSelected ? AppColors.textPrimary : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Semi-Circle Gauge Painter
/// Custom painter for blood pressure gauge visualization
class SemiCircleGaugePainter extends CustomPainter {
  final double percentage;

  SemiCircleGaugePainter({required this.percentage});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height * 2);
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 14
      ..strokeCap = StrokeCap.round;

    // Draw background arc
    canvas.drawArc(rect, math.pi, math.pi, false, paint);

    // Draw progress arc with gradient effect
    paint.color = Colors.lightGreenAccent[400]!;
    canvas.drawArc(rect, math.pi, math.pi * percentage, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
            Text(
              LocaleKeys.homeMeasurementsHistory.tr(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: context.sp(18),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : null,
                  ),
            ),
            const Spacer(),
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
