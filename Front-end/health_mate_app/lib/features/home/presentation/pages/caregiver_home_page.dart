import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../linking/presentation/pages/qr_scanner_page.dart';
import '../../../../core/services/socket_service.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';
import '../../../communication/presentation/pages/incoming_call_page.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import './patient_detail_page.dart';

/// Caregiver Home Page
/// Dashboard for monitoring linked patients

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
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.homeCaregiverDashboard.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            label: LocaleKeys.homeDashboard.tr(),
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined),
            label: LocaleKeys.contacts,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outlined),
            label: LocaleKeys.settingsProfile.tr(),
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
                    child: const Icon(
                      Icons.person,
                      size: 30,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${LocaleKeys.homeWelcome.tr()}, ${user?.fullName ?? ""}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LocaleKeys.authCaregiver.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Linked Patients Section
          _buildLinkedPatientsSection(),
          const SizedBox(height: 24),

          // Recent Alerts Section
          Text(
            LocaleKeys.homeRecentAlerts.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),

          Card(
            child: ListTile(
              leading: Icon(
                Icons.notifications_none,
                color: AppColors.textSecondary,
              ),
              title: Text(LocaleKeys.homeNoActiveAlerts.tr()),
              subtitle: Text(LocaleKeys.homeAlertsSubtitle.tr()),
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
              style: Theme.of(context).textTheme.titleLarge,
            ),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _openScanner(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (linkingState.isLoading)
          const Center(child: CircularProgressIndicator())
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
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: patient.profileImage != null
                        ? NetworkImage(patient.profileImage!)
                        : null,
                    child: patient.profileImage == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                  title: Text(patient.fullName),
                  subtitle: Text(patient.email),
                  trailing: const Icon(Icons.chevron_right),
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
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.homeNoLinkedPatients.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              LocaleKeys.homeScanToLinkSubtitle.tr(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _openScanner(),
              icon: const Icon(Icons.qr_code_scanner),
              label: Text(LocaleKeys.homeScanQrCode.tr()),
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
