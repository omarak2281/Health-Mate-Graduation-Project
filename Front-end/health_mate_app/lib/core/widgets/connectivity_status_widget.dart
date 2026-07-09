import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/home/presentation/providers/iot_provider.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';

// ─── Medicine Box Connectivity Widget ──────────────────────────────────────────

class ConnectivityStatusWidget extends ConsumerWidget {
  final bool showText;
  const ConnectivityStatusWidget({super.key, this.showText = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(hardwareStatusProvider);
    return _StatusBadge(
      isConnected: isConnected,
      label: 'vitals.smart_box_status'.tr(),
      showText: showText,
    );
  }
}

// ─── Sensor Device (BP Hardware) Connectivity Widget ────────────────────────

class SensorsDeviceStatusWidget extends ConsumerWidget {
  final bool showText;
  final String? patientId;

  const SensorsDeviceStatusWidget({
    super.key,
    this.showText = true,
    this.patientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isConnected;
    if (patientId != null) {
      final sensorsAsync = ref.watch(patientSensorsStreamProvider(patientId!));
      isConnected = sensorsAsync.maybeWhen(
        data: (sensors) => _checkFreshness(sensors),
        orElse: () => false,
      );
    } else {
      final iotState = ref.watch(iotNotifierProvider);
      isConnected = _checkFreshness(iotState.sensors);
    }

    return _StatusBadge(
      isConnected: isConnected,
      label: 'vitals.vitals_device_status'.tr(),
      showText: showText,
    );
  }

  bool _checkFreshness(List<dynamic> sensors) {
    if (sensors.isEmpty) return false;
    try {
      final firstSensor = sensors.first;
      final lastPingStr = firstSensor['last_ping'];
      if (lastPingStr == null) return false;
      // Backend returns timestamps without timezone suffix (e.g. "2026-07-02T17:35:38"),
      // so we treat them as UTC by appending 'Z' when missing.
      final normalised = lastPingStr.endsWith('Z') || lastPingStr.contains('+')
          ? lastPingStr
          : '${lastPingStr}Z';
      final lastPing = DateTime.parse(normalised).toUtc();
      final now = DateTime.now().toUtc();
      return now.difference(lastPing).inSeconds.abs() < 35;
    } catch (_) {
      return false;
    }
  }
}

// ─── Private Shared Badge Widget ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final bool isConnected;
  final String label;
  final bool showText;

  const _StatusBadge({
    required this.isConnected,
    required this.label,
    required this.showText,
  });

  @override
  Widget build(BuildContext context) {
    final color = isConnected ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 6),
            Text(
              '$label: ${isConnected ? "vitals.connected".tr() : "vitals.disconnected".tr()}',
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
