import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../providers/auth_provider.dart';
import 'register_page.dart';
import 'email_verification_page.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      ref.read(authNotifierProvider.notifier).clearError();
      await ref.read(authNotifierProvider.notifier).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );

      // Handle Account Recovery (Missing Role)
      // If login failed because backend needs role to re-create user
      final state = ref.read(authNotifierProvider);
      if (state.status == AuthStatus.error &&
          (state.errorMessage?.toLowerCase().contains("role") ?? false)) {
        if (!mounted) return;

        final role = await _showRoleSelectionDialog();

        if (role != null) {
          await ref.read(authNotifierProvider.notifier).login(
                email: _emailController.text.trim(),
                password: _passwordController.text,
                role: role,
              );
        }
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    ref.read(authNotifierProvider.notifier).clearError();

    try {
      // LOGIN attempt: Try Google Sign-In (isSignup: false means only existing users allowed)
      await ref
          .read(authNotifierProvider.notifier)
          .loginWithGoogle(role: null, isSignup: false);
    } catch (e) {
      // Check if authentication failed due to missing account (404)
      final state = ref.read(authNotifierProvider);
      final errorMsg = state.errorMessage ?? '';

      // Check for "Not registered" in both English and Arabic translations
      if (errorMsg.contains('Not registered') ||
          errorMsg.contains('غير مسجل')) {
        if (!mounted) return;

        // Clear the error from UI
        ref.read(authNotifierProvider.notifier).clearError();

        // Show expert dialog with "Go to Register" option
        final goToRegister = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.error_outline,
                    color: AppColors.error, size: context.sp(24)),
                SizedBox(width: context.w(2)),
                Text(LocaleKeys.authLoginError.tr()),
              ],
            ),
            content: Text(
              LocaleKeys.authGoogleNotRegistered.tr(),
              style: TextStyle(fontSize: context.sp(16)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(LocaleKeys.cancel.tr()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: AppStyles.primaryButtonStyle.copyWith(
                  backgroundColor:
                      WidgetStateProperty.all(AppColors.expertTeal),
                  minimumSize: WidgetStateProperty.all(
                      Size(context.w(30), context.h(5.5))),
                ),
                child: Text(LocaleKeys.authGoToRegister.tr()),
              ),
            ],
          ),
        );

        if (goToRegister == true && mounted) {
          final role = await _showRoleSelectionDialog();

          if (role != null) {
            if (!mounted) return;
            // Navigate to RegisterPage with the selected role
            Navigator.push(
              context,
              FadePageRoute(
                page: RegisterPage(initialRole: role),
              ),
            );
          }
        }
      }
    }
  }

  Future<String?> _showRoleSelectionDialog() {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.only(top: context.h(3)),
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(5), vertical: context.h(2)),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcons.splashLogo(size: context.sp(60), color: null),
            SizedBox(height: context.h(2)),
            Text(
              LocaleKeys.authSelectRole.tr(),
              textAlign: TextAlign.center,
              style: AppStyles.cardTitleStyle.copyWith(
                fontSize: context.sp(24),
                color: AppColors.expertTeal,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildRoleOption(
              context,
              icon: Icons.person_rounded,
              title: LocaleKeys.authPatient.tr(),
              subtitle: LocaleKeys.authPatientSubtitle.tr(),
              role: AppConstants.rolePatient,
            ),
            SizedBox(height: context.h(2)),
            _buildRoleOption(
              context,
              icon: Icons.medical_services_rounded,
              title: LocaleKeys.authCaregiver.tr(),
              subtitle: LocaleKeys.authCaregiverSubtitle.tr(),
              role: AppConstants.roleCaregiver,
            ),
            SizedBox(height: context.h(1)),
          ],
        ),
      ),
    ).then((role) {
      if (role != null) {
        ref.read(sharedPrefsCacheProvider).setLastSelectedRole(role);
      }
      return role;
    });
  }

  Future<void> _handleForgotPassword() async {
    final authState = ref.read(authNotifierProvider);
    if (authState.status == AuthStatus.loading) return;

    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authEnterEmail.tr())),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LocaleKeys.authResetPassword.tr()),
        content: Text(LocaleKeys.authResetPasswordInstruction.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expertTeal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(LocaleKeys.authResetPassword.tr()),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(authNotifierProvider.notifier).resetPassword(email);
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Icon(
                Icons.check_circle_outline,
                color: AppColors.success,
                size: context.sp(60),
              ),
              content: Text(
                LocaleKeys.authResetPasswordSent.tr(),
                textAlign: TextAlign.center,
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handleForgotPassword(); // Recursive resend
                      },
                      child: Text(LocaleKeys.authResendResetEmail.tr()),
                    ),
                    SizedBox(width: context.w(2)),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: AppStyles.primaryButtonStyle.copyWith(
                        minimumSize: WidgetStateProperty.all(
                            Size(context.w(25), context.h(5))),
                      ),
                      child: Text(LocaleKeys.ok.tr()),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      } catch (e) {
        // Error is handled by AuthNotifier
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated && next.user != null) {
        if (next.user!.isPatient) {
          Navigator.of(context).pushReplacement(
            FadePageRoute(page: const PatientHomePage()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            FadePageRoute(page: const CaregiverHomePage()),
          );
        }
      } else if (next.status == AuthStatus.unverified) {
        Navigator.of(context).pushReplacement(
          FadePageRoute(page: const EmailVerificationPage()),
        );
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Curved Header
            Stack(
              children: [
                CustomPaint(
                  painter: HeaderPainter(),
                  child: SizedBox(
                    height: context.h(30),
                    width: double.infinity,
                  ),
                ),
                Positioned.directional(
                  textDirection: Directionality.of(context),
                  top: context.h(8),
                  start: context.w(8),
                  end: context.w(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.authLogin.tr(),
                        style: AppStyles.pageTitleStyle.copyWith(
                          fontSize: context.sp(32),
                        ),
                      ),
                      SizedBox(height: context.h(1)),
                      Text(
                        LocaleKeys.authWelcomeBack.tr(),
                        style: AppStyles.pageSubtitleStyle.copyWith(
                          fontSize: context.sp(18),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            Container(
              constraints: BoxConstraints(
                  maxWidth: context.w(90) > 400 ? 400 : context.w(90)),
              padding: EdgeInsets.symmetric(horizontal: context.w(8)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.h(1)),
                    Text(
                      LocaleKeys.authLoginToAccount.tr(),
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: context.sp(24),
                          ),
                    ),
                    SizedBox(height: context.h(4)),

                    // Email Field
                    _buildLabel(LocaleKeys.authEmail.tr()),
                    SizedBox(height: context.h(1)),
                    _buildInputField(
                      controller: _emailController,
                      hint: LocaleKeys.authEnterEmail.tr(),
                      customIcon:
                          AppIcons.email(color: AppColors.textSecondary),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        if (!value.contains('@')) {
                          return LocaleKeys.errorsInvalidEmail.tr();
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.h(3)),

                    // Password Field
                    _buildLabel(LocaleKeys.authPassword.tr()),
                    SizedBox(height: context.h(1)),
                    _buildInputField(
                      controller: _passwordController,
                      hint: LocaleKeys.authEnterPassword.tr(),
                      customIcon: AppIcons.password(
                          color: AppColors.textSecondary, size: context.sp(20)),
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onToggleVisibility: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        return null;
                      },
                    ),

                    // Forgot Password
                    SizedBox(height: context.h(1.5)),
                    Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: GestureDetector(
                        onTap: _handleForgotPassword,
                        child: Text(
                          LocaleKeys.authForgotPassword.tr(),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: context.h(3)),

                    // Login Button
                    ElevatedButton(
                      onPressed: isLoading ? null : _handleLogin,
                      style: AppStyles.primaryButtonStyle.copyWith(
                        minimumSize: WidgetStateProperty.all(
                            Size(double.infinity, context.h(7))),
                        shape: WidgetStateProperty.all(RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        )),
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: context.sp(24),
                              width: context.sp(24),
                              child: const CircularProgressIndicator(
                                  color: AppColors.white, strokeWidth: 2),
                            )
                          : Text(
                              LocaleKeys.authLogin.tr(),
                              style: TextStyle(
                                fontSize: context.sp(18),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),

                    SizedBox(height: context.h(3)),

                    // Divider
                    Row(
                      children: [
                        const Expanded(
                            child: Divider(
                                color: AppColors.borderGray, thickness: 1)),
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.w(4)),
                          child: Text(
                            LocaleKeys.authContinueWith.tr(),
                            style: TextStyle(
                                color: AppColors.mediumGray,
                                fontSize: context.sp(13)),
                          ),
                        ),
                        const Expanded(
                            child: Divider(
                                color: AppColors.borderGray, thickness: 1)),
                      ],
                    ),

                    SizedBox(height: context.h(3)),

                    // Google Login Button
                    Center(
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _handleGoogleSignIn,
                        style: AppStyles.secondaryButtonStyle.copyWith(
                          minimumSize: WidgetStateProperty.all(
                              Size(double.infinity, context.h(7))),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: const BorderSide(color: AppColors.border),
                          )),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: context.w(4)),
                                child: Image.network(
                                  AssetsConstants.googleLogoUrl,
                                  height: context.sp(20),
                                  width: context.sp(20),
                                ),
                              ),
                            ),
                            Text(
                              LocaleKeys.authContinueWithGoogle.tr(),
                              style: TextStyle(
                                fontSize: context.sp(16),
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: context.h(3)),

                    // Error Message
                    if (authState.status == AuthStatus.error)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.h(2.5)),
                        child: Container(
                          padding: EdgeInsets.all(context.w(3)),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.error,
                                color: AppColors.error,
                                size: context.sp(20),
                              ),
                              SizedBox(width: context.w(2)),
                              Expanded(
                                child: Text(
                                  authState.errorMessage ??
                                      LocaleKeys.errorsServerError.tr(),
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: context.sp(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    SizedBox(height: context.h(3)),

                    // Sign Up Link
                    Center(
                      child: GestureDetector(
                        onTap: () async {
                          final role = await _showRoleSelectionDialog();

                          if (role != null) {
                            if (!context.mounted) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RegisterPage(initialRole: role),
                              ),
                            );
                          }
                        },
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                color: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.color,
                                fontSize: context.sp(14)),
                            children: [
                              TextSpan(
                                text: "${LocaleKeys.authDontHaveAccount.tr()} ",
                              ),
                              TextSpan(
                                text: LocaleKeys.authSignUpNow.tr(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: context.sp(14),
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    Widget? customIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword && obscureText,
      validator: validator,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontSize: context.sp(16)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
        prefixIcon: customIcon != null
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: customIcon,
              )
            : (icon != null
                ? Icon(icon, color: Theme.of(context).iconTheme.color)
                : null),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? AppIcons.visibility : AppIcons.visibilityOff,
                  color: Theme.of(context).iconTheme.color,
                  size: context.sp(20),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
      ),
    );
  }

  Widget _buildRoleOption(
    BuildContext context, {
    String? iconPath,
    IconData? icon,
    required String title,
    required String subtitle,
    required String role,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, role),
      child: Container(
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).dividerColor,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(3)),
              decoration: BoxDecoration(
                color: AppColors.expertTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: iconPath != null
                  ? SvgPicture.asset(
                      iconPath,
                      height: context.sp(28),
                      width: context.sp(28),
                      colorFilter: const ColorFilter.mode(
                        AppColors.expertTeal,
                        BlendMode.srcIn,
                      ),
                    )
                  : Icon(icon,
                      color: AppColors.expertTeal, size: context.sp(28)),
            ),
            SizedBox(width: context.w(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.sp(16),
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: context.h(0.3)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.sp(12),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(AppIcons.forward,
                color: AppColors.mediumGray, size: context.sp(16)),
          ],
        ),
      ),
    );
  }
}

class HeaderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.expertTeal;

    final path = Path();
    path.lineTo(0, size.height * 0.7);
    path.quadraticBezierTo(
        size.width / 2, size.height, size.width, size.height * 0.7);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
