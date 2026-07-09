/// API Constants
/// NO HARDCODED VALUES - use environment variables for different environments

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Base URLs
  static String get devBaseUrl {
    // Use --dart-define=BASE_URL=http://your-ip:8000/api/v1 during build
    const baseUrl = String.fromEnvironment('BASE_URL');
    if (baseUrl.isNotEmpty) return baseUrl;

    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    if (Platform.isAndroid) {
      // Clean string to ensure no hidden spaces are present
      return 'http://10.229.183.149:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static const String prodBaseUrl =
      'https://api.healthmate.com/api/v1'; // Update with real production URL when available

  // Get base URL based on environment
  static String get baseUrl {
    const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
    return environment == 'prod' ? prodBaseUrl : devBaseUrl;
  }

  static const bool symptomCheckerV2Enabled = bool.fromEnvironment(
    'SYMPTOM_CHECKER_V2_ENABLED',
    defaultValue: true,
  );

  // Endpoints
  static const String auth = '/auth';
  static const String login = '$auth/login';
  static const String googleLogin = '$auth/social';
  static const String register = '$auth/register';
  static const String refreshToken = '$auth/refresh';
  static const String logout = '$auth/logout';

  static const String users = '/users';
  static const String userProfile = '$users/me';
  static const String userLinked = '$users/linked';
  static String userLink(String userId) => '$users/link/$userId';
  static String userUnlink(String userId) => '$userLinked/$userId';
  static const String userPassword = '$users/me/password';
  static const String userFcmToken = '$users/me/fcm-token';
  static const String deleteAccount = '$users/me';

  static const String vitals = '/vitals';
  static const String bpCreate = '$vitals/bp';
  static const String bpSubmit = '$vitals/bp/submit';
  static const String bpComplete = '$vitals/bp/complete';
  static const String bpCurrent = '$vitals/bp/current';
  static const String bpHistory = '$vitals/bp/history';
  static const String bpStats = '$vitals/bp/stats';
  static const String bpCalibrationStatus = '$vitals/bp/calibration/status';
  static String patientBPCurrent(String patientId) =>
      '$vitals/patient/$patientId/current';
  static String patientBPHistory(String patientId) =>
      '$vitals/patient/$patientId/history';

  static const String bpReminders = '/bp/reminders';
  static const String bpRemindersScheduleDaily =
      '$bpReminders/schedule-daily';

  static const String medications = '/medications';
  static const String medicationsTaken = '$medications/taken';
  static const String medicationsSnooze = '$medications/snooze';
  static String medication(String id) => '$medications/$id';
  static String medicationConfirm(String id) => '$medications/$id/confirm';
  static String patientMedications(String patientId) =>
      '$medications/patient/$patientId';

  static const String iot = '/iot';
  static const String sensorsStatus = '$iot/sensors/status';
  static const String sensorsData = '$iot/sensors/data';
  static const String medicineBoxStatus = '$iot/medicine-box/status';
  static const String medicineBoxDrawers = '$iot/medicine-box/drawers';
  static const String iotDeactivateAll = '$iot/medicine-box/deactivate-all';
  static String drawerActivate(int num) =>
      '$iot/medicine-box/drawer/$num/activate';
  static String drawerDeactivate(int num) =>
      '$iot/medicine-box/drawer/$num/deactivate';

  static const String hardware = '/hardware';
  static const String hardwareStatus = '$hardware/status';

  static const String contacts = '/contacts';
  static String contact(String id) => '$contacts/$id';

  static const String upload = '/upload';
  static const String uploadImage = '$upload/image';
  static const String uploadProfilePicture = '$upload/profile-picture';
  static const String uploadMedicationImage = '$upload/medication-image';

  static const String notifications = '/notifications';
  static const String notificationUnreadCount = '$notifications/unread-count';
  static const String notificationMarkRead = '$notifications/mark-read';
  static String notificationRead(String id) => '$notifications/$id/read';

  static const String calls = '/calls';
  static String call(String id) => '$calls/$id';
  static String callOffer(String id) => '$calls/$id/offer';
  static String callAccept(String id) => '$calls/$id/accept';
  static String callReject(String id) => '$calls/$id/reject';
  static String callBusy(String id) => '$calls/$id/busy';
  static String callEnd(String id) => '$calls/$id/end';

  static const String ai = '/ai';
  static const String aiSymptomCheck = '$ai/symptom-checker';
  static const String aiChat = '$ai/chat';
  static const String aiSymptomAnalyze = '$ai/symptom-checker/analyze';
  static const String availableSymptoms = '$ai/available-symptoms';
  static const String aiModelInfo = '$ai/model-info';
  static const String aiCategories = '$ai/categories';
  static const String aiTaxonomySymptoms = '$ai/taxonomy/symptoms';
  static const String aiAssessment = '$ai/assessment';
  static const String aiBpTriage = '$ai/bp-triage';
  static const String aiChatFromAssessment = '$ai/chat/from-assessment';
  static const String aiAssessmentNotifyCaregiver =
      '$ai/assessment/notify-caregiver';
  static String aiChatHistory(String sessionId) =>
      '$aiSymptomCheck/history/$sessionId';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
