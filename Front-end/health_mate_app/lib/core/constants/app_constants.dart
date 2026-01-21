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
  static const String cacheKeyLastRole = 'last_selected_role';

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
  static const String bloodPressure = '$_imagesPath/Blood_Pressure.svg';
  static const String check = '$_imagesPath/Check.svg';
  static const String heartRate = '$_imagesPath/Heart_Rate.svg';
  static const String home = '$_imagesPath/Home.svg';
  static const String language = '$_imagesPath/Language.svg';
  static const String logout = '$_imagesPath/Logout.svg';
  static const String pill = '$_imagesPath/Pill.svg';
  static const String settings = '$_imagesPath/Settings.svg';
  static const String phone = '$_imagesPath/phone.svg';
  static const String doctor = '$_imagesPath/doctor.svg';
  static const String email = '$_imagesPath/email.svg';
  static const String password = '$_imagesPath/password.svg';
  static const String googleLogoUrl =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png';
  static const String ukFlagUrl = 'https://flagcdn.com/w160/gb.png';
  static const String egyptFlagUrl = 'https://flagcdn.com/w160/eg.png';
}
