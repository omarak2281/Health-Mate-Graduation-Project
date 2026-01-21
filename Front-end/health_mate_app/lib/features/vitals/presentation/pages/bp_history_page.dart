import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/vitals_provider.dart';
import './bp_detail_page.dart';

class BPHistoryPage extends ConsumerStatefulWidget {
  const BPHistoryPage({super.key});

  @override
  ConsumerState<BPHistoryPage> createState() => _BPHistoryPageState();
}

class _BPHistoryPageState extends ConsumerState<BPHistoryPage> {
  @override
  void initState() {
    super.initState();
    // Load history when page opens
    Future.microtask(() {
      ref.read(vitalsNotifierProvider.notifier).loadHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vitalsState = ref.watch(vitalsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.homeBpHistory.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: context.sp(22)),
            onPressed: () {
              ref.read(vitalsNotifierProvider.notifier).loadHistory();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(vitalsNotifierProvider.notifier).loadHistory();
        },
        child: vitalsState.history.isEmpty
            ? _buildEmptyState(context)
            : SingleChildScrollView(
                padding: EdgeInsets.all(context.w(4)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chart Card
                    Card(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: EdgeInsets.all(context.w(4)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocaleKeys.vitalsBpTrend.tr(),
                              style: TextStyle(
                                  fontSize: context.sp(18),
                                  fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: context.h(3)),
                            SizedBox(
                              height: context.h(25),
                              child: _buildChart(vitalsState.history),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(2.5)),

                    // History List
                    Text(
                      LocaleKeys.vitalsReadingHistory.tr(),
                      style: TextStyle(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: context.h(1)),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vitalsState.history.length,
                      itemBuilder: (context, index) {
                        final reading = vitalsState.history[index];
                        final riskColor = _getRiskColor(reading.riskLevel);

                        return Card(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          margin: EdgeInsets.only(bottom: context.h(1)),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BPDetailPage(bp: reading),
                                ),
                              );
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: context.w(4),
                                  vertical: context.h(0.5)),
                              leading: CircleAvatar(
                                radius: context.sp(22),
                                backgroundColor: riskColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(Icons.favorite,
                                    color: riskColor, size: context.sp(20)),
                              ),
                              title: Text(
                                '${reading.systolic}/${reading.diastolic}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: context.sp(18),
                                  color: riskColor,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: context.h(0.5)),
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(
                                          reading.measuredAt,
                                        ),
                                    style: TextStyle(fontSize: context.sp(13)),
                                  ),
                                  if (reading.heartRate != null)
                                    Text(
                                      LocaleKeys.vitalsHeartRateValue.tr(
                                        args: [reading.heartRate.toString()],
                                      ),
                                      style:
                                          TextStyle(fontSize: context.sp(13)),
                                    ),
                                  SizedBox(height: context.h(0.3)),
                                  Text(
                                    _getRiskText(reading.riskLevel),
                                    style: TextStyle(
                                      fontSize: context.sp(13),
                                      color: riskColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Icon(
                                reading.source == 'sensor'
                                    ? Icons.sensors
                                    : Icons.edit,
                                color: AppColors.textSecondary,
                                size: context.sp(20),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline,
              size: context.sp(80), color: AppColors.textSecondary),
          SizedBox(height: context.h(2)),
          Text(
            LocaleKeys.vitalsNoReadings.tr(),
            style: TextStyle(
                fontSize: context.sp(20),
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List readings) {
    if (readings.isEmpty) return const SizedBox();

    // Take last 7 readings for chart
    final chartData = readings.take(7).toList().reversed.toList();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                  final reading = chartData[value.toInt()];
                  return Padding(
                    padding: EdgeInsets.only(top: context.h(0.8)),
                    child: Text(
                      DateFormat('MM/dd').format(reading.measuredAt),
                      style: TextStyle(fontSize: context.sp(10)),
                    ),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: context.w(10),
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(fontSize: context.sp(10)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Systolic line
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.systolic.toDouble(),
              );
            }).toList(),
            isCurved: true,
            color: AppColors.error,
            barWidth: context.w(0.8),
            dotData: const FlDotData(show: true),
          ),
          // Diastolic line
          LineChartBarData(
            spots: chartData.asMap().entries.map((entry) {
              return FlSpot(
                entry.key.toDouble(),
                entry.value.diastolic.toDouble(),
              );
            }).toList(),
            isCurved: true,
            color: AppColors.primary,
            barWidth: context.w(0.8),
            dotData: const FlDotData(show: true),
          ),
        ],
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
}
