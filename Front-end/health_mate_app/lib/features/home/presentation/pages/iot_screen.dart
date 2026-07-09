import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/models/vital_sign.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/iot_provider.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';

class IoTScreen extends ConsumerStatefulWidget {
  const IoTScreen({super.key});

  @override
  ConsumerState<IoTScreen> createState() => _IoTScreenState();
}

class _IoTScreenState extends ConsumerState<IoTScreen> {
  @override
  void initState() {
    super.initState();
    // The last-reading rows come from the vitals history already cached by
    // the provider; refresh it once on entry so the data isn't stale.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(vitalsNotifierProvider.notifier).loadHistory();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final iotState = ref.watch(iotNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.vitalsIoTDevices.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(iotNotifierProvider.notifier).loadStatus();
          await ref.read(vitalsNotifierProvider.notifier).loadHistory();
        },
        child: iotState.isLoading && iotState.sensors.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(context.w(4)),
                children: [
                  _buildSensorSection(context, iotState),
                  SizedBox(height: context.h(3)),
                  _buildMedicineBoxSection(context, ref, iotState),
                ],
              ),
      ),
    );
  }

  /// Latest reading from the sensor pipeline (any status), used to show what
  /// the device last actually measured, next to its connection state.
  VitalSign? get _latestSensorReading {
    final history = ref.watch(vitalsNotifierProvider).history;
    for (final v in history) {
      if (v.source == 'sensor') return v;
    }
    return history.isNotEmpty ? history.first : null;
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'vitals.time_just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'vitals.time_min_ago'
          .tr(namedArgs: {'min': diff.inMinutes.toString()});
    }
    if (diff.inHours < 24) {
      return 'vitals.time_hours_ago'
          .tr(namedArgs: {'hours': diff.inHours.toString()});
    }
    return DateFormat.yMd().add_jm().format(time);
  }

  Widget _buildSensorSection(BuildContext context, IoTState state) {
    final latest = _latestSensorReading;
    final vitalsLoading = ref.watch(vitalsNotifierProvider).isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.vitalsSensor.tr(),
          style:
              TextStyle(fontSize: context.sp(18), fontWeight: FontWeight.bold),
        ),
        SizedBox(height: context.h(2)),
        ...state.sensors.map((sensor) {
          final isPpg = sensor['sensor_type'] == 'ppg';

          String? lastReadingText;
          if (latest != null) {
            if (isPpg) {
              final parts = <String>[
                if (latest.heartRate != null)
                  '${latest.heartRate} ${LocaleKeys.homeBpm.tr()}',
                if (latest.spo2 != null) '${latest.spo2}%',
              ];
              if (parts.isNotEmpty) {
                lastReadingText =
                    '${parts.join(', ')} — ${_relativeTime(latest.measuredAt)}';
              }
            } else if (latest.signalQuality != null) {
              final q = latest.hasGoodSignal
                  ? LocaleKeys.vitalsSignalExcellent.tr()
                  : LocaleKeys.vitalsSignalPoor.tr();
              lastReadingText = '$q — ${_relativeTime(latest.measuredAt)}';
            }
          }

          return _buildSensorTile(
            context,
            name: isPpg
                ? LocaleKeys.vitalsPpgSensor.tr()
                : LocaleKeys.vitalsEcgSensor.tr(),
            icon: isPpg ? AppIcons.heartRate : AppIcons.bloodPressure,
            status: sensor['status'],
            lastReadingText: lastReadingText,
            lastReadingLoading: vitalsLoading && latest == null,
          );
        }),
      ],
    );
  }

  Widget _buildSensorTile(
    BuildContext context, {
    required String name,
    required dynamic icon,
    required String status,
    String? lastReadingText,
    bool lastReadingLoading = false,
  }) {
    final isConnected = status == 'connected';
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: context.h(1.5)),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(4),
          vertical: context.h(1.4),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(top: context.h(0.3)),
              child: icon is IconData
                  ? Icon(
                      icon,
                      size: context.sp(24),
                      color: isConnected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    )
                  : SizedBox(
                      width: context.sp(24),
                      height: context.sp(24),
                      child: icon is Function
                          ? icon(
                              size: context.sp(24),
                              color: isConnected
                                  ? AppColors.primary
                                  : AppColors.textSecondary)
                          : (icon is Widget ? icon : null),
                    ),
            ),
            SizedBox(width: context.w(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: TextStyle(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: context.h(0.4)),
                  Text(
                    isConnected
                        ? LocaleKeys.vitalsConnected.tr()
                        : LocaleKeys.vitalsDisconnected.tr(),
                    style: TextStyle(
                      fontSize: context.sp(14),
                      color:
                          isConnected ? AppColors.success : AppColors.error,
                    ),
                  ),
                  SizedBox(height: context.h(0.4)),
                  if (lastReadingLoading)
                    SizedBox(
                      height: context.sp(12),
                      width: context.sp(12),
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Text(
                      lastReadingText != null
                          ? '${'vitals.last_reading'.tr()}: $lastReadingText'
                          : 'vitals.no_readings_yet'.tr(),
                      style: TextStyle(
                        fontSize: context.sp(12.5),
                        color: mutedColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineBoxSection(
    BuildContext context,
    WidgetRef ref,
    IoTState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.vitalsSmartMedicineBox.tr(),
          style:
              TextStyle(fontSize: context.sp(18), fontWeight: FontWeight.bold),
        ),
        SizedBox(height: context.h(2)),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: context.w(3),
            mainAxisSpacing: context.h(1.5),
          ),
          itemCount: state.drawers.length,
          itemBuilder: (context, index) {
            final drawer = state.drawers[index];
            return _buildDrawerCard(context, ref, drawer);
          },
        ),
      ],
    );
  }

  Widget _buildDrawerCard(BuildContext context, WidgetRef ref, dynamic drawer) {
    final number = drawer['drawer'];
    final isActive = drawer['led_on'] || drawer['buzzer_on'];

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _testDrawer(context, ref, number),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(context.w(3)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: context.sp(24),
                color: isActive ? AppColors.primary : AppColors.textSecondary,
              ),
              SizedBox(height: context.h(1)),
              Text(
                LocaleKeys.vitalsDrawerWithNumber.tr(
                  namedArgs: {'num': number.toString()},
                ),
                style: TextStyle(
                    fontSize: context.sp(14), fontWeight: FontWeight.bold),
              ),
              Text(
                isActive
                    ? LocaleKeys.medicationsActive.tr()
                    : LocaleKeys.medicationsInactive.tr(),
                style: TextStyle(
                  fontSize: context.sp(10),
                  color: isActive ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _testDrawer(BuildContext context, WidgetRef ref, int number) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LocaleKeys.vitalsTestingDrawer.tr())),
    );
    ref.read(iotNotifierProvider.notifier).testDrawer(number);
  }
}
