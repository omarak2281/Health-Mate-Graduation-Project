import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/connectivity_service.dart';
import '../theme/app_colors.dart';

class ConnectivityStatusWidget extends ConsumerWidget {
  final bool showText;
  const ConnectivityStatusWidget({super.key, this.showText = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(hardwareStatusProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isConnected ? AppColors.success : AppColors.warning)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isConnected ? AppColors.success : AppColors.warning)
              .withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isConnected ? AppColors.success : AppColors.warning,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? AppColors.success : AppColors.warning)
                      .withValues(alpha: 0.5),
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          if (showText) ...[
            const SizedBox(width: 8),
            Text(
              isConnected ? "Box connected" : "Box not reachable",
              style: TextStyle(
                color: isConnected ? AppColors.success : AppColors.warning,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
