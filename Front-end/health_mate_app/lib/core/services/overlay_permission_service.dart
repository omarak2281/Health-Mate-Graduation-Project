import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:easy_localization/easy_localization.dart';
import '../constants/locale_keys.dart';
import '../theme/app_colors.dart';

/// Handles the "Display Over Other Apps" (System Alert Window) permission.
class OverlayPermissionService {
  static const String _prefKey = 'overlay_permission_prompted';

  static final OverlayPermissionService instance = OverlayPermissionService._();
  OverlayPermissionService._();

  /// Checks if overlay permission is granted.
  Future<bool> isGranted() async {
    return await Permission.systemAlertWindow.isGranted;
  }

  /// Main entry point: called on app startup.
  Future<void> requestIfNeeded(BuildContext context) async {
    if (await isGranted()) {
      debugPrint('✅ Overlay permission already granted.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    const promptVersion = 'v2';
    final promptKey = '${_prefKey}_$promptVersion';
    final hasBeenPrompted = prefs.getBool(promptKey) ?? false;

    if (hasBeenPrompted) {
      debugPrint(
          'ℹ️ Overlay permission prompt already shown before. Skipping.');
      return;
    }

    await prefs.setBool(promptKey, true);

    if (context.mounted) {
      await _showExplanationDialog(context);
    }
  }

  Future<void> _showExplanationDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.alarm_rounded,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                LocaleKeys.permissionsOverlayTitle.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              LocaleKeys.permissionsOverlayDescription.tr(),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.white70 : AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              isDark: isDark,
              icon: Icons.layers_rounded,
              text: LocaleKeys.permissionsOverlayItemTitle.tr(),
              description: LocaleKeys.permissionsOverlayItemDesc.tr(),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      LocaleKeys.permissionsOverlayInstruction.tr(),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? AppColors.primary : AppColors.primaryDark,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              LocaleKeys.permissionsLater.tr(),
              style: TextStyle(
                color: isDark ? AppColors.white38 : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.settings_rounded, size: 16),
                const SizedBox(width: 6),
                Text(
                  LocaleKeys.permissionsGrantPermission.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionItem({
    required bool isDark,
    required IconData icon,
    required String text,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.white54 : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
