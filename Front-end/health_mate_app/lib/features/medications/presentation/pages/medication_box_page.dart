import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medications_provider.dart';
import './add_medication_page.dart';
import '../../../home/presentation/providers/iot_provider.dart';

class MedicationBoxPage extends ConsumerWidget {
  const MedicationBoxPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medsState = ref.watch(medicationsNotifierProvider);
    final iotState = ref.watch(iotNotifierProvider);
    final boxStatus = iotState.boxStatus;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: isDark ? AppColors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LocaleKeys.medicationsMedicationBox.tr(),
          style: AppStyles.headingStyle.copyWith(
            fontSize: context.sp(22),
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: context.w(6), vertical: context.h(2)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Battery & Status Card
              Container(
                padding: EdgeInsets.all(context.w(5)),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.cardDark : AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(alpha: 0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.expertTeal.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.bluetooth_connected_rounded,
                          color: AppColors.expertTeal, size: 24),
                    ),
                    SizedBox(width: context.w(4)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            boxStatus?['box_id'] ??
                                LocaleKeys.medicationsSmartBoxId
                                    .tr(args: ['#---']),
                            style: TextStyle(
                              fontSize: context.sp(18),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '${iotState.isLoading ? "..." : LocaleKeys.vitalsConnected.tr()}  •  ${LocaleKeys.medicationsBattery.tr(args: [
                                  boxStatus?['battery_level']?.toString() ?? '?'
                                ])}%',
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.expertTeal.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.battery_5_bar_rounded,
                          color: AppColors.expertTeal, size: 24),
                    ),
                  ],
                ),
              ),
              SizedBox(height: context.h(4)),

              Text(
                LocaleKeys.medicationsDrawers.tr(),
                style: AppStyles.headingStyle.copyWith(
                  fontSize: context.sp(22),
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: context.h(2)),

              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: context.w(4),
                  crossAxisSpacing: context.w(4),
                  childAspectRatio: 1.1,
                ),
                itemCount: 10,
                itemBuilder: (context, index) {
                  final drawerNum = index + 1;
                  final medication =
                      medsState.medications.cast<dynamic>().firstWhere(
                            (m) => m.drawerNumber == drawerNum,
                            orElse: () => null,
                          );

                  return _buildDrawerCard(
                      context, drawerNum, medication, isDark);
                },
              ),
              SizedBox(height: context.h(4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerCard(
      BuildContext context, int number, dynamic medication, bool isDark) {
    final bool isAssigned = medication != null;

    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: isAssigned
            ? AppColors.expertTeal
            : (isDark ? AppColors.cardDark : AppColors.white),
        borderRadius: BorderRadius.circular(20),
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
          Container(
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
          ),
          const Spacer(),
          if (isAssigned) ...[
            Text(
              medication.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            SizedBox(height: 2),
            Text(
              '${medication.dosage}  •  ${medication.frequency}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: context.sp(12),
                color: AppColors.white.withValues(alpha: 0.8),
              ),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddMedicationPage()),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: AppColors.expertTeal,
                        shape: BoxShape.circle,
                      ),
                      child:
                          const Icon(Icons.add, color: Colors.white, size: 16),
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    LocaleKeys.medicationsAssign.tr(),
                    style: TextStyle(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.bold,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
