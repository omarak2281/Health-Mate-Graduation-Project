import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';
import 'onboarding_language_page.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/ecg_heart_line.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late AnimationController _pulseController;

  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<double> _textFade;
  late Animation<double> _pulseAnimation;

  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();

    // Entry sequence controller
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // Pulse/Heartbeat controller
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
    );

    _logoScale = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _textFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.5, 1.0, curve: Curves.easeIn),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _entryController.forward().then((_) {
      _pulseController.repeat(reverse: true);
    });

    _startTimer();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _startTimer() async {
    // Keeping the 5s duration as requested for a premium feel
    await Future.delayed(const Duration(seconds: 5));
    if (mounted) {
      setState(() {
        _canNavigate = true;
      });
      _checkAndNavigate();
    }
  }

  void _checkAndNavigate() {
    if (!_canNavigate) return;

    final sharedPrefs = ref.read(sharedPrefsCacheProvider);
    final isOnboardingCompleted = sharedPrefs.isOnboardingCompleted();

    // Determine the next screen
    Widget nextScreen;
    if (!isOnboardingCompleted) {
      nextScreen = const OnboardingLanguagePage();
    } else {
      final state = ref.read(authNotifierProvider);
      if (state.status == AuthStatus.loading ||
          state.status == AuthStatus.initial) {
        // Wait for auth provider to settle
        return;
      }
      nextScreen = _getNextScreen(state);
    }

    _navigateTo(nextScreen);
  }

  Widget _getNextScreen(AuthState state) {
    if (state.status == AuthStatus.authenticated && state.user != null) {
      return state.user!.isPatient
          ? const PatientHomePage()
          : const CaregiverHomePage();
    } else if (state.status == AuthStatus.unverified) {
      return const EmailVerificationPage();
    } else {
      return const LoginPage();
    }
  }

  void _navigateTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      FadePageRoute(page: screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state changes if we are waiting for auth
    ref.listen(authNotifierProvider, (previous, next) {
      if (_canNavigate) {
        final sharedPrefs = ref.read(sharedPrefsCacheProvider);
        if (sharedPrefs.isOnboardingCompleted()) {
          _checkAndNavigate();
        }
      }
    });

    // Get theme mode from cache
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);
    final themeMode = sharedPrefs.getThemeMode();
    final isDark = themeMode == 'dark';

    // Define theme-aware colors
    final backgroundColor = isDark ? const Color(0xFF0A0E21) : Colors.white;
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimary;
    final accentColor = AppColors.primary;
    final subtleTextColor = isDark
        ? AppColors.textSecondary.withValues(alpha: 0.6)
        : AppColors.textSecondary.withValues(alpha: 0.5);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: context.w(10)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with Entry Fade + Scale + Continuous Pulse
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: ScaleTransition(
                    scale: _pulseAnimation,
                    child: AppIcons.splashLogo(
                      size: context.sp(150),
                      color: null,
                    ),
                  ),
                ),
              ),
              SizedBox(height: context.h(3)),

              // App Name and Tagline with Fade
              FadeTransition(
                opacity: _textFade,
                child: Column(
                  children: [
                    Text(
                      LocaleKeys.appName.tr(),
                      style: TextStyle(
                        fontSize: context.sp(28),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                        color: primaryTextColor,
                      ),
                    ),
                    SizedBox(height: context.h(1)),
                    Text(
                      LocaleKeys.splashTagline.tr(),
                      style: TextStyle(
                        fontSize: context.sp(16),
                        color: accentColor,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: context.h(8)),

              // ECG Line with Fade
              FadeTransition(
                opacity: _textFade,
                child: ECGHeartLine(
                  width: context.w(60),
                  height: context.h(10),
                  color: accentColor,
                ),
              ),

              SizedBox(height: context.h(4)),

              // Subtle Loading Info
              FadeTransition(
                opacity: _textFade,
                child: Text(
                  "Initializing Medical Systems...".toUpperCase(),
                  style: TextStyle(
                    color: subtleTextColor,
                    letterSpacing: 2.0,
                    fontSize: context.sp(10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
