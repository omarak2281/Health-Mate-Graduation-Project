import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/theme/app_styles.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/constants/locale_keys.dart';
import '../../../../../core/services/connectivity_service.dart';

/// Displays the smart medicine box hardware connection status.
/// Uses the [hardwareStatusProvider] which polls GET /hardware/status
/// every 30 s. When the backend cannot reach the ESP32 it returns
/// connected: false → we show a clear "unreachable" warning with a
/// manual-refresh button so the user can immediately re-check.
class IoTStatusCard extends ConsumerWidget {
  final Map<String, dynamic>? boxStatus;
  final bool isLoading;
  final bool isDark;

  const IoTStatusCard({
    super.key,
    required this.boxStatus,
    required this.isLoading,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(hardwareStatusProvider);

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.white,
        borderRadius: AppDimensions.borderLarge,
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildStatusIcon(isConnected),
              SizedBox(width: context.w(4)),
              Expanded(child: _buildStatusInfo(context, isConnected)),
              // Manual refresh button
              IconButton(
                onPressed: () =>
                    ref.read(connectivityServiceProvider).checkNow(),
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isConnected
                      ? AppColors.expertTeal
                      : AppColors.textSecondary,
                  size: 22,
                ),
                tooltip: 'Refresh connection status',
              ),
            ],
          ),
          // Warning banner when unreachable
          if (!isConnected && !isLoading) ...[
            const SizedBox(height: 12),
            _buildUnreachableWarning(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(bool isConnected) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (isConnected ? AppColors.expertTeal : AppColors.warning)
            .withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isConnected
            ? Icons.bluetooth_connected_rounded
            : Icons.bluetooth_disabled_rounded,
        color: isConnected ? AppColors.expertTeal : AppColors.warning,
        size: AppDimensions.iconSizeMedium,
      ),
    );
  }

  Widget _buildStatusInfo(BuildContext context, bool isConnected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.medicationsSmartBoxSection.tr(),
          style: AppStyles.cardTitleStyle.copyWith(
            fontSize: context.sp(17),
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isConnected ? AppColors.success : AppColors.warning,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              isConnected
                  ? LocaleKeys.vitalsConnected.tr()
                  : LocaleKeys.vitalsDisconnected.tr(),
              style: AppStyles.labelStyle.copyWith(
                fontSize: context.sp(13),
                color: isConnected ? AppColors.success : AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUnreachableWarning(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.warning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Smart box is unreachable. Make sure the ESP32 is powered on '
              'and connected to the same Wi-Fi network as the server.',
              style: AppStyles.labelStyle.copyWith(
                fontSize: context.sp(11),
                color: AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
