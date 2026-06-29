import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import 'medicine_tutorial_step2_page.dart';

/// Medicine Tutorial Step 1: Meet Your Smart Medicine Box
class MedicineTutorialStep1Page extends StatelessWidget {
  const MedicineTutorialStep1Page({super.key});

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Button
                    _buildIconButton(
                      context,
                      icon: Icons.arrow_back_ios_new_rounded,
                      onPressed: () => Navigator.of(context).pop(),
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

                        // Medicine Box Illustration
                        _buildMedicineBoxIllustration(context),

                        SizedBox(height: context.h(4)),

                        // Title
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: LocaleKeys.medicineTutorialMeetYour.tr(),
                                style: AppStyles.pageTitleStyle.copyWith(
                                  fontSize: context.sp(28),
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '\n${LocaleKeys.medicineTutorialSmartBox.tr()}',
                                style: AppStyles.pageTitleStyle.copyWith(
                                  color: AppColors.primary,
                                  fontSize: context.sp(32),
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),

                        SizedBox(height: context.h(2)),

                        // Description
                        Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: context.w(4)),
                          child: Text(
                            LocaleKeys.medicineTutorialDescription1.tr(),
                            style: AppStyles.bodyStyle.copyWith(
                              color: isDark
                                  ? AppColors.white.withValues(alpha: 0.7)
                                  : AppColors.textSecondary,
                              fontSize: context.sp(16),
                              height: 1.6,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        SizedBox(height: context.h(3)),

                        // Feature Pills
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildFeaturePill(
                              context,
                              icon: Icons.notifications_active_rounded,
                              label: LocaleKeys.medicineTutorialAlerts.tr(),
                              color: AppColors.info,
                            ),
                            SizedBox(width: context.w(3)),
                            _buildFeaturePill(
                              context,
                              icon: Icons.lightbulb_rounded,
                              label: LocaleKeys.medicineTutorialLighting.tr(),
                              color: AppColors.success,
                            ),
                          ],
                        ),

                        SizedBox(height: context.h(4)),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Column(
                  children: [
                    // Next Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicineTutorialStep2Page(),
                          ),
                        );
                      },
                      style: AppStyles.primaryButtonStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LocaleKeys.next.tr(),
                          ),
                          SizedBox(width: context.w(2)),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: context.sp(22),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.h(2)),

                    // Page Indicator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildPageIndicator(true),
                        SizedBox(width: context.w(2)),
                        _buildPageIndicator(false),
                        SizedBox(width: context.w(2)),
                        _buildPageIndicator(false),
                      ],
                    ),

                    SizedBox(height: context.h(1)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton(BuildContext context,
      {required IconData icon, required VoidCallback onPressed}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.white.withValues(alpha: 0.1)
            : AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: isDark ? AppColors.white : AppColors.primary,
          size: context.sp(22),
        ),
      ),
    );
  }

  Widget _buildMedicineBoxIllustration(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(context.w(8)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          // Main Box
          Container(
            padding: EdgeInsets.all(context.w(6)),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.primaryDark.withValues(alpha: 0.5)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top section with pill icon
                Container(
                  padding: EdgeInsets.all(context.w(4)),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.medication_rounded,
                    color: AppColors.white,
                    size: context.sp(60),
                  ),
                ),
                SizedBox(height: context.h(1.5)),
                // Drawer representation
                Container(
                  height: context.h(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Reminder Badge
          Positioned(
            top: -5,
            right: -5,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(3),
                vertical: context.h(0.5),
              ),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: Text(
                LocaleKeys.medicineTutorialReminder.tr(),
                style: TextStyle(
                  color: AppColors.white,
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturePill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: context.w(4),
        vertical: context.h(1),
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: context.sp(16),
          ),
          SizedBox(width: context.w(2)),
          Text(
            label,
            style: TextStyle(
              color: isDark ? AppColors.white : AppColors.textPrimary,
              fontSize: context.sp(14),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(bool isActive) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: isActive ? 24 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : (isDark
                  ? AppColors.white.withValues(alpha: 0.2)
                  : AppColors.primary.withValues(alpha: 0.2)),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    });
  }
}
