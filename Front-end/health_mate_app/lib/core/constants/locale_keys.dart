/// Localization Keys
/// ALL text strings as constants for easy updates
/// Usage: LocaleKeys.authLogin.tr()

class LocaleKeys {
  LocaleKeys._();

  // App
  static const String appName = 'app_name';
  static const String appNameArabic = 'app_name_arabic';

  // Common
  static const String ok = 'common.ok';
  static const String commonOk = 'common.ok';
  static const String cancel = 'common.cancel';
  static const String commonCancel = 'common.cancel';
  static const String save = 'common.save';
  static const String delete = 'common.delete';
  static const String edit = 'common.edit';
  static const String close = 'common.close';
  static const String loading = 'common.loading';
  static const String error = 'common.error';
  static const String commonError = 'common.error';
  static const String success = 'common.success';
  static const String retry = 'common.retry';
  static const String noInternet = 'common.no_internet';
  static const String offlineMode = 'common.offline_mode';
  static const String confirm = 'common.confirm';
  static const String back = 'common.back';
  static const String next = 'common.next';
  static const String done = 'common.done';
  static const String search = 'common.search';
  static const String filter = 'common.filter';
  static const String refresh = 'common.refresh';
  static const String viewAll = 'common.view_all';
  static const String contacts = 'common.contacts';
  static const String upload = 'common.upload';
  static const String takePhoto = 'common.take_photo';
  static const String chooseGallery = 'common.choose_gallery';

  // Auth
  static const String authLogin = 'auth.login';
  static const String authRegister = 'auth.register';
  static const String authLogout = 'auth.logout';
  static const String authEmail = 'auth.email';
  static const String authPassword = 'auth.password';
  static const String authFullName = 'auth.full_name';
  static const String authPhone = 'auth.phone';
  static const String authConfirmPassword = 'auth.confirm_password';
  static const String authForgotPassword = 'auth.forgot_password';
  static const String authLoginSuccess = 'auth.login_success';
  static const String authRegisterSuccess = 'auth.register_success';
  static const String authSelectRole = 'auth.select_role';
  static const String authPatient = 'auth.patient';
  static const String authCaregiver = 'auth.caregiver';
  static const String authUpdateProfile = 'auth.update_profile';
  static const String authEditProfile = 'auth.edit_profile';
  static const String authProfileUpdated = 'auth.profile_updated';
  static const String authUploadingImage = 'auth.uploading_image';
  static const String authLinkedPatient = 'auth.linked_patient';
  static const String authCurrentPassword = 'auth.current_password';
  static const String authNewPassword = 'auth.new_password';
  static const String authConfirmNewPassword = 'auth.confirm_new_password';
  static const String authPasswordChangedSuccess =
      'auth.password_changed_success';
  static const String authVerifyEmail = 'auth.verify_email';
  static const String authVerificationSent = 'auth.verification_sent';
  static const String authNotVerified = 'auth.not_verified';
  static const String authResendEmail = 'auth.resend_email';
  static const String authCheckVerification = 'auth.check_verification';
  static const String authGoogleSignIn = 'auth.google_sign_in';
  static const String authRegisterGoogle = 'auth.register_google';
  static const String authSocialAuthCancelled = 'auth.social_auth_cancelled';

