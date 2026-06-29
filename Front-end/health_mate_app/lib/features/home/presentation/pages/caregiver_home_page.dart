import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/user.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/services/socket_service.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';
import '../../../communication/presentation/pages/incoming_call_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import '../../../../core/providers/navigation_provider.dart';
import '../../../ai/presentation/pages/ai_symptom_chat_page.dart';
import '../widgets/caregiver_dashboard_widgets.dart';
import './caregiver_patient_detail_page.dart';
import './linked_patients_page.dart';
import '../../../../core/services/overlay_permission_service.dart';

class CaregiverHomePage extends ConsumerStatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  ConsumerState<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends ConsumerState<CaregiverHomePage> {
  @override
  void initState() {
    super.initState();
    // Initialize Socket Listener for Incoming Calls from Patients
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = ref.read(socketServiceProvider);
      socketService.onCallOffer((data) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallPage(
              callerName: data['callerName'] ?? 'Patient',
              callerId: data['callerId'],
              isVideo: data['isVideo'] ?? false,
            ),
          ),
        );
      });

      // Request overlay permission on first launch (with a 2s delay for UX)
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
                svgIcon: AppIcons.home,
                label: LocaleKeys.homeHome.tr(),
              ),
              _buildNavItem(
                index: 1,
                selectedIndex: selectedIndex,
                svgIcon: AppIcons.check,
                label: LocaleKeys.symptomCheckerTitle.tr(),
              ),
              _buildNavItem(
                index: 2,
                selectedIndex: selectedIndex,
                svgIcon: AppIcons.phone,
                label: LocaleKeys.contacts.tr(),
              ),
              _buildNavItem(
                index: 3,
                selectedIndex: selectedIndex,
                svgIcon: AppIcons.settings,
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
    Widget Function({double? size, Color? color})? svgIcon,
    IconData? icon,
    required String label,
  }) {
    final isSelected = selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = AppColors.primary;
    final inactiveColor = isDark ? Colors.white60 : AppColors.textSecondary;

    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(navigationProvider.notifier).setIndex(index),
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
                    child: svgIcon != null
                        ? svgIcon(
                            size: context.sp(24),
                            color: isSelected ? activeColor : inactiveColor,
                          )
                        : Icon(
                            icon,
                            size: context.sp(24),
                            color: isSelected ? activeColor : inactiveColor,
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
                  color: isSelected ? activeColor : inactiveColor,
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
    switch (selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const AiSymptomChatPage();
      case 2:
        return const MedicalContactsPage();
      case 3:
        return const SettingsPage();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = ref.watch(authNotifierProvider).user;
    final linkingState = ref.watch(linkingNotifierProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(linkingNotifierProvider.notifier).getLinkedUsers();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CaregiverUserHeader(user: user),
            SizedBox(height: context.h(2.5)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(5)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CaregiverStatsCard(
                    patientCount: linkingState.linkedUsers.length,
                    activeAlerts: 0,
                  ),
                  SizedBox(height: context.h(3)),
                  CaregiverSectionHeader(
                    title: LocaleKeys.homeLinkedPatients.tr(),
                    trailing: TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const LinkedPatientsPage(),
                        ),
                      ),
                      child: Text(
                        LocaleKeys.manage.tr(),
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: context.sp(14),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.h(1.5)),
                  if (linkingState.isLoading)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(context.w(4)),
                        child: const CircularProgressIndicator(),
                      ),
                    )
                  else if (linkingState.linkedUsers.isEmpty)
                    const CaregiverEmptyLinkedState()
                  else
                    ...linkingState.linkedUsers
                        .take(
                            AppConstants.caregiverDashboardPatientPreviewCount)
                        .toList()
                        .asMap()
                        .entries
                        .map((entry) {
                      final patient = entry.value;
                      return LinkedPatientCard(
                        patient: patient,
                        onTap: () => _openPatientDetail(patient),
                        lastBpReading: null,
                        statusLabel: LocaleKeys.authLinkedPatient.tr(),
                        statusColor: AppColors.riskNormal,
                      );
                    }),
                  if (linkingState.linkedUsers.length > 2)
                    Padding(
                      padding: EdgeInsets.only(bottom: context.h(1)),
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LinkedPatientsPage(),
                          ),
                        ),
                        child: Text(
                          LocaleKeys.viewAll.tr(),
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: context.sp(14),
                          ),
                        ),
                      ),
                    ),
                  SizedBox(height: context.h(3)),
                  CaregiverSectionHeader(
                    title: LocaleKeys.homeRecentAlerts.tr(),
                  ),
                  SizedBox(height: context.h(1.5)),
                  const CaregiverAlertCard(
                    title: '',
                    subtitle: '',
                    icon: Icons.notifications_none_outlined,
                    color: AppColors.riskNormal,
                    isEmpty: true,
                  ),
                  SizedBox(height: context.h(4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openPatientDetail(User patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaregiverPatientDetailPage(patient: patient),
      ),
    );
  }
}
