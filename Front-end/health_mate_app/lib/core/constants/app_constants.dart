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

  // Caregiver Dashboard
  /// Max number of linked patients shown in the Dashboard tab preview section.
  /// Tapping "View All" navigates to the full Patients tab.
  static const int caregiverDashboardPatientPreviewCount = 2;
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
  static const String googleLogo = '$_imagesPath/google_logo.svg';
  static const String googleLogoUrl =
      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png';
  static const String ukFlagUrl = 'https://flagcdn.com/w160/gb.png';
  static const String egyptFlagUrl = 'https://flagcdn.com/w160/eg.png';
}

/// Symptom Checker Constants
class SymptomCheckerConstants {
  SymptomCheckerConstants._();

  // Categories
  static const String categoryHeart = 'Heart';
  static const String categoryGeneral = 'General';

  // Default Sub-categories
  static const String defaultHeartSubCategory = 'Coronary Artery Disease';
  static const String defaultGeneralSubCategory = 'Respiratory Infection';

  // API Response Keys
  static const String keyMapping = 'mapping';
  static const String keyCategories = 'categories';
  static const String keyAllSymptoms = 'all_symptoms';
  static const String keySymptomsData = 'symptoms_data';

  // Default Mappings
  static const Map<String, List<String>> defaultMapping = {
    categoryHeart: ['Coronary Artery Disease', 'Heart Failure'],
    categoryGeneral: ['Respiratory Infection', 'Gastrointestinal'],
  };

  // Steps
  static const List<String> stepLabels = [
    'Specialty',
    'Symptoms',
    'Analysis',
    'Metrics',
  ];

  // Severity Levels
  static const String severityCritical = 'critical';
  static const String severityHigh = 'high';
  static const String severityModerate = 'moderate';
  static const String severityLow = 'low';

  // Severity Emojis
  static const Map<String, String> severityEmojis = {
    severityCritical: '🚨',
    severityHigh: '⚠️',
    severityModerate: '✅',
    severityLow: 'ℹ️',
  };

  // Animation Durations
  static const Duration pageTransitionDuration = Duration(milliseconds: 300);
  static const Duration animationDuration = Duration(milliseconds: 500);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // UI Text Keys (for localization)
  static const String keyClinicalSpecialty = 'Clinical Specialty Selection';
  static const String keySelectSpecialty =
      'Select the clinical area that best matches your symptoms.';
  static const String keyHeartVascular = 'Heart & Vascular';
  static const String keyCardiacSystem = 'Cardiac System';
  static const String keyGeneralMedicine = 'General Medicine';
  static const String keyComprehensive = 'Comprehensive';
  static const String keySymptomAssessment = 'Symptom Assessment';
  static const String keySelectSymptoms =
      'Select your symptoms to generate an assessment.';
  static const String keyRefineCategory = 'Refine category:';
  static const String keySelectSymptomsLabel = 'Select symptoms:';
  static const String keyAnalyzeSymptoms = 'Analyze My Symptoms';
  static const String keyAiAnalysisComplete = 'AI ANALYSIS COMPLETE';
  static const String keyViewModelMetrics = 'View Model Metrics';
  static const String keyNewAssessment = 'New Assessment';
  static const String keyExpertGuidance = 'Expert Health Guidance';

  // Default Accuracy
  static const double defaultAccuracy = 93.5;
  static const double defaultF1Score = 89.5;

  // Error Messages
  static const String errorLoadingData = 'Failed to load symptom data';
  static const String errorUnknown = 'Unknown error occurred';
  static const String errorPleaseTryAgain = 'Please try again';

  // Category Icons Mapping - Based on API response categories
  static const Map<String, String> categoryIcons = {
    'Chest': '💔',
    'Cardiovascular': '❤️',
    'Coronary Artery Disease': '❤️',
    'Heart Failure': '💓',
    'Arrhythmia': '⚡',
    'Valvular Heart Disease': '🔧',
    'Respiratory': '🫁',
    'Neurological': '🧠',
    'Gastrointestinal': '🍽️',
    'Musculoskeletal': '🦴',
    'General': '🏥',
    'Other': '🔍',
    'Emergency': '🚨',
    'Vascular': '🩸',
    'Vascular/Respiratory': '🫁',
    'Hypertension': '📈',
    'Infectious': '🦠',
    'Environmental': '🌍',
    'Psychological': '🧘',
    'Endocrine': '⚗️',
    'Urinary': '💧',
  };

  // Display Names for Categories (English defaults, will be overridden by translations)
  static const Map<String, String> categoryDisplayNames = {
    'Chest': 'Heart & Vascular',
    'Cardiovascular': 'Cardiac System',
    'Coronary Artery Disease': 'Coronary Artery Disease',
    'Heart Failure': 'Heart Failure',
    'Arrhythmia': 'Arrhythmia',
    'Valvular Heart Disease': 'Valvular Disease',
    'Respiratory': 'Respiratory',
    'Neurological': 'Neurological',
    'Gastrointestinal': 'Gastrointestinal',
    'Musculoskeletal': 'Musculoskeletal',
    'General': 'General Medicine',
    'Other': 'Other',
    'Emergency': 'Emergency',
    'Vascular': 'Vascular',
    'Vascular/Respiratory': 'Vascular/Respiratory',
    'Hypertension': 'Hypertension',
    'Infectious': 'Infectious',
    'Environmental': 'Environmental',
    'Psychological': 'Psychological',
    'Endocrine': 'Endocrine',
    'Urinary': 'Urinary',
  };

  // UI Spacing Constants (as percentages)
  static const double paddingSmall = 1.0;
  static const double paddingMedium = 2.0;
  static const double paddingLarge = 3.0;
  static const double paddingXLarge = 4.0;

