import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/iot_provider.dart';

/// IoT Screen
/// Control sensors and medicine box

class IoTScreen extends ConsumerWidget {
  const IoTScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iotState = ref.watch(iotNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.vitalsIoTDevices.tr())),
      body: RefreshIndicator(
        onRefresh: () => ref.read(iotNotifierProvider.notifier).loadStatus(),
        child: iotState.isLoading && iotState.sensors.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSensorSection(context, iotState),
                  const SizedBox(height: 24),
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        ...state.sensors.map((sensor) {
          final isPpg = sensor['sensor_type'] == 'ppg';
          return _buildSensorTile(
            context,
            name: isPpg
                ? LocaleKeys.vitalsPpgSensor.tr()
                : LocaleKeys.vitalsEcgSensor.tr(),
            icon: isPpg ? Icons.favorite : Icons.monitor_heart,
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
    required IconData icon,
    required String status,
    required double quality,
  }) {
    final isConnected = status == 'connected';
    final qualityText = quality > 0.8
        ? LocaleKeys.vitalsSignalExcellent.tr()
        : LocaleKeys.vitalsSignalPoor.tr();

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isConnected ? AppColors.primary : AppColors.textSecondary,
        ),
        title: Text(name),
        subtitle: Text(
          isConnected
              ? '${LocaleKeys.vitalsConnected.tr()} - $qualityText'
              : LocaleKeys.vitalsDisconnected.tr(),
          style: TextStyle(
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
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
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
      child: InkWell(
        onTap: () => _testDrawer(context, ref, number),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                color: isActive ? AppColors.primary : null,
              ),
              const SizedBox(height: 8),
              Text(
                '${LocaleKeys.vitalsDrawer.tr()} $number',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                isActive
                    ? LocaleKeys.medicationsActive.tr()
                    : LocaleKeys.medicationsInactive.tr(),
                style: TextStyle(
                  fontSize: 10,
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
