import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user.dart';
import '../../../vitals/presentation/widgets/bp_card.dart';
import '../../../medications/presentation/widgets/medications_list.dart';
import '../../../communication/presentation/pages/call_page.dart';

/// Patient Detail Page
/// For caregivers to monitor a specific patient's health

class PatientDetailPage extends ConsumerWidget {
  final User patient;

  const PatientDetailPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(patient.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () => _initiateCall(context, isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.phone),
            onPressed: () => _initiateCall(context, isVideo: false),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Header
            _buildPatientHeader(context),
            const SizedBox(height: 24),

            // Vitals Section
            Text(
              LocaleKeys.vitalsBloodPressure.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            BPCard(patientId: patient.id),
            const SizedBox(height: 24),

            // Medications Section
            Text(
              LocaleKeys.homeMedications.tr(),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            MedicationsList(patientId: patient.id),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: patient.profileImage != null
                  ? NetworkImage(patient.profileImage!)
                  : null,
              child: patient.profileImage == null
                  ? const Icon(Icons.person, size: 40)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    patient.email,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      LocaleKeys.authLinkedPatient.tr(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _initiateCall(BuildContext context, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: isVideo,
          contactName: patient.fullName,
          contactId: patient.id,
          isCaller: true,
        ),
      ),
    );
  }
}
