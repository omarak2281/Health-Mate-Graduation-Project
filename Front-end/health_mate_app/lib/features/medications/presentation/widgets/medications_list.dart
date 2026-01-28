import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medications_provider.dart';
import '../../../../core/models/medication.dart';
import '../pages/medication_box_page.dart';
import '../pages/add_medication_page.dart';
import '../pages/edit_medication_page.dart';
import '../../../home/presentation/providers/iot_provider.dart';

class MedicationsList extends ConsumerWidget {
  final bool compact;
  final String? patientId;

  const MedicationsList({super.key, this.compact = false, this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medsState = patientId != null
        ? ref.watch(patientMedicationsNotifierProvider(patientId!))
        : ref.watch(medicationsNotifierProvider);

    if (medsState.isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: context.h(10)),
          child: const CircularProgressIndicator(color: AppColors.expertTeal),
        ),
      );
    }

    if (medsState.medications.isEmpty) {
      return Container(
        padding: EdgeInsets.all(context.w(10)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.05)
                    : AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: AppIcons.pill(
                size: context.sp(80),
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            SizedBox(height: context.h(4)),
            Text(
              LocaleKeys.medicationsNoMedications.tr(),
              style: AppStyles.headingStyle.copyWith(
                color: isDark ? AppColors.white : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(1)),
            Text(
              LocaleKeys.medicationsDemoAdd.tr(),
              style: AppStyles.bodyStyle.copyWith(
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            if (!compact && patientId == null) ...[
              SizedBox(height: context.h(4)),
              ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddMedicationPage()),
                ),
                icon: Icon(AppIcons.add, size: context.sp(20)),
                label: Text(LocaleKeys.medicationsAddMedication.tr()),
                style: AppStyles.primaryButtonStyle.copyWith(
                  minimumSize: WidgetStateProperty.all(const Size(200, 56)),
                ),
              ),
            ],
          ],
        ),
      );
    }

    final medications = compact
        ? medsState.activeMedications.take(3).toList()
        : medsState.activeMedications;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!compact) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
                context.w(6), context.h(4), context.w(6), context.h(1)),
            child: Center(
              child: Text(
                LocaleKeys.medicationsMedsList.tr(),
                style: AppStyles.headingStyle.copyWith(
                  fontSize: context.sp(32),
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ),
          ),
          SizedBox(height: context.h(4)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(6)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleKeys.medicationsTodaysSchedule.tr().toUpperCase(),
                  style: AppStyles.labelStyle.copyWith(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w900,
                    color: AppColors.expertTeal,
                    letterSpacing: 2.0,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(
                    LocaleKeys.medicationsViewCalendar.tr(),
                    style: TextStyle(
                      color: AppColors.expertTeal,
                      fontWeight: FontWeight.bold,
                      fontSize: context.sp(14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: context.w(6)),
          itemCount: medications.length,
          itemBuilder: (context, index) {
            return MedicationScheduleCard(
              medication: medications[index],
              isNext: index == 0,
            );
          },
        ),
        SizedBox(height: context.h(4)),
        if (!compact) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(6)),
            child: Text(
              LocaleKeys.medicationsSmartBoxSection.tr().toUpperCase(),
              style: AppStyles.labelStyle.copyWith(
                fontSize: context.sp(14),
                fontWeight: FontWeight.w900,
                color: isDark
                    ? AppColors.white.withValues(alpha: 0.6)
                    : AppColors.textSecondary,
                letterSpacing: 2.0,
              ),
            ),
          ),
          SizedBox(height: context.h(2)),
          const SmartBoxStatusCard(),
        ],
        SizedBox(height: context.h(12)),
      ],
    );
  }
}

