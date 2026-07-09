import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/assessment_entities.dart';

class RedFlagBanner extends StatelessWidget {
  final List<RedFlagEntity> redFlags;

  const RedFlagBanner({super.key, required this.redFlags});

  @override
  Widget build(BuildContext context) {
    if (redFlags.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.riskCritical.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.riskCritical.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.riskCritical),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'symptom_checker_v2.red_flag_banner'
                  .tr(args: [redFlags.map((flag) => flag.name).join(', ')]),
              style: const TextStyle(
                color: AppColors.riskCritical,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
