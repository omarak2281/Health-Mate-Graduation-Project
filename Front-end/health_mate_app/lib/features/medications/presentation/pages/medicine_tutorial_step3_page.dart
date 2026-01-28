import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/storage/shared_prefs_cache.dart';

/// Medicine Tutorial Step 3: Smart Notifications
class MedicineTutorialStep3Page extends ConsumerWidget {
  const MedicineTutorialStep3Page({super.key});

  Future<void> _finishSetup(BuildContext context, WidgetRef ref) async {
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);

    // Mark tutorial as seen
    await sharedPrefs.setMedicineTutorialCompleted(true);

    if (context.mounted) {
      // Navigate to medications page (or pop back)
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.primaryDark, AppColors.backgroundDark]
                : [
                    AppColors.primary.withValues(alpha: 0.05),
                    AppColors.pageBackground
                  ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: context.w(6),
              vertical: context.h(2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Step Indicator
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: context.w(4), vertical: context.h(1)),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.1)
                            : AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        LocaleKeys.medicineTutorialStep3.tr(),
                        style: AppStyles.labelStyle.copyWith(
                          color: isDark ? AppColors.white : AppColors.primary,
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Removed Language Toggle for cleaner UI
                    const SizedBox(width: 48),
                  ],
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: context.h(4)),

                        // Notification Illustration
                        _buildNotificationIllustration(context),

                        SizedBox(height: context.h(4)),

                        // Title
                        Text(
                          LocaleKeys.medicineTutorialSmartNotifications.tr(),
                          style: AppStyles.pageTitleStyle.copyWith(
                            color: isDark
                                ? AppColors.white
                                : AppColors.textPrimary,
                            fontSize: context.sp(28),
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: context.h(2)),

                        // Description
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.w(4)),
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: LocaleKeys
                                      .medicineTutorialDescription3Part1
                                      .tr(),
                                  style: AppStyles.bodyStyle.copyWith(
                                    color: isDark
                                        ? AppColors.white.withValues(alpha: 0.7)
                                        : AppColors.textSecondary,
                                    fontSize: context.sp(16),
                                    height: 1.6,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ' ${LocaleKeys.medicineTutorialLightUp.tr()} ',
                                  style: AppStyles.bodyStyle.copyWith(
                                    color: isDark
                                        ? AppColors.primaryLight
                                        : AppColors.primary,
                                    fontSize: context.sp(16),
                                    fontWeight: FontWeight.bold,
                                    height: 1.6,
                                  ),
                                ),
                                TextSpan(
                                  text: LocaleKeys
                                      .medicineTutorialDescription3Part2
                                      .tr(),
                                  style: AppStyles.bodyStyle.copyWith(
                                    color: isDark
                                        ? AppColors.white.withValues(alpha: 0.7)
                                        : AppColors.textSecondary,
                                    fontSize: context.sp(16),
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        SizedBox(height: context.h(4)),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Column(
                  children: [
                    // Page Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPageIndicator(false),
                        SizedBox(width: context.w(2)),
                        _buildPageIndicator(false),
                        SizedBox(width: context.w(2)),
                        _buildPageIndicator(true),
                      ],
                    ),

                    SizedBox(height: context.h(3)),

                    // Finish Setup Button
                    ElevatedButton(
                      onPressed: () => _finishSetup(context, ref),
                      style: AppStyles.primaryButtonStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LocaleKeys.medicineTutorialFinishSetup.tr(),
                          ),
                          SizedBox(width: context.w(2)),
                          Icon(
                            Icons.check_circle_rounded,
                            size: context.sp(22),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.h(1)),

                    // Replay Tutorial
                    TextButton(
                      onPressed: () {
                        Navigator.of(context)
                            .popUntil((route) => route.isFirst);
                      },
                      child: Text(
                        LocaleKeys.medicineTutorialReplay.tr(),
                        style: AppStyles.labelStyle.copyWith(
                          color: isDark
                              ? AppColors.white.withValues(alpha: 0.5)
                              : AppColors.textSecondary,
                          fontSize: context.sp(14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: isActive ? 24 : 8,
        height: 6,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    });
  }

  Widget _buildNotificationIllustration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      height: context.h(32),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Medicine Box (background)
          Positioned(
            bottom: 0,
            left: context.w(5),
            child: Container(
              width: context.w(40),
              height: context.h(20),
              padding: EdgeInsets.all(context.w(3)),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primaryDark.withValues(alpha: 0.6)
                    : AppColors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.1)
                      : AppColors.border,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.shadow.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildMiniDrawer(context, isLit: false),
                      SizedBox(width: context.w(2)),
                      _buildMiniDrawer(context, isLit: false),
                    ],
                  ),
                  SizedBox(height: context.h(1)),
                  Row(
                    children: [
                      _buildMiniDrawer(context, isLit: true),
                      SizedBox(width: context.w(2)),
                      _buildMiniDrawer(context, isLit: false),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Phone Notification (foreground)
          Positioned(
            top: 0,
            right: context.w(5),
            child: Container(
              width: context.w(45),
              height: context.h(28),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.1)
                      : AppColors.primary.withValues(alpha: 0.2),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Status bar area
                  Container(
                    height: context.h(2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.primaryDark.withValues(alpha: 0.5)
                          : AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(22),
                        topRight: Radius.circular(22),
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(3)),
                  // Notification Card
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: context.w(3)),
                    padding: EdgeInsets.all(context.w(3)),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Bell Icon
                        Container(
                          padding: EdgeInsets.all(context.w(2)),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            color: AppColors.white,
                            size: context.sp(14),
                          ),
                        ),
                        SizedBox(width: context.w(2)),
                        // Notification lines (simulated text)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 3,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              SizedBox(height: context.h(0.5)),
                              Container(
                                height: 3,
                                width: context.w(20),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.white.withValues(alpha: 0.5)
                                      : AppColors.textSecondary,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniDrawer(BuildContext context, {required bool isLit}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: context.h(7),
        decoration: BoxDecoration(
          color: isLit
              ? AppColors.primary.withValues(alpha: 0.2)
              : (isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.8)
                  : AppColors.backgroundLight),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isLit
                ? AppColors.primary
                : (isDark
                    ? AppColors.white.withValues(alpha: 0.1)
                    : AppColors.border),
            width: 1.5,
          ),
          boxShadow: isLit
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: isLit
            ? Center(
                child: Icon(
                  Icons.medication_rounded,
                  color: AppColors.primary,
                  size: context.sp(20),
                ),
              )
            : null,
      ),
    );
  }
}
