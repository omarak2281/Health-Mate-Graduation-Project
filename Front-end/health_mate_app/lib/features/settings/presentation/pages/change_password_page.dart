import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      await ref.read(authNotifierProvider.notifier).changePassword(
            oldPassword: _oldPasswordController.text,
            newPassword: _newPasswordController.text,
          );

      if (mounted &&
          ref.read(authNotifierProvider).status != AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.authPasswordChangedSuccess.tr(),
                style: TextStyle(fontSize: context.sp(14))),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final user = ref.read(authNotifierProvider).user;
    if (user?.email == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LocaleKeys.authForgotPassword.tr()),
        content: Text(LocaleKeys.authResetPasswordInstruction.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(LocaleKeys.confirm.tr(),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ref
            .read(authNotifierProvider.notifier)
            .resetPassword(user!.email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LocaleKeys.authResetPasswordSent.tr(),
                  style: TextStyle(fontSize: context.sp(14))),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.settingsChangePassword.tr(),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.pageBackground,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.w(6),
            ExpertAppBar.getAppBarPadding(context),
            context.w(6),
            context.h(4),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderIcon(isDark),
                SizedBox(height: context.h(4)),

                Container(
                  padding: EdgeInsets.all(context.w(5)),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                    border:
                        isDark ? Border.all(color: AppColors.borderDark) : null,
                  ),
                  child: Column(
                    children: [
                      // Current Password
                      _buildPasswordField(
                        controller: _oldPasswordController,
                        label: LocaleKeys.authCurrentPassword.tr(),
                        obscureText: _obscureOld,
                        onToggle: () =>
                            setState(() => _obscureOld = !_obscureOld),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return LocaleKeys.errorsRequiredField.tr();
                          }
                          return null;
                        },
                      ),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _handleForgotPassword,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            LocaleKeys.authForgotPassword.tr(),
                            style: TextStyle(
                              fontSize: context.sp(13),
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: context.h(2)),
                      Divider(color: AppColors.border.withValues(alpha: 0.1)),
                      SizedBox(height: context.h(2)),

                      // New Password
                      _buildPasswordField(
                        controller: _newPasswordController,
                        label: LocaleKeys.authNewPassword.tr(),
                        obscureText: _obscureNew,
                        onToggle: () =>
                            setState(() => _obscureNew = !_obscureNew),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return LocaleKeys.errorsRequiredField.tr();
                          }
                          if (value.length < 8) {
                            return LocaleKeys.errorsPasswordTooShort.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: context.h(2.5)),

                      // Confirm New Password
                      _buildPasswordField(
                        controller: _confirmPasswordController,
                        label: LocaleKeys.authConfirmNewPassword.tr(),
                        obscureText: _obscureConfirm,
                        onToggle: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                        validator: (value) {
                          if (value != _newPasswordController.text) {
                            return LocaleKeys.errorsPasswordsDontMatch.tr();
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.h(6)),

                // Action Buttons
                ElevatedButton(
                  onPressed: isLoading ? null : _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    minimumSize: Size(double.infinity, context.h(6.5)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: isLoading
                      ? SizedBox(
                          height: context.sp(24),
                          width: context.sp(24),
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : Text(
                          LocaleKeys.settingsChangePassword.tr().toUpperCase(),
                          style: TextStyle(
                            fontSize: context.sp(16),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                ),

                // Error Message
                if (authState.status == AuthStatus.error)
                  Padding(
                    padding: EdgeInsets.only(top: context.h(3)),
                    child: Container(
                      padding: EdgeInsets.all(context.w(4)),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppColors.error.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: AppColors.error, size: context.sp(20)),
                          SizedBox(width: context.w(3)),
                          Expanded(
                            child: Text(
                              authState.errorMessage ??
                                  LocaleKeys.errorsSomethingWentWrong.tr(),
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(bool isDark) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.lock_reset_rounded,
          size: context.sp(60),
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscureText,
    required VoidCallback onToggle,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: TextStyle(
        fontSize: context.sp(16),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: context.sp(14),
        ),
        prefixIcon: Icon(
          Icons.lock_outline_rounded,
          color: AppColors.primary.withValues(alpha: 0.7),
          size: context.sp(22),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: AppColors.textSecondary.withValues(alpha: 0.6),
            size: context.sp(20),
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark.withValues(alpha: 0.3)
            : AppColors.backgroundLight.withValues(alpha: 0.5),
      ),
      validator: validator,
    );
  }
}
