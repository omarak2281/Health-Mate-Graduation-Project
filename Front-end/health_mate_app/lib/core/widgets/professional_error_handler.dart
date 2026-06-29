import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

/// Professional Error Handler Widget
/// Provides consistent error display across the app
class ProfessionalErrorHandler {
  ProfessionalErrorHandler._();

  /// Shows a professional error dialog with clear user guidance
  static void showErrorDialog({
    required BuildContext context,
    required String titleKey,
    required String messageKey,
    String? subtitleKey,
    VoidCallback? onRetry,
    VoidCallback? onDismiss,
    bool showRetry = false,
    String? customActionText,
  }) {
    showDialog(
      context: context,
      barrierDismissible: onDismiss != null,
      builder: (context) => _ErrorDialog(
        titleKey: titleKey,
        messageKey: messageKey,
        subtitleKey: subtitleKey,
        onRetry: onRetry,
        onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
        showRetry: showRetry,
        customActionText: customActionText,
      ),
    );
  }

  /// Shows a professional error snackbar with actionable guidance
  static void showErrorSnackBar({
    required BuildContext context,
    required String messageKey,
    Duration duration = const Duration(seconds: 5),
    VoidCallback? action,
    String? actionText,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: Colors.transparent,
        elevation: 0,
        content: Container(
          padding: EdgeInsets.all(context.w(4)),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.error.withValues(alpha: 0.95),
                AppColors.error.withValues(alpha: 0.85),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.error.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2)),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Colors.white,
                  size: context.w(6),
                ),
              ),
              SizedBox(width: context.w(3)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'error_occurred'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: context.h(0.3)),
                    Text(
                      _getClearErrorMessage(messageKey),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: context.sp(12),
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[
                SizedBox(width: context.w(2)),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    action();
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(3),
                      vertical: context.h(1),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      actionText ?? 'retry'.tr(),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Shows a warning dialog with clear options
  static void showWarningDialog({
    required BuildContext context,
    required String titleKey,
    required String messageKey,
    VoidCallback? onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
  }) {
    showDialog(
      context: context,
      builder: (context) => _WarningDialog(
        titleKey: titleKey,
        messageKey: messageKey,
        onConfirm: onConfirm ?? () => Navigator.of(context).pop(),
        onCancel: onCancel ?? () => Navigator.of(context).pop(),
        confirmText: confirmText,
        cancelText: cancelText,
      ),
    );
  }

  /// Shows a success dialog
  static void showSuccessDialog({
    required BuildContext context,
    required String titleKey,
    required String messageKey,
    VoidCallback? onDismiss,
  }) {
    showDialog(
      context: context,
      builder: (context) => _SuccessDialog(
        titleKey: titleKey,
        messageKey: messageKey,
        onDismiss: onDismiss ?? () => Navigator.of(context).pop(),
      ),
    );
  }

  /// Converts error keys to clear, user-friendly messages
  static String _getClearErrorMessage(String messageKey) {
    // Map error keys to clear user messages
    final clearMessages = {
      'errors.servers_busy':
          'Our servers are currently busy. Please try again in a moment.',
      'errors.connection_timeout':
          'Connection timed out. Please check your internet connection.',
      'errors.network_error':
          'Network connection failed. Please check your internet settings.',
      'errors.service_unavailable':
          'This service is temporarily unavailable. Please try again later.',
      'errors.symptom_analysis_failed':
          'Unable to analyze symptoms. Please try again.',
      'errors.categories_load_failed':
          'Could not load medical categories. Please refresh.',
      'errors.no_symptoms_selected':
          'Please select at least one symptom to continue.',
      'errors.invalid_symptom_data':
          'Invalid symptom data provided. Please try again.',
      'errors.model_unavailable':
          'AI model is currently unavailable. Please try again later.',
      'errors.unauthorized': 'Please login to access this feature.',
      'errors.too_many_requests':
          'Too many requests. Please wait a moment and try again.',
      'errors.unknown_error': 'Something went wrong. Please try again.',
      'errors.please_try_again': 'Please try again.',
    };

    return clearMessages[messageKey] ?? messageKey.tr();
  }
}

/// Custom Error Dialog Widget
class _ErrorDialog extends StatelessWidget {
  final String titleKey;
  final String messageKey;
  final String? subtitleKey;
  final VoidCallback? onRetry;
  final VoidCallback onDismiss;
  final bool showRetry;
  final String? customActionText;

  const _ErrorDialog({
    required this.titleKey,
    required this.messageKey,
    this.subtitleKey,
    this.onRetry,
    required this.onDismiss,
    this.showRetry = false,
    this.customActionText,
  });

  @override
  Widget build(BuildContext context) {
    final clearMessage =
        ProfessionalErrorHandler._getClearErrorMessage(messageKey);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(context.w(5)),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1e293b)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error Icon with animation
            Container(
              width: context.w(20),
              height: context.w(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.error.withValues(alpha: 0.2),
                    AppColors.error.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                _getErrorIcon(titleKey),
                color: AppColors.error,
                size: context.w(10),
              ),
            ),
            SizedBox(height: context.h(3)),

            // Clear, user-friendly title
            Text(
              _getClearTitle(titleKey),
              style: TextStyle(
                fontSize: context.sp(20),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(1.5)),

            // Clear error message
            Text(
              clearMessage,
              style: TextStyle(
                fontSize: context.sp(16),
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),

            // Helpful subtitle with guidance
            if (subtitleKey != null) ...[
              SizedBox(height: context.h(1)),
              Container(
                padding: EdgeInsets.all(context.w(3)),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.info.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.info,
                      size: context.w(5),
                    ),
                    SizedBox(width: context.w(2)),
                    Expanded(
                      child: Text(
                        subtitleKey!.tr(),
                        style: TextStyle(
                          fontSize: context.sp(14),
                          color: AppColors.info,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            SizedBox(height: context.h(4)),

            // Action Buttons with clear labels
            Row(
              children: [
                if (showRetry && onRetry != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: context.h(2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: AppColors.error),
                      ),
                      child: Text(
                        customActionText ?? 'try_again'.tr(),
                        style: TextStyle(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: context.w(3)),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: onDismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: EdgeInsets.symmetric(vertical: context.h(2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'understood'.tr(),
                      style: TextStyle(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns appropriate icon based on error type
  IconData _getErrorIcon(String titleKey) {
    if (titleKey.contains('connection') || titleKey.contains('network')) {
      return Icons.wifi_off;
    } else if (titleKey.contains('server') || titleKey.contains('busy')) {
      return Icons.cloud_off;
    } else if (titleKey.contains('unauthorized') ||
        titleKey.contains('login')) {
      return Icons.lock;
    } else if (titleKey.contains('timeout')) {
      return Icons.timer_off;
    } else {
      return Icons.error_outline;
    }
  }

  /// Returns clear, user-friendly title
  String _getClearTitle(String titleKey) {
    final clearTitles = {
      'connection_error': 'Connection Problem',
      'server_error': 'Server Issue',
      'service_unavailable': 'Service Unavailable',
      'connection_timeout': 'Connection Timeout',
      'network_error': 'Network Error',
      'bad_request': 'Invalid Request',
      'unauthorized': 'Access Required',
      'forbidden': 'Access Denied',
      'not_found': 'Service Not Found',
      'too_many_requests': 'Too Many Requests',
      'http_error': 'Connection Error',
      'data_error': 'Data Problem',
      'unexpected_error': 'Unexpected Issue',
      'no_symptoms_selected': 'Selection Required',
      'error_loading_data': 'Loading Error',
      'analysis_error': 'Analysis Failed',
    };

    return clearTitles[titleKey] ?? 'Error Occurred';
  }
}

/// Custom Warning Dialog Widget
class _WarningDialog extends StatelessWidget {
  final String titleKey;
  final String messageKey;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;
  final String? confirmText;
  final String? cancelText;

  const _WarningDialog({
    required this.titleKey,
    required this.messageKey,
    required this.onConfirm,
    required this.onCancel,
    this.confirmText,
    this.cancelText,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(context.w(5)),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1e293b)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.warning.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.w(20),
              height: context.w(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.warning.withValues(alpha: 0.2),
                    AppColors.warning.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.warning_amber,
                color: AppColors.warning,
                size: context.w(10),
              ),
            ),
            SizedBox(height: context.h(3)),
            Text(
              _getClearWarningTitle(titleKey),
              style: TextStyle(
                fontSize: context.sp(20),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(1.5)),
            Text(
              messageKey.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(4)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: context.h(2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: BorderSide(color: AppColors.warning),
                    ),
                    child: Text(
                      cancelText ?? 'cancel'.tr(),
                      style: TextStyle(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: context.w(3)),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onConfirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      padding: EdgeInsets.symmetric(vertical: context.h(2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      confirmText ?? 'continue'.tr(),
                      style: TextStyle(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Returns clear, user-friendly warning title
  String _getClearWarningTitle(String titleKey) {
    final clearTitles = {
      'no_symptoms_selected': 'No Symptoms Selected',
      'confirm_action': 'Confirm Action',
      'warning': 'Warning',
    };

    return clearTitles[titleKey] ?? titleKey.tr();
  }
}

/// Custom Success Dialog Widget
class _SuccessDialog extends StatelessWidget {
  final String titleKey;
  final String messageKey;
  final VoidCallback onDismiss;

  const _SuccessDialog({
    required this.titleKey,
    required this.messageKey,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: EdgeInsets.all(context.w(5)),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1e293b)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.success.withValues(alpha: 0.2),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: context.w(20),
              height: context.w(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.success.withValues(alpha: 0.2),
                    AppColors.success.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: AppColors.success.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: context.w(10),
              ),
            ),
            SizedBox(height: context.h(3)),
            Text(
              titleKey.tr(),
              style: TextStyle(
                fontSize: context.sp(20),
                fontWeight: FontWeight.bold,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(1.5)),
            Text(
              messageKey.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                color: Colors.grey[600],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(4)),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  padding: EdgeInsets.symmetric(vertical: context.h(2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'ok'.tr(),
                  style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
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
