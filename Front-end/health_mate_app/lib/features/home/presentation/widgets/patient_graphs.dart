import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:ui' as ui;
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../vitals/presentation/pages/bp_history_page.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';

/// Blood Pressure Trend Card Widget
/// Displays recent completed BP readings and opens the full history on tap.
class BloodPressureTrendCard extends ConsumerWidget {
  const BloodPressureTrendCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final history = ref.watch(vitalsNotifierProvider).history;
    final chartData = history
        .where((reading) =>
            reading.displaySystolic != null && reading.displayDiastolic != null)
        .take(7)
        .toList()
        .reversed
        .toList();

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const BPHistoryPage()),
        );
      },
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
                  child: Icon(
                    Icons.show_chart,
                    color:
                        isDark ? Colors.white : Theme.of(context).primaryColor,
                    size: context.sp(22),
                  ),
                ),
                SizedBox(width: context.w(3)),
                Expanded(
                  child: Text(
                    LocaleKeys.vitalsBpTrend.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : null,
                        ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Theme.of(context)
                      .unselectedWidgetColor
                      .withValues(alpha: 0.55),
                  size: context.sp(16),
                ),
              ],
            ),
            SizedBox(height: context.h(3)),

            Container(
              height: context.h(20),
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                context.w(1),
                context.h(1.5),
                context.w(2),
                context.h(1),
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: chartData.length < 2
                  ? chartData.isEmpty
                      ? _buildEmptyState(context)
                      : _buildSingleReadingState(context, chartData.first)
                  : LineChart(
                      LineChartData(
                        minY: 40,
                        maxY: 190,
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 30,
                          getDrawingHorizontalLine: (_) => FlLine(
                            color: Theme.of(context)
                                .dividerColor
                                .withValues(alpha: 0.35),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: context.w(8),
                              interval: 30,
                              getTitlesWidget: (value, meta) => Text(
                                value.toInt().toString(),
                                style: TextStyle(
                                  fontSize: context.sp(9),
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                ),
                              ),
                            ),
                          ),
                          bottomTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        lineTouchData: const LineTouchData(enabled: false),
                        lineBarsData: [
                          _buildLine(
                            chartData,
                            isSystolic: true,
                            color: AppColors.error,
                          ),
                          _buildLine(
                            chartData,
                            isSystolic: false,
                            color: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
            ),
            if (chartData.length >= 2) ...[
              SizedBox(height: context.h(1.2)),
              Row(
                children: [
                  _buildLegend(
                      context, AppColors.error, LocaleKeys.vitalsSystolic.tr()),
                  SizedBox(width: context.w(4)),
                  _buildLegend(context, AppColors.primary,
                      LocaleKeys.vitalsDiastolic.tr()),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  LineChartBarData _buildLine(
    List<dynamic> readings, {
    required bool isSystolic,
    required Color color,
  }) {
    return LineChartBarData(
      spots: readings.asMap().entries.map((entry) {
        final reading = entry.value;
        final value =
            isSystolic ? reading.displaySystolic! : reading.displayDiastolic!;
        return FlSpot(entry.key.toDouble(), value.toDouble());
      }).toList(),
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withValues(alpha: 0.08),
      ),
    );
  }

  Widget _buildLegend(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: context.sp(9),
          height: context.sp(9),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: context.w(1)),
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(11),
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart_rounded,
            size: context.sp(48),
            color:
                Theme.of(context).unselectedWidgetColor.withValues(alpha: 0.3),
          ),
          SizedBox(height: context.h(1)),
          Text(
            LocaleKeys.vitalsNoReadings.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyMedium?.color,
              fontSize: context.sp(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleReadingState(BuildContext context, dynamic reading) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart_rounded,
            size: context.sp(42),
            color: AppColors.primary.withValues(alpha: 0.7),
          ),
          SizedBox(height: context.h(1)),
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Text(
              '${reading.displaySystolic} / ${reading.displayDiastolic}',
              style: TextStyle(
                fontSize: context.sp(24),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.displayMedium?.color,
              ),
            ),
          ),
          Text(
            LocaleKeys.homeMmHg.tr(),
            style: TextStyle(
              fontSize: context.sp(12),
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          SizedBox(height: context.h(0.8)),
          Text(
            'vitals.bp_trend_needs_more'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(12),
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
