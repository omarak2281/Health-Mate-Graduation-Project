import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/constants/iot_constants.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/push_notification_service.dart';

/// Mirrors [MedicationAlarmState]/[MedicationAlarmNotifier], simplified for
/// BP reminders: no IoT/hardware drawers, no server-side snooze endpoint —
/// snoozing is a local-only convenience reschedule of the same reminder.
class BPReminderAlarmState {
  final bool isSnoozed;
  final Duration snoozeRemaining;

  const BPReminderAlarmState({
    this.isSnoozed = false,
    this.snoozeRemaining = Duration.zero,
  });

  BPReminderAlarmState copyWith({
    bool? isSnoozed,
    Duration? snoozeRemaining,
  }) {
    return BPReminderAlarmState(
      isSnoozed: isSnoozed ?? this.isSnoozed,
      snoozeRemaining: snoozeRemaining ?? this.snoozeRemaining,
    );
  }
}

class BPReminderAlarmNotifier extends StateNotifier<BPReminderAlarmState> {
  final LocalNotificationService _localNotifications;

  Timer? _countdownTimer;
  Timer? _autoSnoozeTimer;

  BPReminderAlarmNotifier({
    required LocalNotificationService localNotifications,
  })  : _localNotifications = localNotifications,
        super(const BPReminderAlarmState()) {
    // Auto-Snooze: if the user takes no action within 5 minutes, snooze
    // automatically -- same behavior as the medication alarm.
    _autoSnoozeTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !state.isSnoozed) {
        snooze();
      }
    });
  }

  Future<void> snooze({bool skipNotificationCancel = false}) async {
    _autoSnoozeTimer?.cancel();

    final snoozeDuration = Duration(minutes: IoTConstants.snoozeDurationMinutes);
    state = state.copyWith(isSnoozed: true, snoozeRemaining: snoozeDuration);

    if (!skipNotificationCancel) {
      await _localNotifications.cancelAllAlarms();
    }

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = state.snoozeRemaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();
        PushNotificationService.instance.pushBpReminderAlarmPage();
        state = state.copyWith(isSnoozed: false, snoozeRemaining: Duration.zero);
      } else {
        state = state.copyWith(snoozeRemaining: remaining);
      }
    });

    try {
      await _localNotifications.scheduleSnoozeReminder(
        id: LocalNotificationService.bpReminderId,
        title: LocaleKeys.vitalsBpReminderTitle.tr(),
        body: LocaleKeys.vitalsBpReminderBody.tr(),
        delay: snoozeDuration,
        payload: jsonEncode({'type': 'bp_reminder'}),
      );
    } catch (_) {
      // Non-fatal -- the in-memory countdown timer above still re-triggers
      // the alarm page if the app stays alive.
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoSnoozeTimer?.cancel();
    super.dispose();
  }
}

final bpReminderAlarmNotifierProvider =
    StateNotifierProvider<BPReminderAlarmNotifier, BPReminderAlarmState>(
  (ref) => BPReminderAlarmNotifier(
    localNotifications: LocalNotificationService.instance,
  ),
);
