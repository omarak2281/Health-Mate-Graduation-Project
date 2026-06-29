import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/user.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import '../../../linking/presentation/pages/qr_scanner_page.dart';
import '../widgets/caregiver_dashboard_widgets.dart';
import './caregiver_patient_detail_page.dart';
import '../../../../core/widgets/expert_app_bar.dart';

/// Linked Patients Page
/// Shows full list of linked patients for the caregiver
class LinkedPatientsPage extends ConsumerStatefulWidget {
  const LinkedPatientsPage({super.key});

  @override
  ConsumerState<LinkedPatientsPage> createState() => _LinkedPatientsPageState();
}

class _LinkedPatientsPageState extends ConsumerState<LinkedPatientsPage> {
  @override
  Widget build(BuildContext context) {
    final linkingState = ref.watch(linkingNotifierProvider);

    if (linkingState.isLoading) {
      return Scaffold(
        appBar: ExpertAppBar(
          title: LocaleKeys.homeLinkedPatients.tr(),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: ExpertAppBar(
        title: LocaleKeys.homeLinkedPatients.tr(),
      ),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.read(linkingNotifierProvider.notifier).getLinkedUsers();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(5),
                  vertical: context.h(2),
                ),
                child: Column(
                  children: [
                    if (linkingState.linkedUsers.isEmpty)
                      const CaregiverEmptyLinkedState()
                    else
                      ...linkingState.linkedUsers.map(
                        (patient) => LinkedPatientCard(
                          patient: patient,
                          onTap: () => _openPatientDetail(patient),
                          lastBpReading: null,
                          statusLabel: LocaleKeys.authLinkedPatient.tr(),
                          statusColor: AppColors.riskNormal,
                        ),
                      ),
                    // Extra space to ensure last item is fully visible above fixed button
                    SizedBox(height: context.h(10)),
                  ],
                ),
              ),
            ),
          ),

          // Fixed Scan QR Code Button at bottom
          Padding(
            padding: EdgeInsets.fromLTRB(
              context.w(5),
              0,
              context.w(5),
              MediaQuery.of(context).padding.bottom + context.h(1.5),
            ),
            child: CaregiverQuickActionCard(
              icon: AppIcons.scanner,
              label: LocaleKeys.homeScanQrCode.tr(),
              subtitle: LocaleKeys.homeScanToLinkSubtitle.tr(),
              color: AppColors.primary,
              onTap: _openScanner,
            ),
          ),
        ],
      ),
    );
  }



  Future<void> _openScanner() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const QRScannerPage()),
    );
    if (result == true) {
      ref.read(linkingNotifierProvider.notifier).getLinkedUsers();
    }
  }

  void _openPatientDetail(User patient) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CaregiverPatientDetailPage(patient: patient),
      ),
    );
  }
}
