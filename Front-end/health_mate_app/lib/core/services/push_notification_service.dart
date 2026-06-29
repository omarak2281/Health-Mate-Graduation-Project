import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../features/medications/presentation/pages/medication_alarm_page.dart';
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
      '🔌 [FCM Background] Hardware notice received for drawers: $message.data');

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

    if (_isMedicationMessage(message)) {
      // ✅ Show a high-priority heads-up banner with actions.
      _showLocalNotification(message);

      // 🚫 BACKEND AUTHORITY: We NO LONGER trigger hardware directly from the mobile app.
      // The backend handles everything to stay in sync.
      debugPrint('🔌 [FCM Foreground] Hardware notice received.');
    }
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

  /// Called when the user taps a notification and the app reopens from background.
  void _handleMessageOpenedApp(RemoteMessage message) {
    debugPrint('📩 [FCM Tapped from bg] Navigating to alarm...');
    _navigateToAlarm(message);
  }

  /// Navigate to [MedicationAlarmPage] using the global [navigatorKey].
  void _navigateToAlarm(RemoteMessage message) {
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
    try {
      final medications = _parseMedicationsFromData(data);
      if (medications.isNotEmpty) {
        _pushAlarmPageSafely(medications);
      }
    } catch (e) {
      debugPrint('❌ Error navigating from local notification tap: $e');
    }
  }

  void _pushAlarmPageSafely(List<Medication> medications,
      {bool initialSnooze = false}) {
    void tryPush(int attempts) {
      if (navigatorKey.currentState != null) {
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
      final medId = data['id'];
      if (medId != null) {
        _markAsTaken(dio, token, medId);
      }
    }
  }

  void _silenceHardware(Dio dio, String? token) {
    dio
        .post(
          '${ApiConstants.baseUrl}${ApiConstants.iotDeactivateAll}',
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        )
        .catchError(
            (e) => debugPrint('⚠️ Hardware silence background error: $e'));
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
