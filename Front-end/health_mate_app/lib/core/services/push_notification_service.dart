import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../features/medications/presentation/pages/medication_alarm_page.dart';
import '../../features/communication/presentation/pages/call_page.dart';
import '../../features/communication/presentation/pages/emergency_call_action_page.dart';
import '../../features/communication/presentation/pages/incoming_call_page.dart';
import '../../features/vitals/presentation/pages/bp_reminder_alarm_page.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/medication.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/constants/app_constants.dart';
import 'local_notification_service.dart';
import '../../core/constants/locale_keys.dart';
import 'background_translation_service.dart';

/// Top-level background message handler.
/// MUST be a top-level function annotated with @pragma('vm:entry-point').
/// Called by Firebase when a message arrives while the app is in the
/// background or terminated state. Cannot access Flutter widgets.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  debugPrint('📥 [FCM Background] Received: ${message.messageId}');

  await LocalNotificationService.instance.init();
  await BackgroundTranslationService.instance.init();

  final translator = BackgroundTranslationService.instance;

  if (message.data['type'] == 'bp_reminder') {
    final title = translator.translate(LocaleKeys.vitalsBpReminderTitle);
    final body = translator.translate(LocaleKeys.vitalsBpReminderBody);
    debugPrint('🔔 [FCM Background] Showing BP reminder: $title - $body');
    await LocalNotificationService.instance.showBpReminder(
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
    return;
  }

  if (PushNotificationService.instance._isIncomingCallData(message.data)) {
    await PushNotificationService.instance.showIncomingCallAlert(message.data);
    return;
  }

  // Try to determine the name of the medicine for the body
  String? medName;
  try {
    if (message.data['type'] == 'single') {
      final medData = message.data['medicine'];
      final Map? medMap =
          medData is String ? jsonDecode(medData) : medData as Map?;
      medName = medMap?['name'] as String?;
    }
  } catch (e) {
    debugPrint('⚠️ Error parsing med name in background: $e');
  }

  // ALWAYS override with local translations because FCM might send raw keys
  // if the backend isn't supporting the client's language perfectly.
  String title = translator.translate(LocaleKeys.medicationsAlarmTitle);

  String body = (medName != null
      ? translator.translate(LocaleKeys.medicationsTimeToTake,
          namedArgs: {'name': medName})
      : translator.translate(LocaleKeys.medicationsTimeToTakeMeds));

  debugPrint('🔔 [FCM Background] Showing notification: $title - $body');
  debugPrint('🔔 [FCM Background] FullScreenIntent: true, Importance: MAX');

  // 🚫 BACKEND AUTHORITY: We NO LONGER trigger hardware directly from the mobile app
  // background handler. The backend handles hardware activation/deactivation
  // to ensure synchronization with the cloud-based snooze/taken logic.
  debugPrint(
      '🔌 [FCM Background] Hardware notice received for drawers: ${message.data}');

  await LocalNotificationService.instance.showMedicationAlarm(
    id: 100,
    title: title,
    body: body,
    payload: jsonEncode(message.data),
  );
}

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  static final PushNotificationService instance = PushNotificationService._();
  PushNotificationService._();

  /// True while [MedicationAlarmPage] or [BPReminderAlarmPage] is pushed
  /// on top of the navigator (via a tapped/full-screen-intent reminder).
  /// SplashPage's timer-driven navigation checks this before calling
  /// `pushReplacement`, so it doesn't blindly clobber a currently-showing
  /// reminder screen with the home page (see `_pushAlarmPageSafely` and
  /// `notifyAlarmScreenClosed`).
  bool isAlarmScreenActive = false;
  final Set<String> _activeIncomingCallIds = <String>{};
  String? _navigatedCallId;

  /// Call from [MedicationAlarmPage.dispose] so the splash race guard is
  /// released once the alarm screen is gone.
  void notifyAlarmScreenClosed() {
    isAlarmScreenActive = false;
  }

  Future<void> showIncomingCallAlert(Map<String, dynamic> data) async {
    final callId = _callIdFromData(data);
    if (callId.isEmpty || !_activeIncomingCallIds.add(callId)) return;

    final translator = BackgroundTranslationService.instance;
    await translator.init();
    await translator.refreshLocale();

    final isVideo = data['call_type']?.toString() == 'video' ||
        data['callType']?.toString() == 'video' ||
        data['isVideo'] == true ||
        data['isVideo']?.toString() == 'true';
    final title = translator.translate(
      isVideo
          ? LocaleKeys.communicationIncomingVideoCall
          : LocaleKeys.communicationIncomingAudioCall,
    );
    final callerName = _callerNameFromData(data);

    await LocalNotificationService.instance.showIncomingCall(
      callId: callId,
      title: title,
      body: callerName,
      payload: jsonEncode(data),
    );

    // Don't make the callee hunt for the notification banner to see who's
    // calling -- if the app has a live navigator (foreground or just
    // backgrounded), jump straight to the ringing screen. The notification
    // stays posted regardless, since it's what actually plays the ring.
    _pushIncomingCallPageSafely(data);

    Future.delayed(const Duration(seconds: 45), () {
      _activeIncomingCallIds.remove(callId);
      if (_navigatedCallId == callId) _navigatedCallId = null;
    });
  }

  Future<void> handleIncomingCallAction(
    String action,
    Map<String, dynamic> data,
  ) async {
    final callId = _callIdFromData(data);
    if (callId.isNotEmpty) {
      _activeIncomingCallIds.remove(callId);
      if (_navigatedCallId == callId) _navigatedCallId = null;
      await LocalNotificationService.instance.cancelIncomingCall(callId);
    }

    if (action == LocalNotificationService.actionCallDecline) {
      await _rejectIncomingCall(data);
      return;
    }

    if (action == LocalNotificationService.actionCallAccept) {
      _pushAnswerCallPageSafely(data);
    }
  }

  // ─── Public API ───────────────────────────────────────────────────────────

  Future<void> init() async {
    // 1. Request permissions
    try {
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('⚠️ FCM permission error: $e');
    }

    // 2. Register background handler (must also be called in main() before
    //    Firebase.initializeApp — this call here is a safety net)
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // 3. Listen for foreground messages → show banner + navigate
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 4. Handle notification tap from background state
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // 5. Handle notification tap from terminated state
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(milliseconds: 600), () {
        _handleMessageOpenedApp(initialMessage);
      });
    }

    // 6. Listen for token refresh and sync with backend
    _fcm.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed, syncing with backend...');
      _sendTokenToBackend(newToken);
    });

    // 7. Initial sync of token (if already logged in)
    _fcm.getToken().then((token) {
      if (token != null) _sendTokenToBackend(token);
    });
  }

  /// Call this right after a successful login so the backend has the current token.
  Future<void> registerTokenAfterLogin(Dio dio) async {
    try {
      final token = await _fcm.getToken();
      if (token == null) {
        debugPrint('⚠️ FCM Token is null — skipping registration');
        return;
      }
      debugPrint('📱 Registering FCM Token with backend...');
      await dio.put(
        ApiConstants.userFcmToken,
        data: {'fcm_token': token},
      );
      debugPrint('✅ FCM Token registered successfully');
    } catch (e) {
      // Non-critical — notifications may be delayed until next login, but
      // we must not crash the login flow.
      debugPrint('⚠️ Failed to register FCM Token: $e');
    }
  }

  // ─── Private helpers ──────────────────────────────────────────────────────

  Future<void> _sendTokenToBackend(String token) async {
    // This is called during token-refresh, before Dio is available via Riverpod.
    // We use a plain http/Dio instance as a fire-and-forget.
    try {
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        headers: {'Content-Type': 'application/json'},
      ));
      final storage = await _readAccessTokenFromSecureStorage();
      if (storage != null) {
        dio.options.headers['Authorization'] = 'Bearer $storage';
      }
      await dio.put(
        ApiConstants.userFcmToken,
        data: {'fcm_token': token},
      );
      debugPrint('✅ FCM Token refreshed and synced with backend');
    } catch (e) {
      debugPrint('⚠️ Failed to sync refreshed FCM token: $e');
    }
  }

  /// Read the access token from secure storage without Riverpod.
  Future<String?> _readAccessTokenFromSecureStorage() async {
    try {
      // Lazy import to avoid circular dependency
      final secureStorage = await _getSecureStorageToken();
      return secureStorage;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _getSecureStorageToken() async {
    try {
      // Use flutter_secure_storage directly to avoid Riverpod coupling
      // during background FCM token refresh events.
      const storage = FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );
      return await storage.read(key: AppConstants.cacheKeyToken);
    } catch (e) {
      debugPrint('⚠️ Error reading token in background: $e');
      return null;
    }
  }

  /// Called when the app is in the FOREGROUND and a message arrives.
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📩 [FCM Foreground] type=${message.data['type']}');

    if (message.data['type'] == 'bp_reminder') {
      // Showing only a passive tray notification here (like the medication
      // branch below does) meant the alarm screen never appeared unless the
      // patient noticed and tapped that banner -- if they were already using
      // the app, the reminder silently did nothing but ring/vibrate via the
      // notification channel, then left them on whatever page they were on.
      // Push the ringing alarm screen immediately instead of waiting for a tap.
      _showBpReminderLocalNotification(message);
      _pushBpReminderPageSafely();
      return;
    }

    if (_isIncomingCallMessage(message)) {
      showIncomingCallAlert(message.data);
      return;
    }

    if (_isEmergencyBpMessage(message)) {
      _showGenericAlertNotification(message);
      return;
    }

    if (_isMedicationMessage(message)) {
      // ✅ Show a high-priority heads-up banner with actions.
      _showLocalNotification(message);

      // 🚫 BACKEND AUTHORITY: We NO LONGER trigger hardware directly from the mobile app.
      // The backend handles everything to stay in sync.
      debugPrint('🔌 [FCM Foreground] Hardware notice received.');
    }
  }

  Future<void> _showBpReminderLocalNotification(RemoteMessage message) async {
    final translator = BackgroundTranslationService.instance;
    await translator.init();

    await LocalNotificationService.instance.showBpReminder(
      title: translator.translate(LocaleKeys.vitalsBpReminderTitle),
      body: translator.translate(LocaleKeys.vitalsBpReminderBody),
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final translator = BackgroundTranslationService.instance;
    await translator.init();

    String? medName;
    try {
      if (message.data['type'] == 'single') {
        final medMap = message.data['medicine'] is String
            ? jsonDecode(message.data['medicine'])
            : message.data['medicine'];
        medName = medMap['name'];
      }
    } catch (_) {}

    final title = translator.translate(LocaleKeys.medicationsAlarmTitle);
    final body = medName != null
        ? translator.translate(LocaleKeys.medicationsTimeToTake,
            namedArgs: {'name': medName})
        : translator.translate(LocaleKeys.medicationsTimeToTakeMeds);

    await LocalNotificationService.instance.showMedicationAlarm(
      id: 100,
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
  }

  Future<void> _showGenericAlertNotification(RemoteMessage message) async {
    final title = message.notification?.title ??
        message.data['title']?.toString() ??
        'Health Mate';
    final body = message.notification?.body ??
        message.data['body']?.toString() ??
        message.data['message']?.toString() ??
        '';

    await LocalNotificationService.instance.showGenericAlert(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: jsonEncode(message.data),
    );
  }

  /// Called when the user taps a notification and the app reopens from background.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📩 [FCM Tapped from bg] Navigating to alarm...');
    _navigateToAlarm(message);
  }

  /// Navigate to [MedicationAlarmPage] (or [BPReminderAlarmPage] for a BP
  /// reminder) using the global [navigatorKey].
  void _navigateToAlarm(RemoteMessage message) {
    if (message.data['type'] == 'bp_reminder') {
      _pushBpReminderPageSafely();
      return;
    }
    if (_isEmergencyBpMessage(message)) {
      _pushEmergencyActionPageSafely(message.data);
      return;
    }
    if (_isIncomingCallMessage(message)) {
      _pushIncomingCallPageSafely(message.data);
      return;
    }
    try {
      final medications = _parseMedicationsFromData(message.data);
      if (medications.isNotEmpty) {
        _pushAlarmPageSafely(medications);
      }
    } catch (e) {
      debugPrint('❌ Error navigating to alarm: $e');
    }
  }

  /// Navigate to alarm when the user taps a LOCAL notification.
  void handleNotificationTap(Map<String, dynamic> data) async {
    // 🛑 STOP the notification sound immediately on tap
    await LocalNotificationService.instance.cancelAllAlarms();

    debugPrint('👆 [Notification] User tapped alarm notification');
    if (data['type'] == 'test') {
      debugPrint('🧪 Test notification tapped!');
      return;
    }
    if (data['type'] == 'bp_reminder') {
      _pushBpReminderPageSafely();
      return;
    }
    if (_isEmergencyBpData(data)) {
      _pushEmergencyActionPageSafely(data);
      return;
    }
    if (_isIncomingCallData(data)) {
      _pushIncomingCallPageSafely(data);
      return;
    }
    try {
      debugPrint('👆 [Notification] Raw tap payload: $data');
      final medications = _parseMedicationsFromData(data);
      debugPrint('👆 [Notification] Parsed ${medications.length} medication(s) from tap payload');
      if (medications.isNotEmpty) {
        _pushAlarmPageSafely(medications);
      } else {
        debugPrint('⚠️ [Notification] No medications parsed -- alarm screen will NOT open');
      }
    } catch (e) {
      debugPrint('❌ Error navigating from local notification tap: $e');
    }
  }

  /// Same splash-race protection as [_pushAlarmPageSafely] (see
  /// `isAlarmScreenActive`), reused here so a BP reminder tapped from a
  /// cold start doesn't get clobbered by SplashPage's timer navigation.
  ///
  /// Pushes the ringing [BPReminderAlarmPage] (snooze/measure-now), matching
  /// the medication alarm's UX, instead of jumping straight into the
  /// measurement walkthrough.
  void _pushBpReminderPageSafely({bool initialSnooze = false}) {
    void tryPush(int attempts) {
      if (navigatorKey.currentState != null) {
        isAlarmScreenActive = true;
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => BPReminderAlarmPage(initialSnooze: initialSnooze),
            fullscreenDialog: true,
          ),
          (route) => route.isFirst,
        );
      } else if (attempts < 20) {
        Future.delayed(
            const Duration(milliseconds: 100), () => tryPush(attempts + 1));
      }
    }

    tryPush(0);
  }

  /// Public entry point so [BPReminderAlarmNotifier]'s snooze countdown can
  /// bring the alarm screen back up once the snooze expires, mirroring
  /// [pushAlarmPage] for medications.
  void pushBpReminderAlarmPage({bool initialSnooze = false}) {
    _pushBpReminderPageSafely(initialSnooze: initialSnooze);
  }

  /// Handles the BP reminder's notification-tray action buttons (Snooze /
  /// Measure Now), mirroring [handleNotificationAction] for medications but
  /// without any hardware/cloud-snooze calls -- BP reminders have neither.
  Future<void> handleBpReminderAction(
      String action, Map<String, dynamic> data) async {
    await LocalNotificationService.instance.cancelAllAlarms();

    if (action == LocalNotificationService.actionSnooze) {
      _pushBpReminderPageSafely(initialSnooze: true);
    } else if (action == LocalNotificationService.actionMeasureNow) {
      _pushBpReminderPageSafely();
    }
  }

  /// Public entry point so non-notification callers (e.g. the snooze
  /// countdown timer in [MedicationAlarmNotifier] once the snooze expires)
  /// can bring the alarm screen back up. `bringToForeground` alone only
  /// raises whatever screen is currently on top of the stack -- it does not
  /// push [MedicationAlarmPage], since the widget that used to listen for
  /// "snooze expired" was already popped when the user snoozed.
  void pushAlarmPage(List<Medication> medications,
      {bool initialSnooze = false}) {
    if (medications.isEmpty) return;
    _pushAlarmPageSafely(medications, initialSnooze: initialSnooze);
  }

  void _pushAlarmPageSafely(List<Medication> medications,
      {bool initialSnooze = false}) {
    void tryPush(int attempts) {
      if (navigatorKey.currentState != null) {
        isAlarmScreenActive = true;
        debugPrint('✅ [AlarmPage] Pushing MedicationAlarmPage (attempt $attempts)');
        // Clear existing alarm if any and push new one
        navigatorKey.currentState!.pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => MedicationAlarmPage(
              medications: medications,
              initialSnooze: initialSnooze,
            ),
            fullscreenDialog: true,
          ),
          (route) => route.isFirst,
        );
      } else if (attempts < 20) {
        Future.delayed(
            const Duration(milliseconds: 100), () => tryPush(attempts + 1));
      } else {
        debugPrint('❌ [AlarmPage] Gave up after 20 attempts -- navigatorKey.currentState was never ready');
      }
    }

    tryPush(0);
  }

  bool _isMedicationMessage(RemoteMessage message) {
    final type = message.data['type'];
    return type == 'single' ||
        type == 'grouped' ||
        type == 'medication_reminder' ||
        message.notification != null;
  }

  bool _isEmergencyBpMessage(RemoteMessage message) =>
      _isEmergencyBpData(message.data);

  bool _isIncomingCallMessage(RemoteMessage message) =>
      _isIncomingCallData(message.data);

  bool _isEmergencyBpData(Map<String, dynamic> data) {
    final type = (data['notification_type'] ?? data['type'] ?? '').toString();
    return type == 'emergency_bp_alert' || type == 'EMERGENCY_BP_ALERT';
  }

  bool _isIncomingCallData(Map<String, dynamic> data) {
    final type = (data['notification_type'] ?? data['type'] ?? '').toString();
    return type == 'incoming_call' || type == 'INCOMING_CALL';
  }

  void _pushEmergencyActionPageSafely(Map<String, dynamic> data) {
    void tryPush(int attempts) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => EmergencyCallActionPage(
              patientId: data['patient_id']?.toString() ?? '',
              patientName: data['patient_name']?.toString() ??
                  BackgroundTranslationService.instance
                      .translate(LocaleKeys.authPatient),
              phone: data['phone']?.toString() ?? '',
              riskLevel: data['risk_level']?.toString() ?? '',
              systolic: data['systolic']?.toString() ?? '',
              diastolic: data['diastolic']?.toString() ?? '',
            ),
          ),
        );
      } else if (attempts < 20) {
        Future.delayed(
            const Duration(milliseconds: 100), () => tryPush(attempts + 1));
      }
    }

    tryPush(0);
  }

  String _callIdFromData(Map<String, dynamic> data) {
    return data['session_id']?.toString() ??
        data['sessionId']?.toString() ??
        data['call_id']?.toString() ??
        data['callId']?.toString() ??
        '';
  }

  String _callerIdFromData(Map<String, dynamic> data) {
    return data['caller_id']?.toString() ??
        data['callerId']?.toString() ??
        '';
  }

  String _callerNameFromData(Map<String, dynamic> data) {
    final name =
        data['caller_name']?.toString() ?? data['callerName']?.toString() ?? '';
    if (name.trim().isNotEmpty) return name;
    return BackgroundTranslationService.instance
        .translate(LocaleKeys.communicationContact);
  }

  String? _callerImageFromData(Map<String, dynamic> data) {
    final image = data['caller_avatar']?.toString() ??
        data['callerAvatar']?.toString() ??
        data['callerImage']?.toString() ??
        '';
    return image.trim().isEmpty ? null : image.trim();
  }

  bool _isVideoCallData(Map<String, dynamic> data) {
    return data['call_type']?.toString() == 'video' ||
        data['callType']?.toString() == 'video' ||
        data['isVideo'] == true ||
        data['isVideo']?.toString() == 'true';
  }

  void _pushIncomingCallPageSafely(Map<String, dynamic> data) {
    final callerId = _callerIdFromData(data);
    if (callerId.isEmpty) return;
    final callId = _callIdFromData(data);

    // Both the automatic push-on-offer and a later banner tap for the same
    // call route through here -- without this guard the user could end up
    // with two stacked ringing screens for one call.
    if (callId.isNotEmpty) {
      if (_navigatedCallId == callId) return;
      _navigatedCallId = callId;
    }

    void tryPush(int attempts) {
      if (navigatorKey.currentState != null) {
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => IncomingCallPage(
              callerName: _callerNameFromData(data),
              callerId: callerId,
              callerImage: _callerImageFromData(data),
              isVideo: _isVideoCallData(data),
              callId: callId.isEmpty ? null : callId,
            ),
            fullscreenDialog: true,
          ),
        );
      } else if (attempts < 20) {
        Future.delayed(
            const Duration(milliseconds: 100), () => tryPush(attempts + 1));
      }
    }

    tryPush(0);
  }

  void _pushAnswerCallPageSafely(Map<String, dynamic> data) {
    final callerId = _callerIdFromData(data);
    final callId = _callIdFromData(data);
    if (callerId.isEmpty || callId.isEmpty) return;

    void tryPush(int attempts) async {
      if (navigatorKey.currentState != null) {
        final session = await _fetchCallSession(callId);
        final offerSdp = session?['offer_sdp']?.toString();
        if (offerSdp == null || offerSdp.trim().isEmpty) {
          _pushIncomingCallPageSafely(data);
          return;
        }
        navigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CallPage(
              isVideo: _isVideoCallData(data),
              contactName: _callerNameFromData(data),
              contactImage: _callerImageFromData(data),
              contactId: callerId,
              isCaller: false,
              callId: callId,
              remoteOfferSdp: offerSdp,
              remoteOfferType: 'offer',
            ),
          ),
        );
      } else if (attempts < 20) {
        Future.delayed(
            const Duration(milliseconds: 100), () => tryPush(attempts + 1));
      }
    }

    tryPush(0);
  }

  Future<Map<String, dynamic>?> _fetchCallSession(String callId) async {
    try {
      final token = await _getSecureStorageToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));
      final response = await dio.get(ApiConstants.call(callId));
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('⚠️ Could not fetch call session: $e');
      return null;
    }
  }

  Future<void> _rejectIncomingCall(Map<String, dynamic> data) async {
    final callId = _callIdFromData(data);
    if (callId.isEmpty) return;

    try {
      final token = await _getSecureStorageToken();
      final dio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ));
      await dio.post(ApiConstants.callReject(callId));
    } catch (e) {
      debugPrint('⚠️ Could not reject incoming call: $e');
    }
  }

  /// Parse [List<Medication>] from the FCM data payload.
  List<Medication> _parseMedicationsFromData(Map<String, dynamic> data) {
    final type = data['type'];
    final List<Medication> medications = [];

    try {
      if (type == 'single') {
        final medData = data['medicine'];
        if (medData != null) {
          final Map<String, dynamic> medMap = medData is String
              ? jsonDecode(medData) as Map<String, dynamic>
              : Map<String, dynamic>.from(medData as Map);
          medications.add(Medication.fromJson(medMap));
        }
      } else if (type == 'grouped') {
        final medList = data['medicines'];
        if (medList != null) {
          final List<dynamic> list = medList is String
              ? jsonDecode(medList) as List<dynamic>
              : List<dynamic>.from(medList as List);
          medications.addAll(list.map(
            (m) => Medication.fromJson(Map<String, dynamic>.from(m as Map)),
          ));
        }
      } else {
        // Fallback: try parsing the payload itself as a medication
        medications.add(Medication.fromJson(data));
      }
    } catch (e) {
      debugPrint('⚠️ Could not parse medication from payload: $e');
    }

    return medications;
  }

  Future<void> handleNotificationAction(
      String action, Map<String, dynamic> data) async {
    debugPrint('🔔 Notification action: $action');

    // 0. IMMEDIATE UI FEEDBACK
    await LocalNotificationService.instance.cancelAllAlarms();

    final medications = _parseMedicationsFromData(data);
    final token = await _getSecureStorageToken();
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));

    // 1. SILENCE HARDWARE (Fire and forget to avoid blocking UI)
    _silenceHardware(dio, token);

    if (action == LocalNotificationService.actionSnooze) {
      debugPrint('⏰ [Action] Snoozing...');
      if (medications.isEmpty) return;

      // 2. NAVIGATE IMMEDIATELY
      _pushAlarmPageSafely(medications, initialSnooze: true);

      // 3. CLOUD SNOOZE (Background)
      _requestCloudSnooze(dio, token, medications.map((m) => m.id).toList());
    } else if (action == LocalNotificationService.actionTaken) {
      debugPrint('💊 [Action] Marking as taken...');
      // The FCM/local-notification payload never has a top-level 'id' key
      // (the medicine id is nested under data['medicine']['id'] for a
      // single reminder, or inside each entry of data['medicines'] for a
      // grouped one) -- `data['id']` was always null, so this action never
      // actually confirmed anything. Use the already-parsed `medications`
      // list and confirm each one.
      for (final med in medications) {
        _markAsTaken(dio, token, med.id);
      }
    }
  }

  void _silenceHardware(Dio dio, String? token) {
    dio
        .post(
          '${ApiConstants.baseUrl}${ApiConstants.iotDeactivateAll}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .then<void>((_) {})
        .onError((Object e, StackTrace stackTrace) {
      debugPrint('Hardware silence background error: $e');
    });
  }

  void _requestCloudSnooze(Dio dio, String? token, List<String> medicationIds) {
    dio
        .post(
          '${ApiConstants.baseUrl}${ApiConstants.medicationsSnooze}',
          data: jsonEncode(medicationIds),
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .then((_) => debugPrint('✅ Cloud Snooze background success'))
        .catchError((e) => debugPrint('❌ Cloud Snooze background error: $e'));
  }

  void _markAsTaken(Dio dio, String? token, String medId) {
    dio
        .post(
          '${ApiConstants.baseUrl}${ApiConstants.medicationConfirm(medId)}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .then((_) => debugPrint('✅ Marked taken background success'))
        .catchError((e) => debugPrint('⚠️ Mark taken background error: $e'));
  }
}

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((_) => PushNotificationService.instance);
