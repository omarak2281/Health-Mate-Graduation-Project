import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import 'call_page.dart';

class EmergencyCallActionPage extends StatelessWidget {
  final String patientId;
  final String patientName;
  final String phone;
  final String riskLevel;
  final String systolic;
  final String diastolic;

  const EmergencyCallActionPage({
    super.key,
    required this.patientId,
    required this.patientName,
    this.phone = '',
    this.riskLevel = '',
    this.systolic = '',
    this.diastolic = '',
  });

  @override
  Widget build(BuildContext context) {
    final hasPhone = phone.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.notificationsEmergencyAlert.tr())),
      body: Padding(
        padding: EdgeInsets.all(context.w(5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              patientName,
              style: TextStyle(
                fontSize: context.sp(24),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: context.h(1)),
            Text(
              LocaleKeys.communicationBloodPressureValue.tr(
                namedArgs: {'value': '$systolic/$diastolic mmHg'},
              ),
              style: TextStyle(fontSize: context.sp(16)),
            ),
            SizedBox(height: context.h(0.5)),
            Text(
              LocaleKeys.communicationRiskValue.tr(
                namedArgs: {'value': riskLevel.toUpperCase()},
              ),
              style: TextStyle(
                fontSize: context.sp(16),
                color: AppColors.error,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (hasPhone) ...[
              SizedBox(height: context.h(1)),
              Text(
                phone,
                style: TextStyle(
                  fontSize: context.sp(15),
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            SizedBox(height: context.h(4)),
            _ActionButton(
              icon: Icons.call_rounded,
              label: LocaleKeys.communicationAudioCall.tr(),
              color: AppColors.success,
              onTap: () => _openCall(context, isVideo: false),
            ),
            SizedBox(height: context.h(1.5)),
            _ActionButton(
              icon: Icons.videocam_rounded,
              label: LocaleKeys.communicationVideoCall.tr(),
              color: AppColors.primary,
              onTap: () => _openCall(context, isVideo: true),
            ),
            if (hasPhone) ...[
              SizedBox(height: context.h(1.5)),
              _ActionButton(
                icon: Icons.phone_android_rounded,
                label: LocaleKeys.communicationPhoneCall.tr(),
                color: AppColors.info,
                onTap: () => _makePhoneCall(phone),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openCall(BuildContext context, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: isVideo,
          contactName: patientName,
          contactId: patientId,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final launchUri = Uri(scheme: 'tel', path: phoneNumber);
    final launched = await launchUrl(
      launchUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('No dialer app can handle $launchUri');
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: context.h(1.6)),
        ),
      ),
    );
  }
}