  static const double spacingSmall = 0.5;
  static const double spacingMedium = 1.0;
  static const double spacingLarge = 1.5;
  static const double spacingXLarge = 2.0;

  // Font Sizes
  static const double fontSizeSmall = 10.0;
  static const double fontSizeMedium = 12.0;
  static const double fontSizeLarge = 14.0;
  static const double fontSizeXLarge = 16.0;
  static const double fontSizeXXLarge = 18.0;
  static const double fontSizeTitle = 20.0;
  static const double fontSizeHeader = 24.0;

  // Border Radius
  static const double borderRadiusSmall = 8.0;
  static const double borderRadiusMedium = 12.0;
  static const double borderRadiusLarge = 16.0;
  static const double borderRadiusXLarge = 20.0;
  static const double borderRadiusXXLarge = 24.0;
  static const double borderRadiusFull = 100.0;

  // Chat Specific Constants
  static const String chatInitialMessageEn = "Hello! I am your AI Health Assistant. Please describe your symptoms in detail, and I'll help you understand what might be happening.";
  static const String chatInitialMessageAr = "مرحباً! أنا مساعدك الصحي الذكي. يرجى وصف أعراضك بالتفصيل، وسأساعدك في فهم ما قد يحدث.";
  static const String chatDisclaimerEn = "Disclaimer: This is an AI assessment, not a medical diagnosis. Please consult a doctor for professional medical advice.";
  static const String chatDisclaimerAr = "إخلاء مسؤولية: هذا تقييم ذكاء اصطناعي وليس تشخيصاً طبياً. يرجى استشارة الطبيب للحصول على مشورة طبية مهنية.";
  static const String chatListeningEn = "I'm listening. Please describe your symptoms clearly (e.g., 'I have high fever and cough').";
  static const String chatListeningAr = "أنا أسمعك. يرجى وصف أعراضك بوضوح (مثلاً: 'عندي سخونية عالية وكحة').";
  static const String suggestionsEn = "Suggestions:";
  static const String suggestionsAr = "اقتراحات:";
  static const String diagnosisFallbackEn = "I have analyzed your symptoms and found a potential match:";
  static const String diagnosisFallbackAr = "لقد قمت بتحليل أعراضك ووجدت تشخيصاً محتملاً:";
  static const String roleExpert = "Expert Medical AI";
  static const String roleUser = "You";

  // Card Dimensions
  static const double categoryCardWidth = 24.0;
  static const double categoryCardHeight = 14.0;
  static const double categoryCardIconSize = 8.0;

  static const double specialtyCardPadding = 3.0;
  static const double symptomCardPadding = 1.5;

  // Icon Sizes
  static const double iconSizeSmall = 12.0;
  static const double iconSizeMedium = 16.0;
  static const double iconSizeLarge = 20.0;
  static const double iconSizeXLarge = 24.0;
  static const double iconSizeEmoji = 20.0;

  // Symptom Icons Mapping - Maps symptom categories to icons
  static const Map<String, String> symptomIcons = {
    // Heart/Vascular symptoms
    'chest_pain': '💔',
    'heart_pain': '❤️',
    'palpitations': '💓',
    'shortness_of_breath': '😮‍💨',
    'dyspnea': '😮‍💨',
    'fatigue': '😴',
    'dizziness': '😵',
    'syncope': '😵',
    'edema': '🦵',
    'swelling': '🦵',
    'nausea': '🤢',
    'sweating': '💦',
    'anxiety': '😰',
    'irregular_heartbeat': '⚡',
    'rapid_heartbeat': '⚡',
    'arrhythmia': '⚡',
    // Respiratory symptoms
    'cough': '🗣️',
    'wheezing': '🌬️',
    'sputum': '🤧',
    'phlegm': '🤧',
    'breathlessness': '😮‍💨',
    // Neurological symptoms
    'headache': '🤕',
    'migraine': '🤕',
    'numbness': '👋',
    'tingling': '👋',
    'weakness': '💪',
    'confusion': '🤔',
    'seizure': '⚡',
    'tremor': '⚡',
    // Gastrointestinal symptoms
    'abdominal_pain': '😣',
    'stomach_pain': '😣',
    'bloating': '😮',
    'constipation': '🚽',
    'diarrhea': '🚽',
    'vomiting': '🤮',
    'heartburn': '🔥',
    'indigestion': '🔥',
    'loss_of_appetite': '🍽️',
    // Musculoskeletal symptoms
    'joint_pain': '🦴',
    'muscle_pain': '💪',
    'back_pain': '🦴',
    'neck_pain': '🦴',
    'stiffness': '🦴',
    'swelling_joints': '🦵',
    'limited_movement': '🚶',
    // General/Infectious symptoms
    'fever': '🌡️',
    'chills': '🥶',
    'body_ache': '😣',
    'loss_of_taste': '👅',
    'loss_of_smell': '👃',
    'sore_throat': '😷',
    'runny_nose': '🤧',
    'sneezing': '🤧',
    // Psychological symptoms
    'depression': '😔',
    'insomnia': '🌙',
    'stress': '😰',
    'panic': '😰',
    'mood_changes': '🎭',
    // Emergency symptoms
    'severe_pain': '🚨',
    'unconsciousness': '🚨',
    'severe_bleeding': '🩸',
    'difficulty_breathing': '🆘',
    'chest_tightness': '🆘',
    'blurred_vision': '👁️',
    'speech_difficulty': '🗣️',
    // Default
    'default': '🔹',
  };

  // Breakpoints
  static const double mobileBreakpoint = 600.0;
  static const double tabletBreakpoint = 1200.0;
}