  // Home
  static const String homeWelcome = 'home.welcome';
  static const String homeLatestBp = 'home.latest_bp';
  static const String homeBpHistory = 'home.bp_history';
  static const String vitalsBpTrend = 'vitals.bp_trend';
  static const String vitalsReadingHistory = 'vitals.reading_history';
  static const String vitalsHeartRateValue = 'vitals.heart_rate_value';
  static const String homeMedications = 'home.medications';
  static const String homeNotifications = 'home.notifications';
  static const String homeSettings = 'home.settings';
  static const String homeDashboard = 'home.dashboard';
  static const String homePatientDashboard = 'home.patient_dashboard';
  static const String homeCaregiverDashboard = 'home.caregiver_dashboard';
  static const String homeRecentAlerts = 'home.recent_alerts';
  static const String homeNoActiveAlerts = 'home.no_active_alerts';
  static const String homeAlertsSubtitle = 'home.alerts_subtitle';
  static const String homeLinkedPatients = 'home.linked_patients';
  static const String homeNoLinkedPatients = 'home.no_linked_patients';
  static const String homeScanToLinkSubtitle = 'home.scan_to_link_subtitle';
  static const String homeScanQrCode = 'home.scan_qr_code';
  static const String homeQuickActions = 'home.quick_actions';
  static const String homeAiChat = 'home.ai_chat';
  static const String aiWelcomeMessage = 'ai.welcome_message';
  static const String aiInputPlaceholder = 'ai.input_placeholder';
  static const String aiErrorMessage = 'ai.error_message';
  static const String aiUnknownResponse = 'ai.unknown_response';
  static const String splashTagline = 'splash.tagline';

  // Vitals
  static const String vitalsBloodPressure = 'vitals.blood_pressure';
  static const String vitalsSystolic = 'vitals.systolic';
  static const String vitalsDiastolic = 'vitals.diastolic';
  static const String vitalsHeartRate = 'vitals.heart_rate';
  static const String vitalsRiskNormal = 'vitals.risk_normal';
  static const String vitalsRiskLow = 'vitals.risk_low';
  static const String vitalsRiskModerate = 'vitals.risk_moderate';
  static const String vitalsRiskHigh = 'vitals.risk_high';
  static const String vitalsRiskCritical = 'vitals.risk_critical';
  static const String vitalsNoReadings = 'vitals.no_readings';
  static const String vitalsViewHistory = 'vitals.view_history';
  static const String vitalsAddReading = 'vitals.add_reading';
  static const String vitalsLastReading = 'vitals.last_reading';
  static const String vitalsReadingTime = 'vitals.reading_time';
  static const String vitalsDate = 'vitals.date';
  static const String vitalsNormalBpStatus = 'vitals.normal_bp_status';
  static const String vitalsHighBpStatus = 'vitals.high_bp_status';
  static const String vitalsHealthTip = 'vitals.health_tip';
  static const String vitalsHighBpRec = 'vitals.high_bp_recommend';
  static const String vitalsNormalBpRec = 'vitals.normal_bp_recommend';
  static const String vitalsSource = 'vitals.source';
  static const String vitalsManual = 'vitals.manual';
  static const String vitalsSensor = 'vitals.sensor';
  static const String vitalsPpgSensor = 'vitals.ppg_sensor';
  static const String vitalsEcgSensor = 'vitals.ecg_sensor';
  static const String vitalsConnected = 'vitals.connected';
  static const String vitalsDisconnected = 'vitals.disconnected';
  static const String vitalsSignalExcellent = 'vitals.signal_excellent';
  static const String vitalsSignalPoor = 'vitals.signal_poor';
  static const String vitalsSmartMedicineBox = 'vitals.smart_medicine_box';
  static const String vitalsDrawer = 'vitals.drawer';
  static const String vitalsTestingDrawer = 'vitals.testing_drawer';
  static const String vitalsIoTDevices = 'vitals.iot_devices';

  // Medications
  static const String medicationsMyMedications = 'medications.my_medications';
  static const String medicationsAddMedication = 'medications.add_medication';
  static const String medicationsMedicationName = 'medications.medication_name';
  static const String medicationsDosage = 'medications.dosage';
  static const String medicationsFrequency = 'medications.frequency';
  static const String medicationsTimeSlots = 'medications.time_slots';
  static const String medicationsInstructions = 'medications.instructions';
  static const String medicationsDrawer = 'medications.drawer';
  static const String medicationsNoMedications = 'medications.no_medications';
  static const String medicationsConfirmTaken = 'medications.confirm_taken';
  static const String medicationsActive = 'medications.active';
  static const String medicationsInactive = 'medications.inactive';
  static const String medicationsTakeNow = 'medications.take_now';
  static const String medicationsSnooze = 'medications.snooze';
  static const String medicationsAlarmTitle = 'medications.alarm_title';
  static const String medicationsTimeToTake = 'medications.time_to_take';
  static const String medicationsConfirmed = 'medications.confirmed';
  static const String medicationsEnableLed = 'medications.enable_led';
  static const String medicationsEnableBuzzer = 'medications.enable_buzzer';
  static const String medicationsImageUploadError =
      'medications.image_upload_error';

