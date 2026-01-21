import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/navigation_utils.dart';
import 'onboarding_welcome_page.dart';

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

  void _handleGetStarted() {
    Navigator.of(context).push(
      FadePageRoute(page: const OnboardingWelcomePage()),
    );
  }

  Widget _buildLanguageOption({
    required String languageCode,
    required String languageName,
    required String nativeName,
    required Widget flag,
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
        padding: EdgeInsets.symmetric(
          horizontal: context.w(5),
          vertical: context.h(2),
        ),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.white : AppColors.backgroundLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          children: [
            // Premium Flag Icon
            SizedBox(
              width: context.sp(48),
              height: context.sp(48),
              child: flag,
            ),
            SizedBox(width: context.w(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    languageName,
                    style: TextStyle(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary : AppColors.black,
                    ),
                  ),
                  SizedBox(height: context.h(0.5)),
                  Text(
                    nativeName,
                    style: TextStyle(
                      fontSize: context.sp(14),
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: context.sp(24),
              height: context.sp(24),
              child: isSelected
                  ? Container(
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check,
                          color: Colors.white, size: context.sp(16)),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: context.h(4)),
            // Fixed App Logo (Static, doesn't re-animate on entry or language change)
            Center(
              child: AppIcons.splashLogo(
                key: const ValueKey('onboarding_fixed_logo'),
                size: context.sp(100),
                color: null,
              ),
            ),

            // Animated Content (Only these elements transition on page load)
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(6),
                      vertical: context.h(2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: context.h(3)),

                        // Language Selection Header
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              LocaleKeys.onboardingSelectLanguage.tr(),
                              style: TextStyle(
                                fontSize: context.sp(24),
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: context.h(1.5)),
                            Text(
                              LocaleKeys.onboardingLanguageDescription.tr(),
                              style: TextStyle(
                                fontSize: context.sp(16),
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                        SizedBox(height: context.h(4)),

                        // Language Options
                        _buildLanguageOption(
                          languageCode: AppConstants.englishCode,
                          languageName: LocaleKeys.onboardingEnglish.tr(),
                          nativeName: 'English',
                          flag: AppIcons.ukFlag(),
                        ),
                        SizedBox(height: context.h(2.5)),
                        _buildLanguageOption(
                          languageCode: AppConstants.arabicCode,
                          languageName: LocaleKeys.onboardingArabic.tr(),
                          nativeName: 'العربية',
                          flag: AppIcons.egyptFlag(),
                        ),

                        SizedBox(height: context.h(6)),

                        // Get Started Button
                        ElevatedButton(
                          onPressed: _handleGetStarted,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding:
                                EdgeInsets.symmetric(vertical: context.h(2.2)),
                            elevation: 8,
                            shadowColor:
                                AppColors.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                LocaleKeys.onboardingGetStarted
                                    .tr()
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: context.sp(16),
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: EdgeInsets.only(right: context.w(4)),
                                  child: Icon(Icons.arrow_forward_ios,
                                      size: context.sp(18)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: context.h(3)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
