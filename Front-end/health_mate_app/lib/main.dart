import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/constants.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/storage/hive_cache.dart';
import 'core/storage/shared_prefs_cache.dart';
import 'features/auth/presentation/pages/splash_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
    // On web, if firebase_options.dart is missing, this will fail.
    // For now, we continue so the app can at least start.
  }

  // Initialize EasyLocalization
  await EasyLocalization.ensureInitialized();

  // Initialize cache services
  final hiveCache = HiveCache();
  await hiveCache.init();

  final sharedPrefsCache = SharedPrefsCache();
  await sharedPrefsCache.init();

  // Get saved language preference
  final savedLanguage = sharedPrefsCache.getLanguage();

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('en'), Locale('ar')],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      startLocale: Locale(savedLanguage), // Use saved language preference
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

      home: const SplashPage(),
    );
  }
}