class SmartBoxStatusCard extends ConsumerWidget {
  const SmartBoxStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iotState = ref.watch(iotNotifierProvider);
    final boxStatus = iotState.boxStatus;
    final medsState = ref.watch(medicationsNotifierProvider);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: context.w(6)),
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.white.withValues(alpha: 0.05)
              : AppColors.border.withValues(alpha: 0.3),
        ),
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
              Container(
                width: context.sp(54),
                height: context.sp(54),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.expertTeal,
                      AppColors.expertTeal.withValues(alpha: 0.7)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.expertTeal.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: Colors.white,
                  size: context.sp(26),
                ),
              ),
              SizedBox(width: context.w(4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boxStatus?['name'] ??
                          LocaleKeys.medicationsMedicationBox.tr(),
                      style: AppStyles.cardTitleStyle.copyWith(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: boxStatus != null
                                ? AppColors.success
                                : AppColors.textDisabled,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          boxStatus != null
                              ? 'Online • ${boxStatus?['box_id'] ?? '---'}'
                              : 'Offline',
                          style: AppStyles.labelStyle.copyWith(
                            fontSize: context.sp(13),
                            color: isDark
                                ? AppColors.white.withValues(alpha: 0.4)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(
                        boxStatus != null &&
                                boxStatus['battery_level'] != null &&
                                (boxStatus['battery_level'] as int) < 20
                            ? Icons.battery_alert_rounded
                            : Icons.battery_charging_full_rounded,
                        size: 16,
                        color: boxStatus != null &&
                                boxStatus['battery_level'] != null &&
                                (boxStatus['battery_level'] as int) < 20
                            ? AppColors.error
                            : AppColors.success,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${boxStatus?['battery_level'] ?? '--'}%',
                        style: TextStyle(
                          fontSize: context.sp(14),
                          fontWeight: FontWeight.bold,
                          color:
                              isDark ? AppColors.white : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Battery',
                    style: TextStyle(
                      fontSize: context.sp(10),
                      color: AppColors.textSecondary.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: context.h(3)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                LocaleKeys.medicationsDrawers.tr(),
                style: AppStyles.labelStyle.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.6)
                      : AppColors.textSecondary,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const MedicationBoxPage()),
                ),
                child: Text(
                  LocaleKeys.medicationsViewMore.tr(),
                  style: TextStyle(
                    color: AppColors.expertTeal,
                    fontWeight: FontWeight.bold,
                    fontSize: context.sp(13),
                  ),
                ),
              ),
            ],
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(5, (index) {
                final drawerNum = index + 1;
                final isAssigned = medsState.medications
                    .any((m) => m.drawerNumber == drawerNum);
                return Container(
                  width: context.w(20),
                  margin: EdgeInsets.only(right: context.w(3)),
                  padding: EdgeInsets.symmetric(vertical: context.h(1.5)),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.white.withValues(alpha: 0.03)
                        : AppColors.pageBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAssigned
                          ? AppColors.expertTeal.withValues(alpha: 0.5)
                          : (isDark
                              ? AppColors.white.withValues(alpha: 0.05)
                              : AppColors.border.withValues(alpha: 0.2)),
                      width: isAssigned ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'D$drawerNum',
                        style: TextStyle(
                          fontSize: context.sp(12),
                          fontWeight: FontWeight.bold,
                          color: isAssigned
                              ? AppColors.expertTeal
                              : AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Icon(
                        isAssigned
                            ? Icons.medication_rounded
                            : Icons.add_rounded,
                        size: 16,
                        color: isAssigned
                            ? AppColors.expertTeal
                            : AppColors.textSecondary.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class MedicationScheduleCard extends ConsumerWidget {
  final Medication medication;
  final bool isNext;

  const MedicationScheduleCard({
    super.key,
    required this.medication,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: context.h(2)),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark.withValues(alpha: 0.7)
            : AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isNext
              ? AppColors.expertTeal.withValues(alpha: 0.4)
              : (isDark
                  ? AppColors.white.withValues(alpha: 0.05)
                  : AppColors.border.withValues(alpha: 0.3)),
          width: isNext ? 2 : 1,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: AppColors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _showMedicationOptions(context, ref, medication),
            child: Padding(
              padding: EdgeInsets.all(context.w(4)),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Timeline indicator
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: isNext
                            ? AppColors.expertTeal
                            : AppColors.textDisabled.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(width: context.w(3)),
                    // Time Section
                    SizedBox(
                      width: context.w(15),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            medication.timeSlots.isNotEmpty
                                ? medication.timeSlots.first
                                : "--:--",
                            style: TextStyle(
                              fontSize: context.sp(16),
                              fontWeight: FontWeight.w900,
                              color: isNext
                                  ? AppColors.expertTeal
                                  : AppColors.textSecondary,
                            ),
                          ),
                          Text(
                            'AM', // Mocking for now, could be dynamic
                            style: TextStyle(
                              fontSize: context.sp(10),
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    VerticalDivider(
                      width: context.w(4),
                      indent: 8,
                      endIndent: 8,
                      color: AppColors.border.withValues(alpha: 0.5),
                    ),
                    // Icon
                    Container(
                      width: context.sp(50),
                      height: context.sp(50),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.05)
                            : (isNext
                                ? AppColors.expertTeal.withValues(alpha: 0.1)
                                : AppColors.pageBackground),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: medication.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.network(medication.imageUrl!,
                                    fit: BoxFit.cover),
                              )
                            : Icon(
                                _getMedicationIcon(medication),
                                color: AppColors.expertTeal,
                                size: context.sp(24),
                              ),
                      ),
                    ),
                    SizedBox(width: context.w(4)),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            medication.name,
                            style: TextStyle(
                              fontSize: context.sp(18),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            medication.dosage,
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action Icon
                    Icon(
                      Icons.more_vert_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.4),
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMedicationOptions(
      BuildContext context, WidgetRef ref, Medication medication) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.symmetric(vertical: context.h(2)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textDisabled.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: context.h(3)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(6)),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.expertTeal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.medication_rounded,
                        color: AppColors.expertTeal),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          medication.name,
                          style: AppStyles.headingStyle.copyWith(fontSize: 20),
                        ),
                        Text(
                          medication.dosage,
                          style: AppStyles.bodyStyle.copyWith(
                              color: AppColors.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: context.h(3)),
            _optionItem(
              context,
              icon: Icons.info_outline_rounded,
              label: LocaleKeys.medicationsMedicationInformation.tr(),
              onTap: () {
                Navigator.pop(context);
                _showMedicationDetails(context, medication);
              },
            ),
            _optionItem(
              context,
              icon: Icons.edit_outlined,
              label: LocaleKeys.edit.tr(),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          EditMedicationPage(medication: medication)),
                );
              },
            ),
            _optionItem(
              context,
              icon: Icons.delete_outline_rounded,
              label: LocaleKeys.delete.tr(),
              color: AppColors.error,
              onTap: () {
                Navigator.pop(context);
                _confirmDelete(context, ref, medication);
              },
            ),
            SizedBox(height: context.h(2)),
          ],
        ),
      ),
    );
  }

  Widget _optionItem(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? AppColors.expertTeal).withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color ?? AppColors.expertTeal, size: 20),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: color ?? (isDark ? AppColors.white : AppColors.textPrimary),
        ),
      ),
      onTap: onTap,
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, Medication medication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(LocaleKeys.contactsDeleteConfirm.tr()),
        content: Text('Are you sure you want to delete ${medication.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          TextButton(
            onPressed: () async {
              await ref
                  .read(medicationsNotifierProvider.notifier)
                  .deleteMedication(medication.id);
              if (context.mounted) Navigator.pop(context);
            },
            child: Text(
              LocaleKeys.delete.tr(),
              style: const TextStyle(
                  color: AppColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMedicationDetails(BuildContext context, Medication medication) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: EdgeInsets.fromLTRB(
            context.w(6), context.h(2), context.w(6), context.h(4)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.white.withValues(alpha: 0.1)
                      : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: context.h(3)),
            Row(
              children: [
                Container(
                  width: context.sp(80),
                  height: context.sp(80),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.white.withValues(alpha: 0.05)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: medication.imageUrl != null
                        ? Image.network(medication.imageUrl!, fit: BoxFit.cover)
                        : Icon(AppIcons.medication,
                            color: AppColors.expertTeal, size: context.sp(36)),
                  ),
                ),
                SizedBox(width: context.w(4)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medication.name,
                        style: AppStyles.headingStyle.copyWith(
                          fontSize: context.sp(24),
                          color:
                              isDark ? AppColors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        '${medication.dosage} • ${medication.frequency}',
                        style: AppStyles.bodyStyle.copyWith(
                          color: isDark
                              ? AppColors.white.withValues(alpha: 0.6)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.h(4)),
            _detailItem(
                context,
                isDark,
                AppIcons.description,
                LocaleKeys.medicationsInstructions.tr(),
                medication.instructions ?? '---'),
            if (medication.hasDrawer())
              _detailItem(
                  context,
                  isDark,
                  Icons.grid_view_rounded,
                  LocaleKeys.medicationsDrawer.tr(),
                  medication.drawerNumber.toString()),
            _detailItem(
                context,
                isDark,
                AppIcons.time,
                LocaleKeys.medicationsTimeSlots.tr(),
                medication.timeSlots.join(', ')),
            SizedBox(height: context.h(4)),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: AppStyles.primaryButtonStyle,
              child: Text(LocaleKeys.close.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(BuildContext context, bool isDark, IconData icon,
      String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(2)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: context.sp(22), color: AppColors.expertTeal),
          SizedBox(width: context.w(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppStyles.labelStyle.copyWith(
                    color: isDark
                        ? AppColors.white.withValues(alpha: 0.5)
                        : AppColors.textSecondary,
                  ),
                ),
                Text(
                  value,
                  style: AppStyles.bodyStyle.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMedicationIcon(Medication med) {
    if (med.name.toLowerCase().contains('vit')) return Icons.adjust_rounded;
    return Icons.medication_rounded;
  }
}
