import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../symptom_checker/presentation/pages/symptom_checker_wizard_page.dart';
import '../../../ai/presentation/pages/symptom_checker_page.dart';
import '../../../medications/presentation/pages/medications_page.dart';
import '../widgets/patient_dashboard_widgets.dart';
import '../widgets/patient_graphs.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';
import '../../../../core/widgets/connectivity_status_widget.dart';
import '../providers/iot_provider.dart';
import '../../../../core/services/overlay_permission_service.dart';
import '../../../vitals/presentation/pages/bp_measurement_guide_page.dart';
import '../../../vitals/presentation/providers/vitals_provider.dart';

class PatientHomePage extends ConsumerStatefulWidget {
  const PatientHomePage({super.key});

  @override
  ConsumerState<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends ConsumerState<PatientHomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Request overlay permission after a short delay so the home page
      // is fully rendered before showing the dialog (better UX).
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          OverlayPermissionService.instance.requestIfNeeded(context);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(navigationProvider);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _buildBody(selectedIndex),
      bottomNavigationBar: _buildBottomNavigationBar(selectedIndex),
    );
  }

  Widget _buildBottomNavigationBar(int selectedIndex) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: context.w(2),
            vertical: context.h(0.4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                selectedIndex: selectedIndex,
                icon: AppIcons.home,
                label: LocaleKeys.homeHome.tr(),
              ),
              _buildNavItem(
                index: 1,
                selectedIndex: selectedIndex,
                icon: AppIcons.check,
                label: LocaleKeys.homeCheck.tr(),
              ),
              _buildNavItem(
                index: 2,
                selectedIndex: selectedIndex,
                icon: AppIcons.pill,
                label: LocaleKeys.homeMeds.tr(),
              ),
              _buildNavItem(
                index: 3,
                selectedIndex: selectedIndex,
                icon: AppIcons.phone,
                label: LocaleKeys.contacts.tr(),
              ),
              _buildNavItem(
                index: 4,
                selectedIndex: selectedIndex,
                icon: AppIcons.settings,
                label: LocaleKeys.homeSetting.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required int selectedIndex,
    required Widget Function({double? size, Color? color}) icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(navigationProvider.notifier).setIndex(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: EdgeInsets.symmetric(
            horizontal: context.w(1),
            vertical: context.h(0.6),
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.primary.withValues(alpha: 0.08))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isSelected ? 1.1 : 1.0),
                duration: const Duration(milliseconds: 300),
                curve: Curves.elasticOut,
                builder: (context, scale, child) {
                  return Transform.scale(
                    scale: scale,
                    child: icon(
                      size: context.sp(24),
                      color: isSelected
                          ? AppColors.primary
                          : (isDark ? Colors.white60 : AppColors.textSecondary),
                    ),
                  );
                },
              ),
              SizedBox(height: context.h(0.2)),
              Text(
                label,
                style: TextStyle(
                  fontSize: context.sp(9),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark ? Colors.white60 : AppColors.textSecondary),
                  letterSpacing: 0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(int selectedIndex) {
    return IndexedStack(
      index: selectedIndex,
      children: [
        _DashboardWrapper(), // Case 0
        ApiConstants.symptomCheckerV2Enabled
            ? const SymptomCheckerWizardPage()
            : const SymptomCheckerPage(), // Case 1
        const MedicationsPage(), // Case 2
        const MedicalContactsPage(), // Case 3
        const SettingsPage(), // Case 4
      ],
    );
  }
}

/// A small wrapper to keep the Dashboard state clean
class _DashboardWrapper extends ConsumerWidget {
  const _DashboardWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const _PatientHomePageStateWrapper();
  }
}

class _PatientHomePageStateWrapper extends ConsumerStatefulWidget {
  const _PatientHomePageStateWrapper();
  @override
  ConsumerState<_PatientHomePageStateWrapper> createState() =>
      _PatientHomePageStateWrapperState();
}

