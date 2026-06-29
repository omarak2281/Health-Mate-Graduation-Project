import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/medications_provider.dart';
import '../../../home/presentation/providers/iot_provider.dart';
import '../widgets/medicine_box/iot_status_card.dart';
import '../widgets/medicine_box/drawers_grid.dart';

class MedicationBoxPage extends ConsumerWidget {
  const MedicationBoxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medsState = ref.watch(medicationsNotifierProvider);
    final iotState = ref.watch(iotNotifierProvider);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: _buildAppBar(context, isDark),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(6),
            vertical: context.h(2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IoTStatusCard(
                boxStatus: iotState.boxStatus,
                isLoading: iotState.isLoading,
                isDark: isDark,
              ),
              SizedBox(height: context.h(4)),
              Text(
                LocaleKeys.medicationsDrawers.tr(),
                style: AppStyles.headingStyle.copyWith(
                  fontSize: context.sp(22),
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: context.h(2)),
              _buildContent(iotState, medsState, isDark),
              SizedBox(height: context.h(4)),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          color: isDark ? AppColors.white : AppColors.textPrimary,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        LocaleKeys.medicationsMedicationBox.tr(),
        style: AppStyles.headingStyle.copyWith(
          fontSize: context.sp(22),
          color: isDark ? AppColors.white : AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildContent(
      IoTState iotState, MedicationsState medsState, bool isDark) {
    if (iotState.isLoading && iotState.drawers.isEmpty) {
      return const Center(
        child: Padding(
          padding:
              EdgeInsets.symmetric(vertical: AppDimensions.spaceExtraLarge),
          child: CircularProgressIndicator(
            color: AppColors.expertTeal,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    if (iotState.error != null) {
      return Center(
        child: Text(
          iotState.error!,
          style: AppStyles.labelStyle.copyWith(color: AppColors.error),
        ),
      );
    }

    if (iotState.drawers.isEmpty) {
      return Center(
        child: Text(
          LocaleKeys.medicationsNoMedications.tr(),
          style: AppStyles.labelStyle,
        ),
      );
    }

    return DrawersGrid(
      drawers: iotState.drawers,
      medications: medsState.activeMedications,
      isDark: isDark,
    );
  }
}
