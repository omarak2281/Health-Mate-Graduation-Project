import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
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
    final theme = Theme.of(context);

    // If suddenly authenticated, the router should take over,
    // but we can also show a success state here.

    return Scaffold(
      appBar: AppBar(
        title: Text('auth.verify_email'.tr()),
        actions: [
          IconButton(
            onPressed: () => ref.read(authNotifierProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.mark_email_read_outlined,
                size: 100,
                color: Colors.blue,
              ),
              const SizedBox(height: 32),
              Text(
                'auth.verify_email'.tr(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'auth.verification_sent'.tr(
                  namedArgs: {'email': authState.user?.email ?? ''},
                ),
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              if (authState.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: authState.status == AuthStatus.loading
                      ? null
                      : () => ref
                            .read(authNotifierProvider.notifier)
                            .checkVerificationStatus(),
                  child: authState.status == AuthStatus.loading
                      ? const CircularProgressIndicator()
                      : Text('auth.check_verification'.tr()),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isResending ? null : _resendEmail,
                child: _isResending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('auth.resend_email'.tr()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
