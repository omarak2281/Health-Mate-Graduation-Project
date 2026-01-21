import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/user.dart';
import '../../../../core/utils/responsive.dart';
import '../../../vitals/presentation/widgets/bp_card.dart';
import '../../../medications/presentation/widgets/medications_list.dart';
import '../../../communication/presentation/pages/call_page.dart';

import '../../../../core/widgets/expert_app_bar.dart';

class PatientDetailPage extends ConsumerWidget {
  final User patient;

  const PatientDetailPage({super.key, required this.patient});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: patient.fullName,
        actions: [
          IconButton(
            icon: Icon(AppIcons.videoCall,
                size: context.sp(24), color: Colors.white),
            onPressed: () => _initiateCall(context, isVideo: true),
          ),
          IconButton(
            icon: const Icon(Icons.phone_rounded, color: Colors.white),
            onPressed: () => _initiateCall(context, isVideo: false),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(4)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Header
              _buildPatientHeader(context),
              SizedBox(height: context.h(3)),

              // Vitals Section
              Text(
                LocaleKeys.vitalsBloodPressure.tr(),
                style: TextStyle(
                    fontSize: context.sp(18), fontWeight: FontWeight.bold),
              ),
              SizedBox(height: context.h(2)),
              BPCard(patientId: patient.id),
              SizedBox(height: context.h(3)),

              // Medications Section
              Text(
                LocaleKeys.homeMedications.tr(),
                style: TextStyle(
                    fontSize: context.sp(18), fontWeight: FontWeight.bold),
              ),
              SizedBox(height: context.h(2)),
              MedicationsList(patientId: patient.id),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientHeader(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(context.w(4)),
        child: Row(
          children: [
            CircleAvatar(
              radius: context.sp(40),
              backgroundImage: patient.profileImage != null
                  ? NetworkImage(patient.profileImage!)
                  : null,
              child: patient.profileImage == null
                  ? Icon(AppIcons.person, size: context.sp(40))
                  : null,
            ),
            SizedBox(width: context.w(4)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: TextStyle(
                        fontSize: context.sp(20), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    patient.email,
                    style: TextStyle(
                        fontSize: context.sp(14),
                        color: AppColors.textSecondary),
                  ),
                  SizedBox(height: context.h(1)),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(2),
                      vertical: context.h(0.5),
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      LocaleKeys.authLinkedPatient.tr(),
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: context.sp(12),
                        fontWeight: FontWeight.bold,
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
