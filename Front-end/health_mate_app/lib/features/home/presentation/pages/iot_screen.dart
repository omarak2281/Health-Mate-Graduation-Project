import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/iot_provider.dart';

class IoTScreen extends ConsumerWidget {
  const IoTScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iotState = ref.watch(iotNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.vitalsIoTDevices.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(iotNotifierProvider.notifier).loadStatus(),
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

  Widget _buildSensorSection(BuildContext context, IoTState state) {
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
          return _buildSensorTile(
            context,
            name: isPpg
                ? LocaleKeys.vitalsPpgSensor.tr()
                : LocaleKeys.vitalsEcgSensor.tr(),
            icon: isPpg ? AppIcons.heartRate : AppIcons.bloodPressure,
            status: sensor['status'],
            quality: sensor['signal_quality'],
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
    required double quality,
  }) {
    final isConnected = status == 'connected';
    final qualityText = quality > 0.8
        ? LocaleKeys.vitalsSignalExcellent.tr()
        : LocaleKeys.vitalsSignalPoor.tr();

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(bottom: context.h(1.5)),
      child: ListTile(
        leading: icon is IconData
            ? Icon(
                icon,
                size: context.sp(24),
                color:
                    isConnected ? AppColors.primary : AppColors.textSecondary,
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
        title: Text(name,
            style: TextStyle(
                fontSize: context.sp(16), fontWeight: FontWeight.bold)),
        subtitle: Text(
          isConnected
              ? '${LocaleKeys.vitalsConnected.tr()} - $qualityText'
              : LocaleKeys.vitalsDisconnected.tr(),
          style: TextStyle(
            fontSize: context.sp(14),
            color: isConnected ? AppColors.success : AppColors.error,
          ),
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
                '${LocaleKeys.vitalsDrawer.tr()} $number',
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
