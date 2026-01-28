import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../linking/presentation/pages/qr_scanner_page.dart';
import '../../../../core/services/socket_service.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';
import '../../../communication/presentation/pages/incoming_call_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import './patient_detail_page.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class CaregiverHomePage extends ConsumerStatefulWidget {
  const CaregiverHomePage({super.key});

  @override
  ConsumerState<CaregiverHomePage> createState() => _CaregiverHomePageState();
}

class _CaregiverHomePageState extends ConsumerState<CaregiverHomePage> {
  int _currentIndex = 0;

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
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.homeCaregiverDashboard.tr(),
        actions: [
          IconButton(
            icon: Icon(AppIcons.notifications,
                size: context.sp(24), color: Colors.white),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
        ],
      ),
      body: Container(
        padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
        child: _buildBody(),
      ),
      bottomNavigationBar: Container(
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
          child: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: isDark
                ? AppColors.textSecondary.withValues(alpha: 0.7)
                : AppColors.textSecondary,
            selectedFontSize: context.sp(10),
            unselectedFontSize: context.sp(9),
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
              height: 1.2,
            ),
            items: [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: context.sp(24)),
                activeIcon: Icon(Icons.home, size: context.sp(24)),
                label: LocaleKeys.homeDashboard.tr(),
              ),
              BottomNavigationBarItem(
                icon: AppIcons.phone(
                    size: context.sp(24),
                    color: isDark
                        ? AppColors.textSecondary.withValues(alpha: 0.7)
                        : AppColors.textSecondary),
                activeIcon: AppIcons.phone(
                    size: context.sp(24), color: AppColors.primary),
                label: LocaleKeys.contacts.tr(),
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline, size: context.sp(24)),
                activeIcon: Icon(Icons.person, size: context.sp(24)),
                label: LocaleKeys.settingsProfile.tr(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const MedicalContactsPage();
      case 2:
        return const SettingsPage();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = ref.watch(authNotifierProvider).user;

    return SingleChildScrollView(
      padding: EdgeInsets.all(context.w(4)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: EdgeInsets.all(context.w(4)),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: context.sp(30),
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                    child: Icon(
                      AppIcons.person,
                      size: context.sp(30),
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: context.w(4)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${LocaleKeys.homeWelcome.tr()}, ${user?.fullName ?? ""}',
                          style: TextStyle(
                              fontSize: context.sp(18),
                              fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: context.h(0.5)),
                        Text(
                          LocaleKeys.authCaregiver.tr(),
                          style: TextStyle(
                              fontSize: context.sp(14),
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: context.h(3)),

          // Linked Patients Section
          _buildLinkedPatientsSection(),
          SizedBox(height: context.h(3)),

          // Recent Alerts Section
          Text(
            LocaleKeys.homeRecentAlerts.tr(),
            style: TextStyle(
                fontSize: context.sp(18), fontWeight: FontWeight.bold),
          ),
          SizedBox(height: context.h(2)),

          Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: Icon(
                AppIcons.notifications,
                color: AppColors.textSecondary,
                size: context.sp(24),
              ),
              title: Text(LocaleKeys.homeNoActiveAlerts.tr(),
                  style: TextStyle(fontSize: context.sp(14))),
              subtitle: Text(LocaleKeys.homeAlertsSubtitle.tr(),
                  style: TextStyle(fontSize: context.sp(12))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedPatientsSection() {
    final linkingState = ref.watch(linkingNotifierProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              LocaleKeys.homeLinkedPatients.tr(),
              style: TextStyle(
                  fontSize: context.sp(18), fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: Icon(AppIcons.add, size: context.sp(24)),
              onPressed: () => _openScanner(),
            ),
          ],
        ),
        SizedBox(height: context.h(1)),
        if (linkingState.isLoading)
          Center(
              child: Padding(
            padding: EdgeInsets.all(context.w(4)),
            child: const CircularProgressIndicator(),
          ))
        else if (linkingState.linkedUsers.isEmpty)
          _buildEmptyLinkedState()
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: linkingState.linkedUsers.length,
            itemBuilder: (context, index) {
              final patient = linkingState.linkedUsers[index];
              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                margin: EdgeInsets.only(bottom: context.h(1.5)),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: context.sp(24),
                    backgroundImage: patient.profileImage != null
                        ? NetworkImage(patient.profileImage!)
                        : null,
                    child: patient.profileImage == null
                        ? Icon(AppIcons.person, size: context.sp(24))
                        : null,
                  ),
                  title: Text(patient.fullName,
                      style: TextStyle(
                          fontSize: context.sp(16),
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(patient.email,
                      style: TextStyle(
                          fontSize: context.sp(14),
                          color: AppColors.textSecondary)),
                  trailing: Icon(AppIcons.chevronRight, size: context.sp(20)),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PatientDetailPage(patient: patient),
                      ),
                    );
                  },
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyLinkedState() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.symmetric(
            vertical: context.h(4), horizontal: context.w(6)),
        child: Column(
          children: [
            Icon(
              AppIcons.people,
              size: context.sp(64),
              color: AppColors.textSecondary,
            ),
            SizedBox(height: context.h(2)),
            Text(
              LocaleKeys.homeNoLinkedPatients.tr(),
              style: TextStyle(
                  fontSize: context.sp(18), fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.h(1)),
            Text(
              LocaleKeys.homeScanToLinkSubtitle.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: context.sp(14), color: AppColors.textSecondary),
            ),
            SizedBox(height: context.h(3)),
            ElevatedButton.icon(
              onPressed: () => _openScanner(),
              icon: Icon(AppIcons.scanner, size: context.sp(20)),
              label: Text(LocaleKeys.homeScanQrCode.tr(),
                  style: TextStyle(
                      fontSize: context.sp(14), fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(
                    horizontal: context.w(6), vertical: context.h(1.5)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openScanner() async {
    final result = await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const QRScannerPage()));

    if (result == true) {
      ref.read(linkingNotifierProvider.notifier).getLinkedUsers();
    }
  }
}
