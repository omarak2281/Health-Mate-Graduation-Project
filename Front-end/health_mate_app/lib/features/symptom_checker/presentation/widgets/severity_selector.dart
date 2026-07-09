import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/theme/app_colors.dart';

class SeveritySelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const SeveritySelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(5, (index) {
        final selected = value == index;
        return Expanded(
          child: Tooltip(
            message: 'symptom_checker_v2.severity_$index'.tr(),
            child: InkWell(
              onTap: () => onChanged(index),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 34,
                decoration: BoxDecoration(
                  color: selected
                      ? _severityColor(index)
                      : _severityColor(index).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _severityColor(index).withValues(alpha: selected ? 1 : 0.35),
                  ),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: selected ? Colors.white : _severityColor(index),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Color _severityColor(int severity) {
    if (severity >= 4) return AppColors.riskCritical;
    if (severity == 3) return AppColors.riskHigh;
    if (severity == 2) return AppColors.riskModerate;
    if (severity == 1) return AppColors.riskLow;
    return AppColors.textSecondary;
  }
}
