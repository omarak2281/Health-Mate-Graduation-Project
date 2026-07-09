import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/constants/constants.dart';
import 'core/constants/locale_keys.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/storage/hive_cache.dart';
import 'core/storage/shared_prefs_cache.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/background_translation_service.dart';
import 'features/auth/presentation/pages/splash_page.dart';
import 'features/communication/presentation/widgets/call_coordinator.dart';

// Global navigator key for background notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ⚠️  The background handler MUST be registered as early as possible —
  // before Firebase.initializeApp() — so that the background isolate finds it.
  FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();
  await BackgroundTranslationService.instance.init();

  // Initialize cache services
  final hiveCache = HiveCache();
  await hiveCache.init();

  final sharedPrefsCache = SharedPrefsCache();
  await sharedPrefsCache.init();

  // Initialize Local Notifications Service
  await LocalNotificationService.instance.init();

  // Initialize Push Notifications Service
  try {
    await PushNotificationService.instance.init();
  } catch (e) {
    debugPrint('Push Notifications initialization failed: $e');
  }

  // Get saved language preference
  final savedLanguage = sharedPrefsCache.getLanguage();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLanguage),
      child: ProviderScope(
        overrides: [
          sharedPrefsCacheProvider.overrideWithValue(sharedPrefsCache),
          hiveCacheProvider.overrideWithValue(hiveCache),
        ],
        child: const HealthMateApp(),
      ),
    ),
  );
}

class HealthMateApp extends ConsumerWidget {
  const HealthMateApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      onGenerateTitle: (context) => LocaleKeys.appName.tr(),
      debugShowCheckedModeBanner: false,

      // Localization
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      builder: (context, child) => CallCoordinator(
        child: child ?? const SizedBox.shrink(),
      ),

      home: const SplashPage(),
    );
  }
}
