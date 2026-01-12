/// App Constants
/// General application constants

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Health Mate';
  static const String appNameArabic = 'رفيقك الصحي';
  static const String appVersion = '1.0.0';

  // Supported Languages
  static const String englishCode = 'en';
  static const String arabicCode = 'ar';
  static const List<String> supportedLanguages = [englishCode, arabicCode];

  // Cache Keys
  static const String cacheKeyToken = 'access_token';
  static const String cacheKeyRefreshToken = 'refresh_token';
  static const String cacheKeyUser = 'user';
  static const String cacheKeyLanguage = 'language';
  static const String cacheKeyThemeMode = 'theme_mode';
  static const String cacheKeyLatestBP = 'latest_bp';
  static const String cacheKeyBPHistory = 'bp_history';
  static const String cacheKeyMedications = 'medications';

  // Hive Box Names
  static const String hiveBoxUser = 'user_box';
  static const String hiveBoxVitals = 'vitals_box';
  static const String hiveBoxMedications = 'medications_box';
  static const String hiveBoxNotifications = 'notifications_box';

  // BP Risk Levels
  static const String riskNormal = 'normal';
  static const String riskLow = 'low';
  static const String riskModerate = 'moderate';
  static const String riskHigh = 'high';
  static const String riskCritical = 'critical';

  // User Roles
  static const String rolePatient = 'patient';
  static const String roleCaregiver = 'caregiver';

  // Validation
  static const int passwordMinLength = 8;
  static const int phoneMinLength = 10;
  static const int maxImageSize = 10 * 1024 * 1024; // 10MB

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Refresh Intervals (milliseconds)
  static const int refreshIntervalVitals = 30000; // 30 seconds
  static const int refreshIntervalNotifications = 60000; // 1 minute

  // Animation Durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}

class AssetsConstants {
  AssetsConstants._();

  static const String _imagesPath = 'assets/images';

  static const String splashLogo = '$_imagesPath/splash_logo.svg';
}
