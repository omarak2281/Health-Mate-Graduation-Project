import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

class UrgencyBadge extends StatelessWidget {
  final String urgency;
  final String label;

  const UrgencyBadge({
    super.key,
    required this.urgency,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = switch (urgency) {
      'critical' => AppColors.riskCritical,
      'high' => AppColors.riskHigh,
      'moderate' => AppColors.riskModerate,
      _ => AppColors.riskNormal,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.priority_high_rounded, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