class _PatientHomePageStateWrapperState
    extends ConsumerState<_PatientHomePageStateWrapper> {
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    // Poll sensor status every 5 seconds for real-time dashboard accuracy
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        ref.read(iotNotifierProvider.notifier).loadStatus();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(vitalsNotifierProvider.notifier).loadCurrentBP();
        ref.read(vitalsNotifierProvider.notifier).loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // This is essentially moving the _buildDashboard logic here
    // but simplified to ensure it works within IndexedStack
    final user = ref.watch(authNotifierProvider).user;
    final vitalsState = ref.watch(vitalsNotifierProvider);
    final currentBP = vitalsState.currentBP;

    // Calculate today's average and max heart rates
    final today = DateTime.now();
    final todayReadings = vitalsState.history.where((reading) =>
        reading.measuredAt.year == today.year &&
        reading.measuredAt.month == today.month &&
        reading.measuredAt.day == today.day &&
        reading.heartRate != null);

    final avgHeartRate = todayReadings.isEmpty
        ? 0
        : (todayReadings.map((r) => r.heartRate!).reduce((a, b) => a + b) /
                todayReadings.length)
            .round();
    final maxHeartRate = todayReadings.isEmpty
        ? 0
        : todayReadings
            .map((r) => r.heartRate!)
            .reduce((a, b) => a > b ? a : b);

    // Same aggregation as heart rate, over readings that carry an SpO2 value
    // instead -- a reading can have one field without the other.
    final todaySpo2Readings = vitalsState.history.where((reading) =>
        reading.measuredAt.year == today.year &&
        reading.measuredAt.month == today.month &&
        reading.measuredAt.day == today.day &&
        reading.spo2 != null);

    final avgSpo2 = todaySpo2Readings.isEmpty
        ? 0
        : (todaySpo2Readings.map((r) => r.spo2!).reduce((a, b) => a + b) /
                todaySpo2Readings.length)
            .round();
    final maxSpo2 = todaySpo2Readings.isEmpty
        ? 0
        : todaySpo2Readings.map((r) => r.spo2!).reduce((a, b) => a > b ? a : b);

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(vitalsNotifierProvider.notifier).loadCurrentBP();
        await ref.read(vitalsNotifierProvider.notifier).loadHistory();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PatientUserHeader(user: user),
            SizedBox(height: context.h(2)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PatientQuickActionCard(
                    icon: Icons.monitor_heart,
                    label: 'vitals.bp_check_now'.tr(),
                    subtitle: 'vitals.bp_check_now_desc'.tr(),
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BPMeasurementGuidePage(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: context.h(2.5)),
                  HeartRateCard(
                    heartRate: currentBP?.heartRate,
                    avgToday: todayReadings.isEmpty ? null : avgHeartRate,
                    maxToday: todayReadings.isEmpty ? null : maxHeartRate,
                    riskLevel: currentBP?.heartRateRiskLevel,
                  ),
                  SizedBox(height: context.h(2.5)),
                  SpO2Card(
                    spo2: currentBP?.spo2,
                    avgToday: todaySpo2Readings.isEmpty ? null : avgSpo2,
                    maxToday: todaySpo2Readings.isEmpty ? null : maxSpo2,
                    riskLevel: currentBP?.spo2RiskLevel,
                  ),
                  SizedBox(height: context.h(2.5)),
                  BloodPressureCardExpert(
                    systolic: currentBP?.displaySystolic?.toString(),
                    diastolic: currentBP?.displayDiastolic?.toString(),
                    time: currentBP != null
                        ? DateFormat.jm().format(currentBP.measuredAt)
                        : '--:--',
                    signalQuality: currentBP?.signalQuality,
                    calibrationStatus: currentBP?.effectiveCalibrationStatus,
                    onCheckNow: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BPMeasurementGuidePage(),
                        ),
                      );
                    },
                  ),
                  SizedBox(height: context.h(2.5)),
                  const BloodPressureTrendCard(),
                  SizedBox(height: context.h(4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientUserHeader extends StatelessWidget {
  final dynamic user;
  const PatientUserHeader({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: Stack(
          children: [
            // Decorative Circles matching ExpertAppBar
            Positioned(
              top: -15,
              right: -15,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -10,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withValues(alpha: 0.03),
              ),
            ),

            // Header Content
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + context.h(2),
                bottom: context.h(3),
                left: context.w(6),
                right: context.w(6),
              ),
              child: Row(
                children: [
                  // Profile Avatar with glow
                  Container(
                    width: context.sp(48),
                    height: context.sp(48),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: user?.profileImage != null
                          ? Image.network(
                              user!.profileImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  child: Icon(
                                    AppIcons.person,
                                    color: Colors.white,
                                    size: context.sp(24),
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.white.withValues(alpha: 0.2),
                              child: Icon(
                                AppIcons.person,
                                color: Colors.white,
                                size: context.sp(24),
                              ),
                            ),
                    ),
                  ),
                  SizedBox(width: context.w(4)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LocaleKeys.homeWelcome.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.sp(14),
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          user?.fullName ?? LocaleKeys.authPatient.tr(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: context.sp(22),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: context.w(2)),
                  const SensorsDeviceStatusWidget(showText: false),
                  const SizedBox(width: 8),
                  const ConnectivityStatusWidget(showText: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientSectionHeader extends StatelessWidget {
  final String title;
  const PatientSectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: context.h(1.5)),
      child: Text(
        title,
        style: TextStyle(
          fontSize: context.sp(18),
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}
