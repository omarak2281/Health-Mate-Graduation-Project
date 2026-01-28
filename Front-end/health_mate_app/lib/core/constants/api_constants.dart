/// API Constants
/// NO HARDCODED VALUES - use environment variables for different environments

import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  // Base URLs
  static String get devBaseUrl {
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    if (Platform.isAndroid) {
      // 192.168.1.6 is your PC's local IP (detected via ipconfig)
      // Use 10.0.2.2 if you are using an Android Emulator
      // return 'http://10.0.2.2:8000/api/v1'; // Uncomment for Emulator
      return 'http://192.168.1.14:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static const String prodBaseUrl =
      'https://api.healthmate.com/api/v1'; // TODO: Update with real production URL when available

  // Get base URL based on environment
  static String get baseUrl {
    const environment = String.fromEnvironment('ENV', defaultValue: 'dev');
    return environment == 'prod' ? prodBaseUrl : devBaseUrl;
  }

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
  static const String deleteAccount = '$users/me';

  static const String vitals = '/vitals';
  static const String bpCreate = '$vitals/bp';
  static const String bpCurrent = '$vitals/bp/current';
  static const String bpHistory = '$vitals/bp/history';
  static const String bpStats = '$vitals/bp/stats';
  static String patientBPCurrent(String patientId) =>
      '$vitals/patient/$patientId/current';
  static String patientBPHistory(String patientId) =>
      '$vitals/patient/$patientId/history';

  static const String medications = '/medications';
  static String medication(String id) => '$medications/$id';
  static String medicationConfirm(String id) => '$medications/$id/confirm';
  static String patientMedications(String patientId) =>
      '$medications/patient/$patientId';

  static const String iot = '/iot';
  static const String sensorsStatus = '$iot/sensors/status';
  static const String sensorsData = '$iot/sensors/data';
  static const String medicineBoxStatus = '$iot/medicine-box/status';
  static const String medicineBoxDrawers = '$iot/medicine-box/drawers';
  static String drawerActivate(int num) =>
      '$iot/medicine-box/drawer/$num/activate';
  static String drawerDeactivate(int num) =>
      '$iot/medicine-box/drawer/$num/deactivate';

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

  static const String ai = '/ai';
  static const String aiSymptomCheck = '$ai/symptom-checker';
  static const String availableSymptoms = '$ai/available-symptoms';
  static const String aiModelInfo = '$ai/model-info';
  static String aiChatHistory(String sessionId) =>
      '$aiSymptomCheck/history/$sessionId';

  // Timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
}
