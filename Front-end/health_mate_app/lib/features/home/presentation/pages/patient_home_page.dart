import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../vitals/presentation/widgets/bp_card.dart';
import '../../../vitals/presentation/pages/bp_history_page.dart';
import '../../../medications/presentation/widgets/medications_list.dart';
import '../../../notifications/presentation/pages/notifications_page.dart';
import '../../../notifications/presentation/providers/notifications_provider.dart';
import '../../../settings/presentation/pages/settings_page.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../ai/presentation/pages/symptom_checker_page.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';
import '../../../medications/presentation/pages/medications_page.dart';
import '../../../../core/services/socket_service.dart';
import '../../../communication/presentation/pages/incoming_call_page.dart';
import './iot_screen.dart';
import '../../../linking/presentation/pages/qr_code_page.dart';

/// Patient Home Page
/// Dashboard with BP monitoring, medications, quick actions

class PatientHomePage extends ConsumerStatefulWidget {
  const PatientHomePage({super.key});

  @override
  ConsumerState<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends ConsumerState<PatientHomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize Socket Service for Incoming Calls
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final socketService = ref.read(socketServiceProvider);

      socketService.onCallOffer((data) {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => IncomingCallPage(
              callerName: data['callerName'] ?? 'Contact',
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
    final unreadCount = ref.watch(notificationsNotifierProvider).unreadCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.homePatientDashboard.tr()),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const NotificationsPage(),
                    ),
                  );
                },
              ),
              if (unreadCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      unreadCount > 9 ? '9+' : unreadCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const SettingsPage()));
            },
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            label: LocaleKeys.homeDashboard.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.favorite_outlined),
            label: LocaleKeys.vitalsBloodPressure.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.medication_outlined),
            label: LocaleKeys.medicationsMyMedications.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.chat_bubble_outline),
            label: LocaleKeys.homeAiChat.tr(),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.contacts_outlined),
            label: LocaleKeys.contacts.tr(),
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
    switch (_selectedIndex) {
      case 0:
        return _buildDashboard();
      case 1:
        return const BPHistoryPage();
      case 2:
        return const MedicationsPage();
      case 3:
        return const SymptomCheckerPage();
      case 4:
        return const MedicalContactsPage();
      case 5:
        return const SettingsPage();
      default:
        return _buildDashboard();
    }
  }

  Widget _buildDashboard() {
    final user = ref.watch(authNotifierProvider).user;

    return RefreshIndicator(
      onRefresh: () async {
        // Refresh data here
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
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
                      backgroundColor: AppColors.primaryLight,
                      child: Text(
                        user?.fullName.isNotEmpty == true
                            ? user!.fullName.substring(0, 1).toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
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
                            LocaleKeys.authPatient.tr(),
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

            // Latest BP Reading
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleKeys.homeLatestBp.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 1;
                    });
                  },
                  child: Text(LocaleKeys.viewAll.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const BPCard(),
            const SizedBox(height: 24),

            // Medications
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleKeys.homeMedications.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedIndex = 2;
                    });
                  },
                  child: Text(LocaleKeys.viewAll.tr()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const MedicationsList(compact: true),
            const SizedBox(height: 24),

            // Quick Actions
            Text(
              LocaleKeys.homeQuickActions.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    context,
                    LocaleKeys.vitalsIoTDevices.tr(),
                    Icons.sensors,
                    AppColors.primary,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const IoTScreen()),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    context,
                    LocaleKeys.linkingMyQrCode.tr(),
                    Icons.qr_code,
                    AppColors.secondary,
                    () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const QRCodePage()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
