import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class WizardBottomActions extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onNext;
  final String? nextLabel;
  final IconData nextIcon;

  const WizardBottomActions({
    super.key,
    required this.onBack,
    required this.onNext,
    this.nextLabel,
    this.nextIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: Text('common.back'.tr()),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: onNext,
              icon: Icon(nextIcon),
              label: Text(nextLabel ?? 'common.next'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
