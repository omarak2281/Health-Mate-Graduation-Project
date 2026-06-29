import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../constants/locale_keys.dart';
import '../theme/app_colors.dart';
import 'background_translation_service.dart';
import 'push_notification_service.dart';

/// Local Notification Service
/// Thin, stateless wrapper around [FlutterLocalNotificationsPlugin].
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String?
      _lastHandledResponseId; // ✅ Track last handled notification to prevent re-triggering

  // ─── Notification Action IDs ──────────────────────────────────────────────
  static const String actionTaken = 'TAKEN';
  static const String actionSnooze = 'SNOOZE';
  static const int _snoozeChannelId = 1002; // ✅ Changed ID to force refresh

  // ─── Initialise ───────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Initialize Timezones
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint('[LocalNotificationService] TimeZone set to: $timeZoneName');
    } catch (e) {
      debugPrint('⚠️ Could not set local timezone: $e');
    }

    // Request battery optimization exemption (critical for reliable alarms)
    // Without this, Doze mode can silence AlarmManager on many devices.
    await _requestBatteryOptimizationExemption();

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Handle the case where the notification launched the app
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details != null && details.didNotificationLaunchApp) {
      if (details.notificationResponse != null) {
        final response = details.notificationResponse!;
        // Only handle if it's a new interaction
        final responseId = '${response.id}_${response.actionId}';
        if (_lastHandledResponseId != responseId) {
          _lastHandledResponseId = responseId;
          _handleNotificationResponse(response);
        }
      }
    }

    _initialized = true;
    debugPrint('[LocalNotificationService] initialised with TimeZones');
  }

  /// Requests battery optimization exemption.
  /// On Android, this opens the system dialog asking the user to allow
  /// the app to run in the background unrestricted. Without this, Doze mode
  /// can delay or cancel AlarmManager alarms silently.
  Future<void> _requestBatteryOptimizationExemption() async {
    try {
      final status = await Permission.ignoreBatteryOptimizations.status;
      if (status.isGranted) {
        debugPrint('✅ [Battery] Already exempted from battery optimization.');
        return;
      }
      final result = await Permission.ignoreBatteryOptimizations.request();
      debugPrint('🔋 [Battery] Exemption request result: $result');
    } catch (e) {
      // Non-critical — worst case: snooze may be slightly delayed on some devices
      debugPrint('⚠️ [Battery] Could not request battery exemption: $e');
    }
  }

  void _handleNotificationResponse(NotificationResponse response) {
    if (response.payload != null && response.payload!.trim().isNotEmpty) {
      final responseId = '${response.id}_${response.actionId}';
      if (_lastHandledResponseId == responseId) return;
      _lastHandledResponseId = responseId;

      try {
        final data = jsonDecode(response.payload!);
        if (response.actionId == actionTaken) {
          // Clear all notifications to ensure no ghost alarms
          instance.cancelAllAlarms();
          PushNotificationService.instance
              .handleNotificationAction(actionTaken, data);
        } else if (response.actionId == actionSnooze) {
          // Trigger the foreground snooze logic
          instance.cancelAllAlarms();
          PushNotificationService.instance
              .handleNotificationAction(actionSnooze, data);
        } else {
          // Tapping the notification itself → navigate to alarm
          PushNotificationService.instance.handleNotificationTap(data);
        }
      } catch (e) {
        debugPrint(
            'Error parsing notification payload: $e\nPayload was: "${response.payload}"');
      }
    }
  }

  /// Build alarm details.
  AndroidNotificationDetails _buildAndroidAlarmDetails() {
    final translator = BackgroundTranslationService.instance;
    // We assume translator.init() was already called in background handler,
    // but in foreground it doesn't hurt to have a fallback or check.

    return AndroidNotificationDetails(
      'medication_alarms',
      'Medication Alarms',
      channelDescription: 'Persistent alarms for medication reminders',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: const BigTextStyleInformation(''),
      // ✅ Behave like a real physical alarm
      audioAttributesUsage: AudioAttributesUsage.alarm,
      autoCancel: false,
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: 4
      actions: [
        AndroidNotificationAction(
          actionTaken,
          translator.translate(LocaleKeys.medicationsConfirmTakenShort),
          titleColor: AppColors.expertTeal,
          showsUserInterface: false, // Handle in background without opening app
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSnooze,
          translator.translate(LocaleKeys.medicationsSnoozeAction),
          showsUserInterface:
              false, // ✅ Don't interrupt user, handle in background
          cancelNotification: true,
        ),
      ],
    );
  }

  DarwinNotificationDetails get _iOSDetails => const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        categoryIdentifier: 'MEDICATION_ALARM',
      );

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<void> showMedicationAlarm({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) await init();

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: _buildAndroidAlarmDetails(),
        iOS: _iOSDetails,
      ),
      payload: payload,
    );
  }

  /// Schedules a snooze reminder using native zonedSchedule.
  /// Uses [exactAllowWhileIdle] — SCHEDULE_EXACT_ALARM is already declared
  /// in AndroidManifest.xml so this fires precisely on time even in Doze mode.
  Future<void> scheduleSnoozeReminder({
    required int id,
    required String title,
    required String body,
    required Duration delay,
    String? payload,
  }) async {
    if (!_initialized) await init();

    // Always use alarm details with TAKEN/SNOOZE action buttons so the user
    // can act directly from the notification shade after snooze fires.
    final details = _buildAndroidAlarmDetails();

    // Calculate scheduled time
    final scheduledDate = tz.TZDateTime.now(tz.local).add(delay);

    debugPrint(
        '[LocalNotificationService] ⏱ Scheduling snooze at ${scheduledDate.toString()} (in ${delay.inMinutes} min)');

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: details,
          iOS: _iOSDetails,
        ),
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        // ✅ exactAllowWhileIdle: fires precisely even in Doze/standby mode.
        // Requires SCHEDULE_EXACT_ALARM (declared in AndroidManifest.xml).
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      debugPrint(
          '[LocalNotificationService] ✅ Snooze scheduled for +${delay.inMinutes} min → ${scheduledDate.toString()}');
    } catch (e) {
      debugPrint('[LocalNotificationService] ❌ Snooze schedule failed: $e');
      // Fallback to inexact if exact scheduling fails (permission denied)
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledDate,
        NotificationDetails(
          android: details,
          iOS: _iOSDetails,
        ),
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint(
          '[LocalNotificationService] ⚠️ Snooze scheduled as INEXACT (fallback) for +${delay.inMinutes} min');
    }
  }

  Future<void> cancelSnoozeReminder(int id) async {
    if (!_initialized) await init();
    await _plugin.cancel(id);
  }

  /// Schedules a medication alarm at a specific absolute time.
  Future<void> scheduleMedicationAlarmAt({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    if (!_initialized) await init();

    final tzDate = tz.TZDateTime.from(scheduledDate, tz.local);

    debugPrint(
        '[LocalNotificationService] Scheduling ID: $id at ${tzDate.toString()}');

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzDate,
        NotificationDetails(
          android: _buildAndroidAlarmDetails(),
          iOS: _iOSDetails,
        ),
        payload: payload,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
      debugPrint('[LocalNotificationService] ✅ Successfully scheduled ID: $id');
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] ❌ Failed to schedule ID: $id - Error: $e');
    }
  }

  /// Cancels all active alarm & snooze notifications.
  Future<void> cancelAllAlarms() async {
    if (!_initialized) await init();
    await _plugin.cancel(100); // FCM-triggered alarm ID
    await _plugin.cancel(_snoozeChannelId); // Snooze reminder ID (1001)
    debugPrint('[LocalNotificationService] 🔕 All alarms & snooze cancelled.');
  }

  static int get defaultSnoozeId => _snoozeChannelId;
}

/// ─── Top-level Background Handler ──────────────────────────────────────────
/// MUST be a top-level function annotated with @pragma('vm:entry-point').
/// This is called when a notification action is tapped while the app is
/// in the background or terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) async {
  debugPrint(
      '🔔 [BackgroundAction] ID=${response.id} Action=${response.actionId}');

  if (response.payload != null && response.payload!.isNotEmpty) {
    try {
      final data = jsonDecode(response.payload!);

      if (response.actionId == LocalNotificationService.actionTaken ||
          response.actionId == LocalNotificationService.actionSnooze) {
        // We use the singleton instance which will re-init if needed in this isolate
        await PushNotificationService.instance
            .handleNotificationAction(response.actionId!, data);
      }
    } catch (e) {
      debugPrint('❌ [BackgroundAction] Error: $e');
    }
  }
}

final localNotificationServiceProvider =
    Provider<LocalNotificationService>((ref) {
  return LocalNotificationService.instance;
});
