import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_styles.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/constants/locale_keys.dart';
import '../../../../../core/models/medication.dart';

class DrawerTile extends StatelessWidget {
  final int number;
  final Medication? medication;
  final bool isDark;

  const DrawerTile({
    super.key,
    required this.number,
    this.medication,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAssigned = medication != null;

    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: isAssigned
            ? AppColors.expertTeal
            : (isDark ? AppColors.cardDark : AppColors.white),
        borderRadius: AppDimensions.borderMedium,
        border: Border.all(
          color: isAssigned
              ? AppColors.expertTeal
              : AppColors.border.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          if (isAssigned)
            BoxShadow(
              color: AppColors.expertTeal.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildNumberBadge(isAssigned),
          const Spacer(),
          if (isAssigned)
            _buildMedicationInfo(context)
          else
            _buildEmptyState(context),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(bool isAssigned) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isAssigned
            ? Colors.white.withValues(alpha: 0.2)
            : AppColors.border.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '$number',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isAssigned ? AppColors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medication!.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.cardTitleStyle.copyWith(
            fontSize: context.sp(16),
            color: AppColors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          LocaleKeys.medicationsMedicationSummary.tr(
            namedArgs: {
              'dosage': medication!.dosage,
              'frequency': '${medication!.timesPerDay} times daily',
            },
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppStyles.labelStyle.copyWith(
            fontSize: context.sp(12),
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            LocaleKeys.commonNotAvailable
                .tr(), // Using "N/A" or could use a new key like "Empty"
            style: AppStyles.labelStyle.copyWith(
              fontSize: context.sp(14),
              color: AppColors.textSecondary.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
