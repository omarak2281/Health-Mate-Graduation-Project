import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/linking_repository.dart';

class QRScannerPage extends ConsumerStatefulWidget {
  const QRScannerPage({super.key});

  @override
  ConsumerState<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends ConsumerState<QRScannerPage> {
  late MobileScannerController controller;
  bool isScanning = true;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.linkingScanPatientQr.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(controller: controller, onDetect: _onDetect),
                // Simple Overlay
                _buildOverlay(context),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: context.w(6)),
              child: Center(
                child: isLoading
                    ? const CircularProgressIndicator()
                    : Text(
                        LocaleKeys.linkingScanInstructionsDetail.tr(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: context.sp(16),
                            fontWeight: FontWeight.w500),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final double cutOutSize = context.w(70);
    return Stack(
      children: [
        // Semi-transparent background
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.black.withValues(
              alpha: 0.5,
            ),
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.transparent,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: cutOutSize,
                  height: cutOutSize,
                  decoration: BoxDecoration(
                    color: AppColors.black,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Border for the cutout
        Align(
          alignment: Alignment.center,
          child: Container(
            width: cutOutSize,
            height: cutOutSize,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.primary, width: context.w(1)),
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        ),
      ],
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    final List<Barcode> barcodes = capture.barcodes;

    if (barcodes.isNotEmpty && isScanning) {
      final String? code = barcodes.first.rawValue;

      if (code != null) {
        setState(() {
          isScanning = false;
          isLoading = true;
        });

        try {
          // Stop camera to prevent background processing
          controller.stop();

          await ref
              .read(linkingRepositoryProvider)
              .linkPatient(patientId: code);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(LocaleKeys.linkingLinkedSuccess.tr(),
                    style: TextStyle(fontSize: context.sp(14))),
              ),
            );
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${LocaleKeys.commonError.tr()}: ${e.toString()}',
                  style: TextStyle(fontSize: context.sp(14)),
                ),
              ),
            );
            // Resume scanning
            setState(() {
              isScanning = true;
              isLoading = false;
            });
            controller.start();
          }
        }
      }
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
