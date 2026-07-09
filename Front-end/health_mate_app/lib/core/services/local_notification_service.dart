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
  static const String actionMeasureNow = 'MEASURE_NOW';
  static const String actionCallAccept = 'CALL_ACCEPT';
  static const String actionCallDecline = 'CALL_DECLINE';
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
    await _requestAndroidNotificationPermissions();

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

  Future<void> _requestAndroidNotificationPermissions() async {
    try {
      final androidPlugin =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      final notificationGranted =
          await androidPlugin?.requestNotificationsPermission();
      debugPrint(
          '[LocalNotificationService] Android notification permission: $notificationGranted');

      final fullScreenGranted =
          await androidPlugin?.requestFullScreenIntentPermission();
      debugPrint(
          '[LocalNotificationService] Android full-screen permission: $fullScreenGranted');
    } catch (e) {
      debugPrint(
          '[LocalNotificationService] Could not request Android notification permissions: $e');
    }
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
        final data = Map<String, dynamic>.from(jsonDecode(response.payload!));
        if (response.actionId == actionCallAccept ||
            response.actionId == actionCallDecline) {
          PushNotificationService.instance.handleIncomingCallAction(
            response.actionId!,
            data,
          );
        } else if (data['type'] == 'bp_reminder') {
          // BP reminder actions/tap are handled separately from medication
          // ones -- no medication list to parse, no hardware/cloud calls.
          if (response.actionId == actionSnooze ||
              response.actionId == actionMeasureNow) {
            instance.cancelAllAlarms();
            PushNotificationService.instance
                .handleBpReminderAction(response.actionId!, data);
          } else {
            PushNotificationService.instance.handleNotificationTap(data);
          }
        } else if (response.actionId == actionTaken) {
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
          // showsUserInterface MUST be true: false routes the tap through a
          // separate background isolate where `navigatorKey` is always null
          // (isolates don't share globals), so the alarm screen can never be
          // dismissed/updated and, on some devices, secure-storage/network
          // calls made from that isolate silently fail. Launching the app
          // reuses the same reliable main-isolate path as tapping the
          // notification body.
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSnooze,
          translator.translate(LocaleKeys.medicationsSnoozeAction),
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
  }

  /// BP reminders now ring like a real alarm -- `ongoing` + FLAG_INSISTENT +
  /// Snooze/Measure Now actions, matching [_buildAndroidAlarmDetails] for
  /// medications, so tapping or the full-screen intent opens
  /// `BPReminderAlarmPage` (ring/vibrate/snooze/dismiss) instead of a plain
  /// dismissible notification.
  AndroidNotificationDetails _buildAndroidBpReminderDetails() {
    final translator = BackgroundTranslationService.instance;

    return AndroidNotificationDetails(
      'bp_reminders_v2',
      'Blood Pressure Reminders',
      channelDescription: 'Reminders to take a scheduled blood pressure measurement',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      styleInformation: const BigTextStyleInformation(''),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      autoCancel: false,
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT
      actions: [
        AndroidNotificationAction(
          actionMeasureNow,
          translator.translate(LocaleKeys.vitalsBpMeasureNow),
          titleColor: AppColors.expertTeal,
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionSnooze,
          translator.translate(LocaleKeys.medicationsSnoozeAction),
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
  }

  /// Distinct ID from the medication alarm (100) / snooze reminder so a BP
  /// reminder never overwrites or gets cancelled by medication alarm logic.
  static const int bpReminderId = 200;

  Future<void> showBpReminder({
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) await init();

    await _plugin.show(
      bpReminderId,
      title,
      body,
      NotificationDetails(
        android: _buildAndroidBpReminderDetails(),
        iOS: _iOSDetails,
      ),
      payload: payload,
    );
  }

  Future<void> showGenericAlert({
    required int id,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) await init();

    const androidDetails = AndroidNotificationDetails(
      'health_alerts',
      'Health Alerts',
      channelDescription: 'Important Health Mate alerts',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.status,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(''),
    );

    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: _iOSDetails,
      ),
      payload: payload,
    );
  }

  AndroidNotificationDetails _buildAndroidIncomingCallDetails() {
    final translator = BackgroundTranslationService.instance;

    return AndroidNotificationDetails(
      // Bumped from 'incoming_calls' -- Android locks a channel's sound in
      // at first creation, so devices that already created the old channel
      // (with the default notification tone) would never pick up the real
      // ringtone below without a new channel id forcing recreation.
      'incoming_calls_v2',
      'Incoming Calls',
      channelDescription: 'Incoming audio and video calls',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      ongoing: true,
      autoCancel: false,
      category: AndroidNotificationCategory.call,
      visibility: NotificationVisibility.public,
      styleInformation: const BigTextStyleInformation(''),
      sound: const UriAndroidNotificationSound(
          'content://settings/system/ringtone'),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      additionalFlags: Int32List.fromList([4]), // FLAG_INSISTENT: loop until answered
      actions: [
        AndroidNotificationAction(
          actionCallDecline,
          translator.translate(LocaleKeys.communicationDecline),
          titleColor: AppColors.error,
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          actionCallAccept,
          translator.translate(LocaleKeys.communicationAccept),
          titleColor: AppColors.success,
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ],
    );
  }

  static int incomingCallNotificationId(String callId) {
    return callId.hashCode & 0x7fffffff;
  }

  Future<void> showIncomingCall({
    required String callId,
    required String title,
    required String body,
    required String payload,
  }) async {
    if (!_initialized) await init();
    await BackgroundTranslationService.instance.refreshLocale();

    await _plugin.show(
      incomingCallNotificationId(callId),
      title,
      body,
      NotificationDetails(
        android: _buildAndroidIncomingCallDetails(),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: 'INCOMING_CALL',
        ),
      ),
      payload: payload,
    );
  }

  Future<void> cancelIncomingCall(String callId) async {
    if (!_initialized) await init();
    await _plugin.cancel(incomingCallNotificationId(callId));
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
      final data = Map<String, dynamic>.from(jsonDecode(response.payload!));

      if (response.actionId == LocalNotificationService.actionCallAccept ||
          response.actionId == LocalNotificationService.actionCallDecline) {
        await PushNotificationService.instance.handleIncomingCallAction(
          response.actionId!,
          data,
        );
      } else if (data['type'] == 'bp_reminder') {
        if (response.actionId == LocalNotificationService.actionSnooze ||
            response.actionId == LocalNotificationService.actionMeasureNow) {
          await PushNotificationService.instance
              .handleBpReminderAction(response.actionId!, data);
        } else {
          PushNotificationService.instance.handleNotificationTap(data);
        }
      } else if (response.actionId == LocalNotificationService.actionTaken ||
          response.actionId == LocalNotificationService.actionSnooze) {
        // We use the singleton instance which will re-init if needed in this isolate
        await PushNotificationService.instance
            .handleNotificationAction(response.actionId!, data);
      } else {
        // Plain tap on the notification body (no action button). This was
        // previously a no-op here -- the app would launch/resume via the OS
        // but nothing ever navigated to the alarm screen, so it silently
        // landed on whatever page was last shown instead.
        PushNotificationService.instance.handleNotificationTap(data);
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
