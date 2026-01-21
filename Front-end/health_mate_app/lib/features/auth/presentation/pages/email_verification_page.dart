import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/auth_provider.dart';
import 'splash_page.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    // Refresh status when page opens
    Future.microtask(
      () => ref.read(authNotifierProvider.notifier).checkVerificationStatus(),
    );
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await ref.read(authNotifierProvider.notifier).resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'auth.verification_sent'.tr(
                namedArgs: {
                  'email': ref.read(authNotifierProvider).user?.email ?? '',
                },
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.authenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()),
          (route) => false,
        );
      }
    });

    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.authVerifyEmail.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            icon: AppIcons.logout(size: context.sp(24)),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(6)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mark_email_read_outlined,
                size: context.sp(100),
                color: AppColors.primary,
              ),
              SizedBox(height: context.h(4)),
              Text(
                LocaleKeys.authVerifyEmail.tr(),
                style: TextStyle(
                  fontSize: context.sp(24),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(2)),
              Text(
                LocaleKeys.authVerificationSent.tr(
                  namedArgs: {'email': authState.user?.email ?? ''},
                ),
                style: TextStyle(
                  fontSize: context.sp(16),
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: context.h(5)),
              if (authState.errorMessage != null)
                Padding(
                  padding: EdgeInsets.only(bottom: context.h(3)),
                  child: Container(
                    padding: EdgeInsets.all(context.w(3)),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(AppIcons.error,
                            color: AppColors.error, size: context.sp(20)),
                        SizedBox(width: context.w(2)),
                        Expanded(
                          child: Text(
                            authState.errorMessage!,
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
              SizedBox(
                width: double.infinity,
                height: context.h(6.5),
                child: ElevatedButton(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : () => ref
                          .read(authNotifierProvider.notifier)
                          .checkVerificationStatus(),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: authState.status == AuthStatus.loading
                      ? SizedBox(
                          height: context.sp(24),
                          width: context.sp(24),
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          LocaleKeys.authCheckVerification.tr(),
                          style: TextStyle(
                              fontSize: context.sp(16),
                              fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              SizedBox(height: context.h(2)),
              TextButton(
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? SizedBox(
                        height: context.sp(20),
                        width: context.sp(20),
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        LocaleKeys.authResendEmail.tr(),
                        style: TextStyle(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
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
