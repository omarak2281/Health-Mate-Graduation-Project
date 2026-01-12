import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/linking_repository.dart';

/// QR Scanner Page
/// Scans patient QR code to link
/// Uses mobile_scanner for Web support

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
      // No formattedOverlayColor here, it was causing errors
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.linkingScanPatientQr.tr())),
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
            child: Center(
              child: isLoading
                  ? const CircularProgressIndicator()
                  : Text(
                      LocaleKeys.linkingScanInstructionsDetail.tr(),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    const double cutOutSize = 300;
    return Stack(
      children: [
        // Semi-transparent background
        ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.black.withValues(
              alpha: 0.5,
            ), // Using withValues as withOpacity is deprecated
            BlendMode.srcOut,
          ),
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.transparent,
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
                    borderRadius: BorderRadius.circular(10),
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
              border: Border.all(color: AppColors.primary, width: 4),
              borderRadius: BorderRadius.circular(10),
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
              SnackBar(content: Text(LocaleKeys.linkingLinkedSuccess.tr())),
            );
            Navigator.of(context).pop(true);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${LocaleKeys.commonError.tr()}: ${e.toString()}',
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
