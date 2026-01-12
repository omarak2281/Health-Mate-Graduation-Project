import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';
import 'onboarding_language_page.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/theme/app_colors.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  bool _canNavigate = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  Future<void> _startTimer() async {
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

    // If onboarding is NOT completed, go to onboarding immediately after timer
    if (!isOnboardingCompleted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const OnboardingLanguagePage()),
      );
      return;
    }

    // If onboarding IS completed, wait for auth status to be definitive
    final state = ref.read(authNotifierProvider);
    if (state.status != AuthStatus.loading &&
        state.status != AuthStatus.initial) {
      _handleNavigation(state);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for state changes
    ref.listen(authNotifierProvider, (previous, next) {
      if (_canNavigate) {
        _handleNavigation(next);
      }
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AssetsConstants.splashLogo,
                height: 150,
                width: 150,
                fit: BoxFit.contain,
                placeholderBuilder: (context) => const SizedBox(
                  height: 150,
                  width: 150,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                LocaleKeys.appName.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                LocaleKeys.splashTagline.tr(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: 200,
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                  borderRadius: const BorderRadius.all(Radius.circular(2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleNavigation(AuthState state) {
    if (!mounted) return;

    // This method is now only called when onboarding is already completed
    if (state.status == AuthStatus.authenticated && state.user != null) {
      if (state.user!.isPatient) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const PatientHomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CaregiverHomePage()),
        );
      }
    } else if (state.status == AuthStatus.unverified) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
      );
    } else if (state.status == AuthStatus.unauthenticated) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    } else if (state.status == AuthStatus.error) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }
}
