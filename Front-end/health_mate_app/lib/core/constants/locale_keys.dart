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
  static const String commonHello = 'common.hello';
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
  static const String manage = 'common.manage';
  static const String active = 'common.active';
  static const String pending = 'common.pending';
  static const String status = 'common.status';

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
  static const String authPatientSubtitle = 'auth.patient_subtitle';
  static const String authCaregiverSubtitle = 'auth.caregiver_subtitle';
  static const String authEnterEmail = 'auth.enter_email';
  static const String authEnterPassword = 'auth.enter_password';
  static const String authEnterName = 'auth.enter_name';
  static const String authEnterPhone = 'auth.enter_phone';
  static const String authBirthday = 'auth.birthday';
  static const String authDay = 'auth.day';
  static const String authMonth = 'auth.month';
  static const String authYear = 'auth.year';
  static const String authGender = 'auth.gender';
  static const String authMale = 'auth.male';
  static const String authFemale = 'auth.female';
  static const String authCreateAccount = 'auth.create_account';
  static const String authCreatePassword = 'auth.create_password';
  static const String authLoginToAccount = 'auth.login_to_account';
  static const String authWelcomeBack = 'auth.welcome_back';
  static const String authContinueWith = 'auth.continue_with';
  static const String authContinueWithGoogle = 'auth.continue_with_google';
  static const String authDontHaveAccount = 'auth.dont_have_account';
  static const String authSignUpNow = 'auth.sign_up_now';
  static const String authAlreadyHaveAccount = 'auth.already_have_account';
  static const String authLoginNow = 'auth.login_now';
  static const String authLoginError = 'auth.login_error';
  static const String authGoogleNotRegistered = 'auth.google_not_registered';
  static const String authGoToRegister = 'auth.go_to_register';
  static const String authCompleteProfile = 'auth.complete_profile';
  static const String authCompleteProfileSubtitle =
      'auth.complete_profile_subtitle';
  static const String authSelectGender = 'auth.select_gender';
  static const String authFinishRegistration = 'auth.finish_registration';
  static const String authContinueWithGoogleRegister =
      'auth.continue_with_google_register';
  static const String authResetPassword = 'auth.reset_password';
  static const String authResetPasswordInstruction =
      'auth.reset_password_instruction';
  static const String authResetPasswordSent = 'auth.reset_password_sent';
  static const String authResendResetEmail = 'auth.resend_reset_email';
  static const String authScanQrCodeOn = 'auth.scan_qr_code_on';
  static const String authThePatients = 'auth.the_patients';
  static const String authDevice = 'auth.device';

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
  static const String homeAvgToday = 'home.avg_today';
  static const String homeMax = 'home.max';
  static const String homeBpm = 'home.bpm';
  static const String homeCheckNow = 'home.check_now';
  static const String homeMeasurementsHistory = 'home.measurements_history';
  static const String homeHome = 'home.home';
  static const String homeCheck = 'home.check';
  static const String homeMeds = 'home.meds';
  static const String homeSetting = 'home.setting';
  static const String homeMmHg = 'home.mmHg';

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
  static const String medicationsDemoAdd = 'medications.demo_add_medication';
  static const String medicationsTakeNow = 'medications.take_now';
  static const String medicationsSnooze = 'medications.snooze';
  static const String medicationsAlarmTitle = 'medications.alarm_title';
  static const String medicationsTimeToTake = 'medications.time_to_take';
  static const String medicationsConfirmed = 'medications.confirmed';
  static const String medicationsEnableLed = 'medications.enable_led';
  static const String medicationsEnableBuzzer = 'medications.enable_buzzer';
  static const String medicationsImageUploadError =
      'medications.image_upload_error';
  static const String medicationsAddPhoto = 'medications.add_photo';
  static const String medicationsMedicationInformation =
      'medications.medication_information';
  static const String medicationsMedsList = 'medications.meds_list';
  static const String medicationsTodaysSchedule = 'medications.todays_schedule';
  static const String medicationsViewCalendar = 'medications.view_calendar';
  static const String medicationsNextDose = 'medications.next_dose';
  static const String medicationsDoneAllCaps = 'medications.done_all_caps';
  static const String medicationsFormFactor = 'medications.form_factor';
  static const String medicationsTablet = 'medications.tablet';
  static const String medicationsCapsule = 'medications.capsule';
  static const String medicationsInjection = 'medications.injection';
  static const String medicationsLiquid = 'medications.liquid';
  static const String medicationsSchedule = 'medications.schedule';
  static const String medicationsInterval = 'medications.interval';
  static const String medicationsStartDate = 'medications.start_date';
  static const String medicationsSmartBoxSection =
      'medications.smart_box_section';
  static const String medicationsViewMore = 'medications.view_more';
  static const String medicationsAssignToDrawer =
      'medications.assign_to_drawer';
  static const String medicationsMedicationBox = 'medications.medication_box';
  static const String medicationsSmartBoxId = 'medications.smart_box_id';
  static const String medicationsBattery = 'medications.battery';
  static const String medicationsDrawers = 'medications.drawers';
  static const String medicationsAssign = 'medications.assign';

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
  static const String settingsLogoutConfirm = 'settings.logout_confirm';
  static const String settingsQrShareSubtitle = 'settings.qr_share_subtitle';
  static const String settingsRevealCode = 'settings.reveal_code';
  static const String settingsLinkedCompanions = 'settings.linked_companions';
  static const String settingsAccount = 'settings.account';
  static const String settingsDeleteAccount = 'settings.delete_account';
  static const String settingsDeleteAccountDesc =
      'settings.delete_account_desc';
  static const String settingsYears = 'settings.years';

  // Contacts
  static const String contactsTitle = 'contacts.title';
  static const String contactsNoContacts = 'contacts.no_contacts';
  static const String contactsAddInstructions = 'contacts.add_instructions';
  static const String contactsAddContact = 'contacts.add_contact';
  static const String contactsType = 'contacts.type';
  static const String contactsDoctor = 'contacts.doctor';
  static const String contactsPharmacy = 'contacts.pharmacy';
  static const String contactsEmergency = 'contacts.emergency';
  static const String contactsFamily = 'contacts.family';
  static const String contactsDeleteConfirm = 'contacts.delete_confirm';
  static const String contactsDeleteWarning = 'contacts.delete_warning';

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
  static const String authGoogleSignUpRequired = 'auth.google_sign_up_required';
  static const String authRecoveryRoleRequired = 'auth.recovery_role_required';
  static const String authEmailMismatch = 'auth.email_mismatch';
  static const String authRoleSelectionRequired =
      'auth.role_selection_required';
  static const String authEmailNotVerifiedFirebase =
      'auth.email_not_verified_firebase';

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
  static const String onboardingTagline = 'onboarding.tagline';
  static const String onboardingSubtitle = 'onboarding.subtitle';

  // Medicine Tutorial
  static const String medicineTutorialMeetYour = 'medicine_tutorial.meet_your';
  static const String medicineTutorialSmartBox = 'medicine_tutorial.smart_box';
  static const String medicineTutorialDescription1 =
      'medicine_tutorial.description_1';
  static const String medicineTutorialAlerts = 'medicine_tutorial.alerts';
  static const String medicineTutorialLighting = 'medicine_tutorial.lighting';
  static const String medicineTutorialReminder = 'medicine_tutorial.reminder';
  static const String medicineTutorialLearnMore =
      'medicine_tutorial.learn_more';

  static const String medicineTutorialSmartBoxSetup =
      'medicine_tutorial.smart_box_setup';
  static const String medicineTutorialFillDrawer =
      'medicine_tutorial.fill_drawer';
  static const String medicineTutorialDescription2 =
      'medicine_tutorial.description_2';
  static const String medicineTutorialNextStep = 'medicine_tutorial.next_step';
  static const String medicineTutorialSkip = 'medicine_tutorial.skip';
  static const String medicineTutorialMorning = 'medicine_tutorial.morning';
  static const String medicineTutorialNoon = 'medicine_tutorial.noon';
  static const String medicineTutorialEvening = 'medicine_tutorial.evening';
  static const String medicineTutorialNight = 'medicine_tutorial.night';
  static const String medicineTutorialAssigned = 'medicine_tutorial.assigned';
  static const String medicineTutorialAssignMeds =
      'medicine_tutorial.assign_meds';
  static const String medicineTutorialEmpty = 'medicine_tutorial.empty';

  static const String medicineTutorialStep3 = 'medicine_tutorial.step_3';
  static const String medicineTutorialSmartNotifications =
      'medicine_tutorial.smart_notifications';
  static const String medicineTutorialDescription3Part1 =
      'medicine_tutorial.description_3_part1';
  static const String medicineTutorialLightUp = 'medicine_tutorial.light_up';
  static const String medicineTutorialDescription3Part2 =
      'medicine_tutorial.description_3_part2';
  static const String medicineTutorialFinishSetup =
      'medicine_tutorial.finish_setup';
  static const String medicineTutorialReplay = 'medicine_tutorial.replay';
}
