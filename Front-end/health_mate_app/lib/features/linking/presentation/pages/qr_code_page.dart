import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class QRCodePage extends ConsumerWidget {
  const QRCodePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authNotifierProvider).user;

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.linkingMyQrCode.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(8)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                LocaleKeys.linkingScanToLink.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.sp(24), fontWeight: FontWeight.bold),
              ),
              SizedBox(height: context.h(1)),
              Text(
                LocaleKeys.linkingScanInstructions.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: context.sp(14), color: AppColors.textSecondary),
              ),
              SizedBox(height: context.h(4)),
              Container(
                padding: EdgeInsets.all(context.w(6)),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: QrImageView(
                  data: user?.id ?? '',
                  version: QrVersions.auto,
                  size: context.w(50),
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColors.primary,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.primary,
                  ),
                ),
              ),
              SizedBox(height: context.h(4)),
              Text(
                user?.fullName ?? '',
                style: TextStyle(
                    fontSize: context.sp(22), fontWeight: FontWeight.bold),
              ),
              SizedBox(height: context.h(1)),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.w(4),
                  vertical: context.h(0.8),
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  LocaleKeys.authPatient.tr(),
                  style: TextStyle(
                    fontSize: context.sp(12),
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
