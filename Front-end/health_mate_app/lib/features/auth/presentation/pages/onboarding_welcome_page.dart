import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../providers/auth_provider.dart';
import 'login_page.dart';
import 'email_verification_page.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';

class OnboardingWelcomePage extends ConsumerWidget {
  const OnboardingWelcomePage({super.key});

  Future<void> _handleGetStarted(BuildContext context, WidgetRef ref) async {
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);

    // Mark onboarding as completed
    await sharedPrefs.setOnboardingCompleted(true);

    final authState = ref.read(authNotifierProvider);

    if (context.mounted) {
      if (authState.status == AuthStatus.authenticated &&
          authState.user != null) {
        if (authState.user!.isPatient) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(page: const PatientHomePage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            FadePageRoute(page: const CaregiverHomePage()),
          );
        }
      } else if (authState.status == AuthStatus.unverified) {
        Navigator.of(context).pushReplacement(
          FadePageRoute(page: const EmailVerificationPage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          FadePageRoute(page: const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                ),
                child: IntrinsicHeight(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: context.w(6)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(height: context.h(4)),
                        // App Logo
                        AppIcons.splashLogo(
                          key: const ValueKey('welcome_onboarding_logo'),
                          size: context.sp(80),
                          color: null,
                        ),
                        SizedBox(height: context.h(2)),

                        // App Name
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'H',
                                style: TextStyle(
                                  color: AppColors.accentRed,
                                  fontSize: context.sp(40),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'EALTH ',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: context.sp(40),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'M',
                                style: TextStyle(
                                  color: AppColors.accentRed,
                                  fontSize: context.sp(40),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: 'ATE',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: context.sp(40),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.h(2)),

                        // Tagline
                        Text(
                          LocaleKeys.onboardingTagline.tr(),
                          style: TextStyle(
                            fontSize: context.sp(20),
                            fontWeight: FontWeight.bold,
                            color: AppColors.black,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: context.h(1.6)),

                        // Subtitle
                        Text(
                          LocaleKeys.onboardingSubtitle.tr(),
                          style: TextStyle(
                            fontSize: context.sp(16),
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: context.h(3)),

                        // Doctor Illustration
                        Container(
                          constraints: BoxConstraints(maxHeight: context.h(35)),
                          child: AppIcons.doctor(size: context.sp(250)),
                        ),

                        SizedBox(height: context.h(1.5)),

                        // Get Started Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _handleGetStarted(context, ref),
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.symmetric(
                                  vertical: context.h(1.8)),
                              backgroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: Text(
                              LocaleKeys.onboardingGetStarted.tr(),
                              style: TextStyle(
                                fontSize: context.sp(18),
                                fontWeight: FontWeight.bold,
                                color: AppColors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: context.h(4)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
