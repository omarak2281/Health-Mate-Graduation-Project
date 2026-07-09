import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:ui' as ui;
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/expert_app_bar.dart';
import '../../../../core/widgets/connectivity_status_widget.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';
import '../../../medications/presentation/widgets/medications_list.dart';
import '../../../medications/presentation/pages/medicine_form_page.dart';
import '../../../medications/presentation/providers/medications_provider.dart';
import '../../../communication/presentation/pages/call_page.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import '../../../vitals/presentation/pages/bp_history_page.dart';
import '../widgets/patient_dashboard_widgets.dart';

/// Caregiver Patient Detail Page
/// Full-featured patient detail page with premium UI matching caregiver dashboard
/// Shows: Patient header, vitals card, medications list, quick actions
class CaregiverPatientDetailPage extends ConsumerWidget {
  final User patient;

  const CaregiverPatientDetailPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: ExpertAppBar(
        title: patient.fullName,
        onBackTap: () => Navigator.of(context).pop(),
        actions: [
          SensorsDeviceStatusWidget(
            showText: false,
            patientId: patient.id,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.delete_outline_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: context.sp(22),
            ),
            onPressed: () => _showUnlinkConfirmation(context, ref),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _refreshPatientData(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Profile Summary Card
              _buildPatientProfileCard(context),

              Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: context.h(2)),

                    // ─── Quick Actions ──────────────────────────────────────
                    _buildSectionTitle(
                        context, LocaleKeys.homeQuickActions.tr()),
                    SizedBox(height: context.h(1.5)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCallActionCard(
                            context,
                            icon: null,
                            iconData: AppIcons.videoCall,
                            label: LocaleKeys.communicationVideoCall.tr(),
                            color: AppColors.primary,
                            onTap: () => _initiateCall(context, isVideo: true),
                          ),
                        ),
                        SizedBox(width: context.w(3)),
                        Expanded(
                          child: _buildCallActionCard(
                            context,
                            icon: null,
                            iconData: Icons.phone_rounded,
                            label: LocaleKeys.communicationAudioCall.tr(),
                            color: AppColors.riskNormal,
                            onTap: () => _initiateCall(context, isVideo: false),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(3)),

                    // ─── Vitals Overview ─────────────────────────────────────
                    _buildSectionTitle(context, LocaleKeys.homeLatestBp.tr()),
                    SizedBox(height: context.h(1.5)),
                    Consumer(
                      builder: (context, ref, _) {
                        final vitalsState = ref
                            .watch(patientVitalsNotifierProvider(patient.id));
                        final bp = vitalsState.currentBP;

                        return Column(
                          children: [
                            _buildCaregiverVitalCard(
                              context,
                              label: LocaleKeys.vitalsBloodPressure.tr(),
                              value: bp?.displaySystolic != null &&
                                      bp?.displayDiastolic != null
                                  ? '${bp!.displaySystolic}/${bp.displayDiastolic}'
                                  : '--/--',
                              unit: LocaleKeys.homeMmHg.tr(),
                              icon: Icons.favorite_rounded,
                              color: AppColors.primary,
                              badge: bp != null
                                  ? VitalTrustBadge(
                                      signalQuality: bp.signalQuality,
                                      calibrationStatus:
                                          bp.effectiveCalibrationStatus,
                                    )
                                  : null,
                              onAction: () {
                                ref
                                    .read(patientVitalsNotifierProvider(
                                            patient.id)
                                        .notifier)
                                    .loadCurrentBP();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      LocaleKeys.homeRefreshDataMessage.tr(
                                        namedArgs: {'name': patient.fullName},
                                      ),
                                      style: AppStyles.labelStyle
                                          .copyWith(color: AppColors.white),
                                    ),
                                    backgroundColor: AppColors.primary,
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                              },
                              actionLabel: LocaleKeys.homeCheckNow.tr(),
                            ),
                            SizedBox(height: context.h(2)),
                            _buildCaregiverVitalCard(
                              context,
                              label: LocaleKeys.vitalsHeartRate.tr(),
                              value: bp?.heartRate?.toString() ?? '--',
                              unit: LocaleKeys.homeBpm.tr(),
                              icon: Icons.monitor_heart_rounded,
                              color: _heartRateColor(bp?.heartRateRiskLevel),
                              badge: _heartRateBadge(context, bp?.heartRateRiskLevel),
                            ),
                            SizedBox(height: context.h(2)),
                            _buildCaregiverVitalCard(
                              context,
                              label: 'vitals.spo2'.tr(),
                              value: bp?.spo2?.toString() ?? '--',
                              unit: '%',
                              icon: Icons.water_drop_rounded,
                              color: AppColors.info,
                            ),
                            SizedBox(height: context.h(2.5)),
                            MeasurementsHistoryCard(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        BPHistoryPage(patientId: patient.id),
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    ),
                    SizedBox(height: context.h(3)),

                    // ─── Medications ────────────────────────────────────────
                    _buildMedicationsHeader(context, ref),
                    SizedBox(height: context.h(1.5)),
                    MedicationsList(
                      patientId: patient.id,
                      embedded: true,
                      showAddButton: false,
                      showHeader: false,
                      showSmartBoxStatus: false,
                    ),

                    SizedBox(height: context.h(4)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refreshPatientData(WidgetRef ref) async {
    await Future.wait([
      ref
          .read(patientVitalsNotifierProvider(patient.id).notifier)
          .loadCurrentBP(),
      ref
          .read(patientMedicationsNotifierProvider(patient.id).notifier)
          .loadMedications(),
      ref.read(linkingNotifierProvider.notifier).getLinkedUsers(),
    ]);
  }

  Widget _buildPatientProfileCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(
          context.w(5), context.h(2), context.w(5), context.h(1)),
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar with linked badge
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: context.sp(65),
                height: context.sp(65),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: patient.profileImage != null
                      ? Image.network(
                          patient.profileImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _buildDefaultAvatar(context),
                        )
                      : _buildDefaultAvatar(context),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: Icon(Icons.link_rounded,
                    size: context.sp(12), color: Colors.white),
              ),
            ],
          ),
          SizedBox(width: context.w(4)),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: TextStyle(
                    fontSize: context.sp(20),
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                    letterSpacing: 0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.h(0.4)),
                Text(
                  patient.email,
                  style: TextStyle(
                    fontSize: context.sp(13),
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: context.h(0.8)),
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: context.w(2.5), vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    LocaleKeys.authLinkedPatient.tr(),
                    style: TextStyle(
                      fontSize: context.sp(10),
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section Title ─────────────────────────────────────────────────────────
  Widget _buildSectionTitle(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: TextStyle(
        fontSize: context.sp(17),
        fontWeight: FontWeight.bold,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildMedicationsHeader(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
          child: _buildSectionTitle(context, LocaleKeys.homeMedications.tr()),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.w(42)),
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MedicineFormPage(patientId: patient.id),
                ),
              );
              ref
                  .read(patientMedicationsNotifierProvider(patient.id).notifier)
                  .loadMedications();
            },
            icon: Icon(Icons.add_rounded, size: context.sp(18)),
            label: Text(
              LocaleKeys.medicationsAddMedication.tr(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.expertTeal,
              foregroundColor: AppColors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: context.w(3),
                vertical: context.h(0.9),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: TextStyle(
                fontSize: context.sp(12),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Call Action Card ──────────────────────────────────────────────────────
  Widget _buildCallActionCard(
    BuildContext context, {
    required Widget Function({double? size, Color? color})? icon,
    IconData? iconData,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: context.h(2),
          horizontal: context.w(3),
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.25 : 0.12),
              color.withValues(alpha: isDark ? 0.15 : 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(2.5)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: icon != null
                  ? icon(size: context.sp(22), color: color)
                  : Icon(iconData, color: color, size: context.sp(22)),
            ),
            SizedBox(height: context.h(0.8)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.sp(11),
                fontWeight: FontWeight.w600,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Icon(
        Icons.person_outline,
        color: AppColors.primary,
        size: context.sp(32),
      ),
    );
  }

  Color _heartRateColor(String? riskLevel) {
    switch (riskLevel) {
      case 'low':
        return Colors.blue[400]!;
      case 'moderate':
        return AppColors.warning;
      case 'high':
        return Colors.deepOrange[400]!;
      case 'critical':
        return AppColors.error;
      case 'normal':
        return AppColors.riskNormal;
      default:
        return AppColors.textSecondary;
    }
  }

  Widget? _heartRateBadge(BuildContext context, String? riskLevel) {
    String? label;
    switch (riskLevel) {
      case 'low':
        label = LocaleKeys.vitalsRiskLow.tr();
        break;
      case 'moderate':
        label = LocaleKeys.vitalsRiskModerate.tr();
        break;
      case 'high':
        label = LocaleKeys.vitalsRiskHigh.tr();
        break;
      case 'critical':
        label = LocaleKeys.vitalsRiskCritical.tr();
        break;
      case 'normal':
        label = LocaleKeys.vitalsRiskNormal.tr();
        break;
    }
    if (label == null) return null;
    final color = _heartRateColor(riskLevel);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.w(2.2), vertical: context.h(0.25)),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: context.sp(10.5),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCaregiverVitalCard(
    BuildContext context, {
    required String label,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    VoidCallback? onAction,
    String? actionLabel,
    Widget? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: isDark ? Border.all(color: AppColors.borderDark) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(context.w(2.5)),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: context.sp(22)),
              ),
              SizedBox(width: context.w(3.5)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: context.sp(14),
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(height: context.h(0.4)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Directionality(
                          textDirection: ui.TextDirection.ltr,
                          child: Text(
                            value,
                            style: TextStyle(
                              fontSize: context.sp(28),
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ),
                        SizedBox(width: context.w(1.5)),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: context.sp(14),
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                    if (badge != null) ...[
                      SizedBox(height: context.h(0.8)),
                      badge,
                    ],
                  ],
                ),
              ),
              if (onAction != null)
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(4),
                      vertical: context.h(1),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    actionLabel ?? '',
                    style: TextStyle(
                      fontSize: context.sp(13),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _initiateCall(BuildContext context, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: isVideo,
          contactName: patient.fullName,
          contactImage: patient.profileImage,
          contactId: patient.id,
          isCaller: true,
        ),
      ),
    );
  }

  void _showUnlinkConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.confirm.tr()),
        content: Text(
          LocaleKeys.homeUnlinkConfirmMessage.tr(
            namedArgs: {'name': patient.fullName},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.riskHigh,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref
                  .read(linkingNotifierProvider.notifier)
                  .unlinkUser(patient.id);
              if (context.mounted) {
                Navigator.pop(context); // Go back to dashboard
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      LocaleKeys.homeUnlinkedSuccessMessage.tr(
                        namedArgs: {'name': patient.fullName},
                      ),
                    ),
                  ),
                );
              }
            },
            child: Text(LocaleKeys.delete.tr()),
          ),
        ],
      ),
    );
  }
}