  // Notifications
  static const String notificationsTitle = 'notifications.title';
  static const String notificationsNoNotifications =
      'notifications.no_notifications';
  static const String notificationsMarkAllRead = 'notifications.mark_all_read';
  static const String notificationsEmergencyAlert =
      'notifications.emergency_alert';
  static const String notificationsMedicationReminder =
      'notifications.medication_reminder';

  // Settings
  static const String settingsTitle = 'settings.title';
  static const String settingsProfile = 'settings.profile';
  static const String settingsLanguage = 'settings.language';
  static const String settingsTheme = 'settings.theme';
  static const String settingsThemeLight = 'settings.theme_light';
  static const String settingsThemeDark = 'settings.theme_dark';
  static const String settingsNotifications = 'settings.notifications';
  static const String settingsAbout = 'settings.about';
  static const String settingsVersion = 'settings.version';
  static const String settingsChangePassword = 'settings.change_password';

  // Linking
  static const String linkingMyQrCode = 'linking.my_qr_code';
  static const String linkingScanToLink = 'linking.scan_to_link';
  static const String linkingScanInstructions = 'linking.scan_instructions';
  static const String linkingScanPatientQr = 'linking.scan_patient_qr';
  static const String linkingScanInstructionsDetail =
      'linking.scan_instructions_detail';
  static const String linkingLinkedSuccess = 'linking.linked_success';
  // Errors - Validation
  static const String errorsInvalidEmail = 'errors.invalid_email';
  static const String errorsPasswordTooShort = 'errors.password_too_short';
  static const String errorsPasswordsDontMatch = 'errors.passwords_dont_match';
  static const String errorsRequiredField = 'errors.required_field';
  static const String errorsNameTooShort = 'errors.name_too_short';
  static const String errorsInvalidPhone = 'errors.invalid_phone';

  // Errors - Network
  static const String errorsNetworkError = 'errors.network_error';
  static const String errorsServerError = 'errors.server_error';
  static const String errorsConnectionTimeout = 'errors.connection_timeout';
  static const String errorsRequestCancelled = 'errors.request_cancelled';

  // Errors - Auth
  static const String errorsUnauthorized = 'errors.unauthorized';
  static const String errorsFirebaseUserCreationFailed =
      'errors.firebase_user_creation_failed';
  static const String errorsFirebaseTokenFailed =
      'errors.firebase_token_failed';
  static const String errorsFirebaseLoginFailed =
      'errors.firebase_login_failed';
  static const String errorsGoogleSignInFailed = 'errors.google_sign_in_failed';
  static const String errorsGoogleTokenFailed = 'errors.google_token_failed';
  static const String errorsEmailAlreadyInUse = 'errors.email_already_in_use';
  static const String errorsInvalidCredentials = 'errors.invalid_credentials';
  static const String errorsUserNotFound = 'errors.user_not_found';
  static const String errorsWrongPassword = 'errors.wrong_password';
  static const String errorsAccountDisabled = 'errors.account_disabled';
  static const String errorsTooManyRequests = 'errors.too_many_requests';

  // Errors - Generic
  static const String errorsUnknownError = 'errors.unknown_error';
  static const String errorsSomethingWentWrong = 'errors.something_went_wrong';

  // Onboarding
  static const String onboardingWelcome = 'onboarding.welcome';
  static const String onboardingSelectLanguage = 'onboarding.select_language';
  static const String onboardingLanguageDescription =
      'onboarding.language_description';
  static const String onboardingGetStarted = 'onboarding.get_started';
  static const String onboardingEnglish = 'onboarding.english';
  static const String onboardingArabic = 'onboarding.arabic';
}
