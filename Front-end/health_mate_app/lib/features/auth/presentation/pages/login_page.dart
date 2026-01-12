import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/auth_provider.dart';
import 'register_page.dart';
import 'email_verification_page.dart';

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
      await ref
          .read(authNotifierProvider.notifier)
          .login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Social auth requires a role for new users
    final role = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.authSelectRole.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(LocaleKeys.authPatient.tr()),
              onTap: () => Navigator.pop(context, 'patient'),
            ),
            ListTile(
              title: Text(LocaleKeys.authCaregiver.tr()),
              onTap: () => Navigator.pop(context, 'caregiver'),
            ),
          ],
        ),
      ),
    );

    if (role != null) {
      await ref.read(authNotifierProvider.notifier).loginWithGoogle(role: role);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Listen for unverified state
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.unverified) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const EmailVerificationPage()),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  const Icon(
                    Icons.favorite_rounded,
                    size: 80,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    LocaleKeys.authLogin.tr(),
                    style: Theme.of(context).textTheme.displayMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    LocaleKeys.appNameArabic.tr(),
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.authEmail.tr(),
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
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
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: LocaleKeys.authPassword.tr(),
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return LocaleKeys.errorsRequiredField.tr();
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Error Message
                  if (authState.status == AuthStatus.error)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        authState.errorMessage ??
                            LocaleKeys.errorsServerError.tr(),
                        style: const TextStyle(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (authState.status == AuthStatus.error)
                    const SizedBox(height: 16),

                  // Login Button
                  ElevatedButton(
                    onPressed: isLoading ? null : _handleLogin,
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(LocaleKeys.authLogin.tr()),
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider()),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Google Sign In
                  OutlinedButton.icon(
                    onPressed: isLoading ? null : _handleGoogleSignIn,
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png',
                      height: 20,
                    ),
                    label: Text(LocaleKeys.authGoogleSignIn.tr()),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Register Link
                  TextButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            // Clear any existing errors before navigating
                            ref
                                .read(authNotifierProvider.notifier)
                                .clearError();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RegisterPage(),
                              ),
                            );
                          },
                    child: Text(LocaleKeys.authRegister.tr()),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
