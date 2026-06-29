import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medication.dart';
import 'local_notification_service.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/locale_keys.dart';

/// Alarm Scheduler Service
/// Responsible for scheduling local medication alarms for offline reliability.
class AlarmSchedulerService {
  final LocalNotificationService _localNotifications;

  AlarmSchedulerService(this._localNotifications);

  static const int _baseAlarmId = 2000; // Offset for scheduled alarms

  /// Schedules all upcoming medication alarms for the next [days].
  Future<void> scheduleAll(List<Medication> medications, {int days = 7}) async {
    debugPrint(
        '⏰ Scheduling local alarms for ${medications.length} medications for the next $days days...');

    // 1. Cancel all previously scheduled alarms in our range efficiently
    await cancelAll();

    int alarmCount = 0;
    final now = DateTime.now();

    for (final med in medications) {
      if (!med.isActive) continue;

      for (final timeStr in med.scheduledTimes) {
        try {
          final parts = timeStr.split(':');
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);

          for (int day = 0; day < days; day++) {
            var scheduledDate =
                DateTime(now.year, now.month, now.day, hour, minute)
                    .add(Duration(days: day));

            // Skip if time has already passed today
            if (scheduledDate.isBefore(now)) continue;

            final int id = _baseAlarmId + (alarmCount % 500);
            alarmCount++;

            final payload = jsonEncode({
              'id': med.id,
              'type': 'single',
              'medicine': med.toJson(),
              'is_local': true,
            });

            final title = LocaleKeys.medicationsAlarmTitle.tr();
            final body = LocaleKeys.medicationsTimeToTake
                .tr(namedArgs: {'name': med.name});

            await _localNotifications.scheduleMedicationAlarmAt(
              id: id,
              title: title,
              body: body,
              scheduledDate: scheduledDate,
              payload: payload,
            );
          }
        } catch (e) {
          debugPrint(
              '⚠️ Error scheduling alarm for ${med.name} at $timeStr: $e');
        }
      }
    }
    debugPrint('✅ Successfully scheduled $alarmCount local alarms.');
  }

  Future<void> cancelAll() async {
    // Cancel in a batch without blocking too much
    for (int i = 0; i < 500; i++) {
      _localNotifications.cancelSnoozeReminder(_baseAlarmId + i);
    }
    _localNotifications.cancelSnoozeReminder(1999); // Cancel test alarm
  }
}

final alarmSchedulerServiceProvider = Provider<AlarmSchedulerService>((ref) {
  return AlarmSchedulerService(ref.watch(localNotificationServiceProvider));
});
