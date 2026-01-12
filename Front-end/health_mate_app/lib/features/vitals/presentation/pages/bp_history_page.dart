import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/vitals_provider.dart';
import './bp_detail_page.dart';

/// BP History Page
/// Shows BP readings history with chart

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
        title: Text(LocaleKeys.homeBpHistory.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
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
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Chart Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocaleKeys.vitalsBpTrend.tr(),
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              height: 200,
                              child: _buildChart(vitalsState.history),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // History List
                    Text(
                      LocaleKeys.vitalsReadingHistory.tr(),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: vitalsState.history.length,
                      itemBuilder: (context, index) {
                        final reading = vitalsState.history[index];
                        final riskColor = _getRiskColor(reading.riskLevel);

                        return Card(
                          child: InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => BPDetailPage(bp: reading),
                                ),
                              );
                            },
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: riskColor.withValues(
                                  alpha: 0.1,
                                ),
                                child: Icon(Icons.favorite, color: riskColor),
                              ),
                              title: Text(
                                '${reading.systolic}/${reading.diastolic}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: riskColor,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(
                                      reading.measuredAt,
                                    ),
                                  ),
                                  if (reading.heartRate != null)
                                    Text(
                                      LocaleKeys.vitalsHeartRateValue.tr(
                                        args: [reading.heartRate.toString()],
                                      ),
                                    ),
                                  Text(
                                    _getRiskText(reading.riskLevel),
                                    style: TextStyle(
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
          Icon(Icons.timeline, size: 80, color: AppColors.textSecondary),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.vitalsNoReadings.tr(),
            style: Theme.of(context).textTheme.headlineSmall,
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
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < chartData.length) {
                  final reading = chartData[value.toInt()];
                  return Text(
                    DateFormat('MM/dd').format(reading.measuredAt),
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
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
            barWidth: 3,
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
            barWidth: 3,
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
