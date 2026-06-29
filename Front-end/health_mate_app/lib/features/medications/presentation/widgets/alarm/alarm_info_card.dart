import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../../core/constants/locale_keys.dart';
import '../../../../../core/models/medication.dart';

class AlarmInfoCard extends StatelessWidget {
  final Medication medication;
  final Color accentColor;

  const AlarmInfoCard({
    super.key,
    required this.medication,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF141929),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: accentColor.withValues(alpha: 0.12)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _InfoCell(
                    icon: Icons.medication_rounded,
                    label: LocaleKeys.medicationsDosage.tr(),
                    value: medication.dosage,
                    color: accentColor),
                Container(
                    width: 1,
                    height: 50,
                    color: Colors.white12,
                    margin: const EdgeInsets.symmetric(horizontal: 16)),
                _InfoCell(
                    icon: Icons.access_time_rounded,
                    label: LocaleKeys.medicationsTime.tr(),
                    value: medication.scheduledTimes.isNotEmpty
                        ? _getLocalizedTime(
                            context, medication.scheduledTimes.first)
                        : "--:--",
                    color: accentColor),
              ],
            ),
            if (medication.instructions != null &&
                medication.instructions!.isNotEmpty) ...[
              const Divider(color: Colors.white10, height: 32),
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Colors.white54, size: 16),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      medication.instructions!,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLocalizedTime(BuildContext context, String timeStr) {
    if (timeStr.isEmpty) return "--:--";
    try {
      final parts = timeStr.split(':');
      final tod =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      return tod.format(context);
    } catch (e) {
      return timeStr;
    }
  }
}

class _InfoCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Color(0xFF6B7A99),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 3),
                Text(value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
