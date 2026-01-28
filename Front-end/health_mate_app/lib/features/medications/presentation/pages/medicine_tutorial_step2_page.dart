import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import 'medicine_tutorial_step3_page.dart';

/// Medicine Tutorial Step 2: Fill the Drawer
class MedicineTutorialStep2Page extends StatelessWidget {
  const MedicineTutorialStep2Page({super.key});

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
              crossAxisAlignment: CrossAxisAlignment.center,
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
                    // Title
                    Text(
                      LocaleKeys.medicineTutorialSmartBoxSetup.tr(),
                      style: AppStyles.headingStyle.copyWith(
                        color: isDark ? AppColors.white : AppColors.primary,
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // Removed Language Toggle for cleaner UI
                    const SizedBox(width: 48), // Spacer to maintain alignment
                  ],
                ),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        SizedBox(height: context.h(3)),

                        // Progress Indicator
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildProgressIndicator(true, 60),
                            SizedBox(width: context.w(2)),
                            _buildProgressIndicator(false, 40),
                            SizedBox(width: context.w(2)),
                            _buildProgressIndicator(false, 40),
                          ],
                        ),

                        SizedBox(height: context.h(4)),

                        // Drawer Grid Illustration
                        _buildDrawerGrid(context),

                        SizedBox(height: context.h(4)),

                        // Title
                        Text(
                          LocaleKeys.medicineTutorialFillDrawer.tr(),
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
                          child: Text(
                            LocaleKeys.medicineTutorialDescription2.tr(),
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

                        SizedBox(height: context.h(4)),
                      ],
                    ),
                  ),
                ),

                // Footer Actions
                Column(
                  children: [
                    // Next Step Button
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MedicineTutorialStep3Page(),
                          ),
                        );
                      },
                      style: AppStyles.primaryButtonStyle,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            LocaleKeys.medicineTutorialNextStep.tr(),
                          ),
                          SizedBox(width: context.w(2)),
                          Icon(
                            Icons.arrow_forward_rounded,
                            size: context.sp(22),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: context.h(1)),

                    // Skip Tutorial
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const MedicineTutorialStep3Page(),
                          ),
                        );
                      },
                      child: Text(
                        LocaleKeys.medicineTutorialSkip.tr(),
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

  Widget _buildProgressIndicator(bool isActive, double width) {
    return Builder(builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        width: width,
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

  Widget _buildDrawerGrid(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.all(context.w(6)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.1)
              : AppColors.primary.withValues(alpha: 0.1),
          width: 2,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row
          Row(
            children: [
              _buildDrawerSlot(
                context,
                label: LocaleKeys.medicineTutorialMorning.tr().toUpperCase(),
                isAssigned: true,
                showCheckmark: true,
              ),
              SizedBox(width: context.w(4)),
              _buildDrawerSlot(
                context,
                label: LocaleKeys.medicineTutorialNoon.tr().toUpperCase(),
                isHighlighted: true,
                showPlusIcon: true,
              ),
            ],
          ),
          SizedBox(height: context.h(2)),
          // Bottom Row
          Row(
            children: [
              _buildDrawerSlot(
                context,
                label: LocaleKeys.medicineTutorialEvening.tr().toUpperCase(),
                isAssigned: false,
                showPlusIcon: true,
              ),
              SizedBox(width: context.w(4)),
              _buildDrawerSlot(
                context,
                label: LocaleKeys.medicineTutorialNight.tr().toUpperCase(),
                isAssigned: false,
                showPlusIcon: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerSlot(
    BuildContext context, {
    required String label,
    bool isAssigned = false,
    bool isHighlighted = false,
    bool showCheckmark = false,
    bool showPlusIcon = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        height: context.h(16),
        decoration: BoxDecoration(
          color: isDark
              ? (isAssigned
                  ? AppColors.primary.withValues(alpha: 0.2)
                  : AppColors.white.withValues(alpha: 0.05))
              : (isAssigned
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.white),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isHighlighted
                ? AppColors.primary
                : (isDark
                    ? AppColors.white.withValues(alpha: 0.1)
                    : AppColors.border),
            width: isHighlighted ? 2 : 1.5,
          ),
          boxShadow: [
            if (!isDark)
              BoxShadow(
                color: AppColors.shadow.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Label
            Text(
              label,
              style: TextStyle(
                color: isHighlighted
                    ? (isDark ? AppColors.primaryLight : AppColors.primary)
                    : (isDark
                        ? AppColors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary),
                fontSize: context.sp(10),
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: context.h(1)),
            // Icon
            if (showCheckmark)
              Container(
                padding: EdgeInsets.all(context.w(2)),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: AppColors.white,
                  size: context.sp(16),
                ),
              )
            else if (showPlusIcon)
              Container(
                padding: EdgeInsets.all(context.w(2)),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? AppColors.primary.withValues(alpha: 0.1)
                      : (isDark
                          ? AppColors.white.withValues(alpha: 0.05)
                          : AppColors.backgroundLight),
                  shape: BoxShape.circle,
                  border: isHighlighted
                      ? Border.all(
                          color: AppColors.primary,
                          width: 2,
                        )
                      : null,
                ),
                child: Icon(
                  Icons.add_rounded,
                  color: isHighlighted
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.white.withValues(alpha: 0.2)
                          : AppColors.textSecondary),
                  size: context.sp(20),
                ),
              ),
            SizedBox(height: context.h(1)),
            // Status Text
            if (isAssigned)
              Text(
                LocaleKeys.medicineTutorialAssigned.tr(),
                style: TextStyle(
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.bold,
                ),
              )
            else if (isHighlighted)
              Text(
                LocaleKeys.medicineTutorialAssignMeds.tr(),
                style: TextStyle(
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  fontSize: context.sp(11),
                  fontWeight: FontWeight.bold,
                ),
              )
            else
              Text(
                LocaleKeys.medicineTutorialEmpty.tr(),
                style: TextStyle(
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.3)
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                  fontSize: context.sp(12),
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
