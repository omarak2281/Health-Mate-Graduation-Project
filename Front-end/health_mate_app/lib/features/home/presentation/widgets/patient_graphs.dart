import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_colors.dart';

/// Blood Pressure Trend Card Widget
/// Displays a placeholder for BP history graph
class BloodPressureTrendCard extends StatelessWidget {
  const BloodPressureTrendCard({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2.5)),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.show_chart,
                  color: isDark ? Colors.white : Theme.of(context).primaryColor,
                  size: context.sp(22),
                ),
              ),
              SizedBox(width: context.w(3)),
              Text(
                LocaleKeys.vitalsBpTrend.tr(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : null,
                    ),
              ),
            ],
          ),
          SizedBox(height: context.h(3)),

          // Placeholder Graph Area
          Container(
            height: context.h(20),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart_rounded,
                    size: context.sp(48),
                    color: Theme.of(context)
                        .unselectedWidgetColor
                        .withValues(alpha: 0.3),
                  ),
                  SizedBox(height: context.h(1)),
                  Text(
                    LocaleKeys.vitalsNoReadings.tr(),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontSize: context.sp(14),
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
}
