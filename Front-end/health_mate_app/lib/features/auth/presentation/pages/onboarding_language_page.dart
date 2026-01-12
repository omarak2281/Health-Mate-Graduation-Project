import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';

/// Language Selection Onboarding Screen
/// Shown on first launch to let user choose app language
/// Language preference is cached for subsequent launches

class OnboardingLanguagePage extends ConsumerStatefulWidget {
  const OnboardingLanguagePage({super.key});

  @override
  ConsumerState<OnboardingLanguagePage> createState() =>
      _OnboardingLanguagePageState();
}

class _OnboardingLanguagePageState extends ConsumerState<OnboardingLanguagePage>
    with SingleTickerProviderStateMixin {
  String _selectedLanguage = AppConstants.englishCode;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Load saved language preference if available
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);
    _selectedLanguage = sharedPrefs.getLanguage();

    // Setup animations
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _animationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleGetStarted() async {
    // Check if widget is still mounted
    if (!mounted) return;

    final sharedPrefs = ref.read(sharedPrefsCacheProvider);

    // Mark onboarding as completed
    await sharedPrefs.setOnboardingCompleted(true);

    if (!mounted) return;

    // Determine destination immediately without going back to Splash delay
    final authState = ref.read(authNotifierProvider);

    if (authState.status == AuthStatus.authenticated &&
        authState.user != null) {
      if (authState.user!.isPatient) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PatientHomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CaregiverHomePage()),
        );
      }
    } else if (authState.status == AuthStatus.unverified) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
    } else {
      // Default for first-time users completing onboarding
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required String nativeName,
    required IconData icon,
  }) {
    final isSelected = _selectedLanguage == languageCode;

    return GestureDetector(
      onTap: () async {
        setState(() {
          _selectedLanguage = languageCode;
        });

        // Update locale immediately
        await context.setLocale(Locale(languageCode));

        // Save language preference immediately
        final sharedPrefs = ref.read(sharedPrefsCacheProvider);
        await sharedPrefs.setLanguage(languageCode);
      },
      child: AnimatedContainer(
        duration: AppConstants.mediumAnimationDuration,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withOpacity(0.2)
                    : AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 32,
                color: isSelected ? Colors.white : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nativeName,
                    style: TextStyle(
                      fontSize: 14,
                      color: isSelected
                          ? Colors.white.withOpacity(0.9)
                          : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // App Logo
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome Title
                  Text(
                    LocaleKeys.onboardingWelcome.tr(),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // App Name
                  Text(
                    AppConstants.appName,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),

                  // Language Selection Title
                  Text(
                    LocaleKeys.onboardingSelectLanguage.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    LocaleKeys.onboardingLanguageDescription.tr(),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Language Options
                  _buildLanguageOption(
                    languageCode: AppConstants.englishCode,
                    languageName: LocaleKeys.onboardingEnglish.tr(),
                    nativeName: 'English',
                    icon: Icons.language,
                  ),
                  const SizedBox(height: 16),
                  _buildLanguageOption(
                    languageCode: AppConstants.arabicCode,
                    languageName: LocaleKeys.onboardingArabic.tr(),
                    nativeName: 'العربية',
                    icon: Icons.translate,
                  ),

                  const Spacer(),

                  // Get Started Button
                  ElevatedButton(
                    onPressed: _handleGetStarted,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          LocaleKeys.onboardingGetStarted.tr(),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
