import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../../core/services/error_handling_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../data/vitals_repository.dart';
import '../providers/vitals_provider.dart';
import '../../../home/presentation/providers/iot_provider.dart';
import '../../../symptom_checker/presentation/pages/symptom_checker_wizard_page.dart';
import '../../../../core/services/push_notification_service.dart';

class BPMeasurementGuidePage extends ConsumerStatefulWidget {
  /// Manual opt-in entry point (e.g. from patient settings): forces the
  /// calibration (cuff-entry) step even if the patient is already calibrated.
  final bool forceCalibration;

  /// Recalibration mode (Settings → Recalibrate): walks through the same
  /// device-intro and sensor-placement steps as first-time setup, then
  /// always forces the cuff-entry step after measuring (see
  /// `_loadCalibrationStatus`) instead of showing the raw device result.
  /// The device reading is still required — the calibration math needs a
  /// paired model value + cuff value from the same window.
  final bool quickRecalibration;

  const BPMeasurementGuidePage({
    super.key,
    this.forceCalibration = false,
    this.quickRecalibration = false,
  });

  @override
  ConsumerState<BPMeasurementGuidePage> createState() =>
      _BPMeasurementGuidePageState();
}

class _BPMeasurementGuidePageState extends ConsumerState<BPMeasurementGuidePage>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  bool _isMeasuring = false;
  int _secondsLeft = 8;
  Timer? _timer;
  Timer? _statusPollTimer;
  String? _measurementError;
  String? _pendingVitalSignId;
  int? _predictedHeartRate;
  int? _predictedSpo2;
  double? _lastSignalQuality;
  int? _estimatedSystolic;
  int? _estimatedDiastolic;

  // Calibration branching (Phase 2): the cuff-entry step only appears for
  // first-time onboarding, drift-triggered recalibration, or manual opt-in.
  bool _calibrationRequired = false;
  bool _calibrationStatusLoaded = false;
  bool _measurementComplete = false;

  // Guards against overlapping status polls now that we poll every second.
  bool _pollInFlight = false;

  // Wave animation controllers
  late AnimationController _waveController;

  // Controllers for manual cuff entries
  final _systolicController = TextEditingController();
  final _diastolicController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Recalibration still walks through the device-intro and sensor-
    // placement steps -- skipping straight to measurement left patients
    // trying to take a reading with the cuff/electrodes not even on yet.
    // `quickRecalibration` only forces the cuff-entry step afterwards (see
    // `_loadCalibrationStatus`), it no longer skips the guidance steps.

    // Start polling sensors status every 2 seconds for live UI feedback
    _statusPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) {
        ref.read(iotNotifierProvider.notifier).loadStatus();
      }
    });

    _loadCalibrationStatus();
  }

  Future<void> _loadCalibrationStatus() async {
    if (widget.forceCalibration || widget.quickRecalibration) {
      // Manual opt-in from patient settings: always show the cuff-entry step.
      setState(() {
        _calibrationRequired = true;
        _calibrationStatusLoaded = true;
      });
      return;
    }
    try {
      final vitalsRepo = ref.read(vitalsRepositoryProvider);
      final status = await vitalsRepo.getCalibrationStatus();
      final calibrationStatus = status['status'] as String?;
      final driftFlag = status['drift_flag'] == true;
      final recalibrationDue = status['recalibration_due'] == true;
      if (!mounted) return;
      setState(() {
        _calibrationRequired = calibrationStatus == 'not_calibrated' ||
            calibrationStatus == 'weak' ||
            calibrationStatus == 'recalibration_due' ||
            driftFlag ||
            recalibrationDue;
        _calibrationStatusLoaded = true;
      });
    } catch (_) {
      // If the status can't be fetched, fail open with the regular 3-step
      // flow rather than blocking measurement on a calibration check.
      if (!mounted) return;
      setState(() {
        _calibrationRequired = false;
        _calibrationStatusLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _statusPollTimer?.cancel();
    _waveController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    PushNotificationService.instance.notifyAlarmScreenClosed();
    super.dispose();
  }

  // ---- Theme helpers (make this page fully dark-mode aware) ----
  bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _textPrimary(BuildContext context) =>
      _isDark(context) ? AppColors.textPrimaryDark : AppColors.textPrimary;

  Color _textSecondary(BuildContext context) =>
      _isDark(context) ? AppColors.textSecondaryDark : AppColors.textSecondary;

  Color _surface(BuildContext context) =>
      _isDark(context) ? AppColors.surfaceDark : AppColors.surfaceLight;

  Color _border(BuildContext context) =>
      _isDark(context) ? AppColors.borderDark : AppColors.border;

  String _getSensorStatus(List sensors, String type) {
    if (sensors.isEmpty) return 'disconnected';
    try {
      final s = sensors.firstWhere((s) => s['sensor_type'] == type,
          orElse: () => null);
      if (s == null) return 'disconnected';
      return s['status'] ?? 'disconnected';
    } catch (_) {
      return 'disconnected';
    }
  }

  // ---- Step-gating helpers (hoisted so both the step content and the nav
  // buttons agree on whether the current step's requirement is satisfied) ----

  /// Device is "online" if it has sent a heartbeat within the last 35 seconds.
  bool get _deviceOnline {
    final sensors = ref.watch(iotNotifierProvider).sensors;
    if (sensors.isEmpty) return false;
    try {
      final firstSensor = sensors.first;
      final lastPingStr = firstSensor['last_ping'];
      if (lastPingStr == null) return false;
      // Backend returns timestamps without 'Z' suffix — treat as UTC.
      final normalised = lastPingStr.endsWith('Z') || lastPingStr.contains('+')
          ? lastPingStr
          : '${lastPingStr}Z';
      final lastPing = DateTime.parse(normalised).toUtc();
      return DateTime.now().toUtc().difference(lastPing).inSeconds.abs() < 35;
    } catch (_) {
      return false;
    }
  }

  bool get _deviceOnlineRead {
    final sensors = ref.read(iotNotifierProvider).sensors;
    if (sensors.isEmpty) return false;
    try {
      final firstSensor = sensors.first;
      final lastPingStr = firstSensor['last_ping'];
      if (lastPingStr == null) return false;
      final normalised = lastPingStr.endsWith('Z') || lastPingStr.contains('+')
          ? lastPingStr
          : '${lastPingStr}Z';
      final lastPing = DateTime.parse(normalised).toUtc();
      return DateTime.now().toUtc().difference(lastPing).inSeconds.abs() < 35;
    } catch (_) {
      return false;
    }
  }

  bool get _allSensorsConnected {
    final sensors = ref.watch(iotNotifierProvider).sensors;
    final ppgConnected = _getSensorStatus(sensors, 'ppg') == 'connected';
    final ecgConnected = _getSensorStatus(sensors, 'ecg') == 'connected';
    return ppgConnected && ecgConnected;
  }

  /// Whether the user is allowed to advance past [step] via the Next button.
  bool _stepRequirementMet(int step) {
    switch (step) {
      case 0:
        return _deviceOnline;
      case 1:
        return _allSensorsConnected;
      default:
        return true;
    }
  }

  void _startMeasurement() async {
    setState(() {
      _isMeasuring = true;
      _secondsLeft = 45; // 45 seconds timeout for hardware reading
      _measurementError = null;
      _pendingVitalSignId = null;
      _predictedHeartRate = null;
      _predictedSpo2 = null;
      _lastSignalQuality = null;
      _estimatedSystolic = null;
      _estimatedDiastolic = null;
    });
    _pollInFlight = false;

    final vitalsRepo = ref.read(vitalsRepositoryProvider);

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });

        // Check if device went offline
        if (!_deviceOnlineRead) {
          _timer?.cancel();
          _timer = null;
          setState(() {
            _isMeasuring = false;
            _measurementError = 'vitals.bp_guide_device_went_offline'.tr();
          });
          return;
        }

        // Poll the latest pending reading from the backend every second so a
        // rejection (poor signal, finger lost, leads off) surfaces as close
        // to real-time as the polling architecture allows. _pollInFlight
        // prevents overlapping requests on slow networks.
        if (!_pollInFlight) {
          _pollInFlight = true;
          try {
            final history = await vitalsRepo.getBPHistory(limit: 1);
            if (history.isNotEmpty) {
              final latest = history.first;
              final difference = DateTime.now()
                  .toUtc()
                  .difference(latest.createdAt.toUtc())
                  .inSeconds;
              final standsFresh = difference.abs() < 60;

              developer.log(
                'BP Polling: checked latest reading ${latest.id}. '
                'createdAt: ${latest.createdAt.toUtc()} (UTC), '
                'now: ${DateTime.now().toUtc()} (UTC), '
                'difference: ${difference}s, '
                'status: ${latest.measurementStatus}, '
                'standsFresh: $standsFresh',
                name: 'vitals.bp_guide',
              );

              if (standsFresh) {
                // Status-based completion detection. The backend creates a
                // reading with status 'completed_pending_bp' the moment the
                // device submission succeeds (HR/model BP known, cuff BP
                // still awaited), or 'completed' if it was finalized. Either
                // one means the measurement arrived.
                final status = latest.measurementStatus;
                if (status == 'completed_pending_bp' || status == 'completed') {
                  _timer?.cancel();
                  _timer = null;
                  setState(() {
                    _isMeasuring = false;
                    _pendingVitalSignId = latest.id;
                    _predictedHeartRate = latest.heartRate;
                    _predictedSpo2 = latest.spo2;
                    _lastSignalQuality = latest.signalQuality;
                    _estimatedSystolic = latest.displaySystolic;
                    _estimatedDiastolic = latest.displayDiastolic;
                    // Quick recalibration always proceeds to cuff entry —
                    // even if the backend auto-completed the reading using
                    // the existing calibration — because the whole point of
                    // the flow is submitting a fresh cuff/model pair.
                    if (_calibrationRequired &&
                        (status != 'completed' || widget.quickRecalibration)) {
                      _currentStep = 3; // Move to the cuff-entry step
                    } else {
                      _measurementComplete = true; // Show inline result
                    }
                  });
                  // Refresh dashboard state so the home page reflects the
                  // new reading when the patient navigates back.
                  ref.read(vitalsNotifierProvider.notifier).loadCurrentBP();
                  ref.read(vitalsNotifierProvider.notifier).loadHistory();
                } else if (status == 'rejected') {
                  _timer?.cancel();
                  _timer = null;
                  setState(() {
                    _isMeasuring = false;
                    _measurementError =
                        _localizedRejectionReason(latest.rejectionReason);
                  });
                }
                // Any other status: keep polling until the timeout window
                // runs out (genuine network/device fallback).
              }
            }
          } catch (e) {
            _timer?.cancel();
            _timer = null;
            final errorInfo = ErrorHandlingService.detectErrorType(e);
            setState(() {
              _isMeasuring = false;
              _measurementError = 'vitals.bp_guide_api_error'.tr(namedArgs: {
                'error': errorInfo.messageKey.tr(),
              });
            });
          } finally {
            _pollInFlight = false;
          }
        }
      } else {
        _timer?.cancel();
        _timer = null;
        setState(() {
          _isMeasuring = false;
          _measurementError = 'vitals.bp_guide_timeout_error'.tr();
        });
      }
    });
  }

  /// Maps a backend rejection_reason code to a specific, actionable,
  /// non-technical instruction the patient can follow.
  String _localizedRejectionReason(String? reason) {
    switch (reason) {
      case 'finger_missing':
        return 'vitals.bp_guide_rejection_finger_missing'.tr();
      case 'leads_off':
        return 'vitals.bp_guide_rejection_leads_off'.tr();
      case 'poor_signal':
        return 'vitals.bp_guide_rejection_poor_signal'.tr();
      case 'out_of_range':
        return 'vitals.bp_guide_rejection_out_of_range'.tr();
      default:
        return 'vitals.bp_guide_rejection_unknown'.tr();
    }
  }

  Future<void> _submitCuffReading() async {
    if (!_formKey.currentState!.validate()) return;

    final systolic = int.parse(_systolicController.text.trim());
    final diastolic = int.parse(_diastolicController.text.trim());

    if (systolic <= diastolic) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              LocaleKeys.errorsPasswordsDontMatch.tr()), // fallback validator
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      setState(() {
        _isMeasuring = true;
      });

      final vitalsRepo = ref.read(vitalsRepositoryProvider);
      final vital = await vitalsRepo.completeReading(
        vitalSignId: _pendingVitalSignId!,
        systolic: systolic,
        diastolic: diastolic,
      );

      // Successfully saved! Refresh provider state and go back
      await ref.read(vitalsNotifierProvider.notifier).loadCurrentBP();
      await ref.read(vitalsNotifierProvider.notifier).loadHistory();

      if (mounted) {
        final risk = vital.riskLevel.toLowerCase();
        final isDangerous = risk == 'high' || risk == 'critical';
        if (isDangerous) {
          _showRiskDiagnosticDialog(context, vital);
        } else {
          _showFinalResultDialog(context, vital);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isMeasuring = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.vitalsBpGuideTitle.tr()),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(context.w(4)),
          child: Column(
            children: [
              // Top Step Progress Indicator
              if (!_calibrationStatusLoaded)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              _buildStepProgress(),
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(context.w(5)),
                    child: SingleChildScrollView(
                      child: _buildCurrentStepContent(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _buildNavButtons(),
            ],
          ),
        ),
      ),
    );
  }

  int get _totalSteps => widget.quickRecalibration
      ? 2 // quick reading + cuff entry only
      : (_calibrationRequired ? 4 : 3);

  /// Step index shown in the progress bar. In quick-recalibration mode the
  /// internal step counter still starts at 2 (measurement), but the patient
  /// sees a 2-step flow.
  int get _displayStep =>
      widget.quickRecalibration ? _currentStep - 2 : _currentStep;

  Widget _buildStepProgress() {
    final borderColor = _border(context);
    final mutedText = _textSecondary(context);
    final totalSteps = _totalSteps;
    final displayStep = _displayStep;
    return Directionality(
      textDirection: ui.TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: context.w(8)),
        child: SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                left: 16,
                right: 16,
                child: Center(
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                left: 16,
                right: 16,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: totalSteps <= 1
                        ? 0
                        : (displayStep / (totalSteps - 1)).clamp(0.0, 1.0),
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(totalSteps, (index) {
                  final isActive = index <= displayStep;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive ? AppColors.primary : borderColor,
                      border: Border.all(
                        color: _surface(context),
                        width: 4,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isActive ? AppColors.white : mutedText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Intro();
      case 1:
        return _buildStep2SensorPlacement();
      case 2:
        return _buildStep3Measurement();
      case 3:
        return _buildStep4CuffEntry();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Intro() {
    // Device is "online" if it has sent a heartbeat within the last 35 seconds.
    // We do NOT require the user to be touching the sensors yet (that's Step 2).
    final deviceOnline = _deviceOnline;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          deviceOnline ? Icons.wifi_tethering : Icons.wifi_tethering_off,
          size: 80,
          color: deviceOnline ? AppColors.primary : _textSecondary(context),
        ),
        const SizedBox(height: 24),
        Text(
          deviceOnline
              ? LocaleKeys.vitalsConnected.tr()
              : 'vitals.bp_guide_device_offline'.tr(),
          style: TextStyle(
            fontSize: context.sp(20),
            fontWeight: FontWeight.bold,
            color: deviceOnline ? AppColors.primary : _textPrimary(context),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          deviceOnline
              ? 'vitals.bp_guide_device_online'.tr()
              : 'vitals.bp_guide_device_offline_desc'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(14),
            color: _textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2SensorPlacement() {
    final iotState = ref.watch(iotNotifierProvider);
    final sensors = iotState.sensors;

    final ppgConnected = _getSensorStatus(sensors, 'ppg') == 'connected';
    final ecgConnected = _getSensorStatus(sensors, 'ecg') == 'connected';
    final allConnected = _allSensorsConnected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          LocaleKeys.vitalsBpGuideSensorPlacement.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(18),
            fontWeight: FontWeight.bold,
            color: _textPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'vitals.bp_guide_step2_intro'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(14),
            color: _textSecondary(context),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        _buildSensorStatusCard(
          icon: Icons.fingerprint,
          connected: ppgConnected,
          title: 'vitals.ppg_sensor'.tr(),
          statusOn: 'vitals.bp_guide_finger_on'.tr(),
          statusOff: 'vitals.bp_guide_finger_off'.tr(),
          howTo: 'vitals.bp_guide_ppg_howto_desc'.tr(),
          onTutorialTap: () => _showPPGTutorialSheet(context),
        ),
        const SizedBox(height: 14),
        _buildSensorStatusCard(
          icon: Icons.monitor_heart,
          connected: ecgConnected,
          title: 'vitals.ecg_sensor'.tr(),
          statusOn: 'vitals.bp_guide_leads_on'.tr(),
          statusOff: 'vitals.bp_guide_leads_off_inline'.tr(),
          howTo: 'vitals.bp_guide_ecg_howto_desc'.tr(),
          onTutorialTap: () => _showECGTutorialSheet(context),
        ),
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: (allConnected ? AppColors.success : AppColors.warning)
                .withValues(alpha: _isDark(context) ? 0.18 : 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: allConnected ? AppColors.success : AppColors.warning,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                allConnected ? Icons.check_circle : Icons.hourglass_top,
                color: allConnected ? AppColors.success : AppColors.warning,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  allConnected
                      ? 'vitals.bp_guide_all_connected'.tr()
                      : 'vitals.bp_guide_status_waiting'.tr(),
                  style: TextStyle(
                    color: allConnected ? AppColors.success : AppColors.warning,
                    fontWeight: FontWeight.bold,
                    fontSize: context.sp(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSensorStatusCard({
    required IconData icon,
    required bool connected,
    required String title,
    required String statusOn,
    required String statusOff,
    required String howTo,
    required VoidCallback onTutorialTap,
  }) {
    final statusColor = connected ? AppColors.success : _textSecondary(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: connected ? AppColors.success : _border(context),
          width: connected ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PulsingStatusIcon(
              icon: icon, active: !connected, color: statusColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: context.sp(15),
                          color: _textPrimary(context),
                        ),
                      ),
                    ),
                    Icon(
                      connected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: statusColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      connected ? statusOn : statusOff,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: context.sp(11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  howTo,
                  style: TextStyle(
                    fontSize: context.sp(12.5),
                    color: _textSecondary(context),
                    height: 1.4,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onTutorialTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.play_circle_fill,
                        color: AppColors.primary, size: 18),
                    label: Text(
                      'vitals.bp_guide_watch_tutorial'.tr(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPPGTutorialSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border(sheetContext),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'vitals.bp_guide_ppg_tutorial_title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sheetContext.sp(17),
                  fontWeight: FontWeight.bold,
                  color: _textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 16),
              const _PPGTutorialAnimation(),
              const SizedBox(height: 20),
              _tutorialStep(
                  sheetContext, 1, 'vitals.bp_guide_ppg_tutorial_step1'.tr()),
              _tutorialStep(
                  sheetContext, 2, 'vitals.bp_guide_ppg_tutorial_step2'.tr()),
              _tutorialStep(
                  sheetContext, 3, 'vitals.bp_guide_ppg_tutorial_step3'.tr()),
              _tutorialStep(
                  sheetContext, 4, 'vitals.bp_guide_ppg_tutorial_step4'.tr()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text('vitals.bp_guide_tutorial_close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showECGTutorialSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _border(sheetContext),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'vitals.bp_guide_ecg_tutorial_title'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: sheetContext.sp(17),
                  fontWeight: FontWeight.bold,
                  color: _textPrimary(sheetContext),
                ),
              ),
              const SizedBox(height: 16),
              const _ECGTutorialAnimation(),
              const SizedBox(height: 12),
              _buildElectrodeLegendRow(sheetContext, Colors.redAccent,
                  'vitals.bp_guide_ecg_dot_red'.tr()),
              _buildElectrodeLegendRow(sheetContext, const Color(0xFFE8C547),
                  'vitals.bp_guide_ecg_dot_yellow'.tr()),
              _buildElectrodeLegendRow(sheetContext, AppColors.success,
                  'vitals.bp_guide_ecg_dot_green'.tr()),
              const SizedBox(height: 8),
              _tutorialStep(
                  sheetContext, 1, 'vitals.bp_guide_ecg_tutorial_step1'.tr()),
              _tutorialStep(
                  sheetContext, 2, 'vitals.bp_guide_ecg_tutorial_step2'.tr()),
              _tutorialStep(
                  sheetContext, 3, 'vitals.bp_guide_ecg_tutorial_step3'.tr()),
              _tutorialStep(
                  sheetContext, 4, 'vitals.bp_guide_ecg_tutorial_step4'.tr()),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text('vitals.bp_guide_tutorial_close'.tr()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildElectrodeLegendRow(
      BuildContext context, Color color, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: context.sp(12.5),
                color: _textSecondary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tutorialStep(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: context.sp(13.5),
                color: _textPrimary(context),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3Measurement() {
    if (_measurementComplete && !_calibrationRequired) {
      return _buildRegularResult();
    }
    // Live sensor state while measuring: if the device reports the finger or
    // leads lost mid-window (via its heartbeat), warn immediately instead of
    // waiting for the backend to reject the whole 8-second window.
    final sensors = ref.watch(iotNotifierProvider).sensors;
    final ppgLive = _getSensorStatus(sensors, 'ppg') == 'connected';
    final ecgLive = _getSensorStatus(sensors, 'ecg') == 'connected';

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_isMeasuring) ...[
          if (!ppgLive || !ecgLive) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning
                    .withValues(alpha: _isDark(context) ? 0.18 : 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber,
                      color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !ppgLive
                          ? 'vitals.bp_guide_live_finger_lost'.tr()
                          : 'vitals.bp_guide_live_leads_lost'.tr(),
                      style: TextStyle(
                        color: AppColors.warning,
                        fontWeight: FontWeight.bold,
                        fontSize: context.sp(12.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          DefaultTextStyle(
            style: TextStyle(color: _textSecondary(context)),
            child: const Text('PPG & ECG Live Waveform').tr(),
          ),
          const SizedBox(height: 16),
          // Waveform animation
          SizedBox(
            height: 80,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                return CustomPaint(
                  painter:
                      _WavePainter(_waveController.value, AppColors.primary),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            LocaleKeys.vitalsBpGuideHoldStill.tr(),
            style: TextStyle(
              fontSize: context.sp(16),
              fontWeight: FontWeight.bold,
              color: _textPrimary(context),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.vitalsBpGuideSecondsLeft.tr(
              namedArgs: {'seconds': _secondsLeft.toString()},
            ),
            style: TextStyle(
              fontSize: context.sp(24),
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
        ] else if (_measurementError != null) ...[
          const Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            _measurementError!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(15),
              fontWeight: FontWeight.bold,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startMeasurement,
            icon: const Icon(Icons.refresh),
            label: Text(LocaleKeys.vitalsBpGuideRetryButton.tr()),
          ),
        ] else ...[
          const Icon(
            Icons.play_circle_outline,
            size: 80,
            color: AppColors.primary,
          ),
          const SizedBox(height: 24),
          Text(
            widget.quickRecalibration
                ? 'vitals.bp_quick_recal_intro'.tr()
                : LocaleKeys.vitalsBpGuideHoldStill.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(15),
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _startMeasurement,
            icon: const Icon(Icons.play_arrow),
            label: Text(LocaleKeys.vitalsBpGuideStart.tr()),
          ),
        ]
      ],
    );
  }

  /// Result screen for the regular (already-calibrated, non-drifting)
  /// measurement flow — no cuff form. The BP number is the most prominent
  /// element; HR/SpO2 and signal quality support it.
  Widget _buildRegularResult() {
    final hasBP = _estimatedSystolic != null && _estimatedDiastolic != null;
    final goodSignal = (_lastSignalQuality ?? 0) >= 0.8;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(
          Icons.check_circle,
          size: 56,
          color: AppColors.success,
        ),
        const SizedBox(height: 12),
        Text(
          'vitals.bp_guide_regular_result_title'.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(17),
            fontWeight: FontWeight.bold,
            color: _textPrimary(context),
          ),
        ),
        if (hasBP) ...[
          const SizedBox(height: 16),
          Directionality(
            textDirection: ui.TextDirection.ltr,
            child: Text(
              '$_estimatedSystolic / $_estimatedDiastolic',
              style: TextStyle(
                fontSize: context.sp(40),
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
          Text(
            LocaleKeys.homeMmHg.tr(),
            style: TextStyle(
              fontSize: context.sp(14),
              color: _textSecondary(context),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'vitals.bp_guide_estimated_note'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(11.5),
              color: _textSecondary(context),
            ),
          ),
        ] else ...[
          const SizedBox(height: 8),
          Text(
            'vitals.bp_guide_regular_result_desc'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(13.5),
              color: _textSecondary(context),
              height: 1.4,
            ),
          ),
        ],
        if (_predictedHeartRate != null || _predictedSpo2 != null) ...[
          const SizedBox(height: 16),
          // Wrap (not Row) -- the Arabic "bpm" translation
          // ("نبضة/دقيقة") is long enough that two chips side by side can
          // exceed narrow screen widths. Wrap drops the second chip to its
          // own line instead of overflowing horizontally.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (_predictedHeartRate != null)
                _buildResultChip(
                  icon: Icons.favorite,
                  iconColor: AppColors.error,
                  value: '$_predictedHeartRate ${LocaleKeys.homeBpm.tr()}',
                ),
              if (_predictedSpo2 != null)
                _buildResultChip(
                  icon: Icons.water_drop,
                  iconColor: AppColors.info,
                  value: '$_predictedSpo2%',
                ),
            ],
          ),
        ],
        if (_lastSignalQuality != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: (goodSignal ? AppColors.success : AppColors.warning)
                  .withValues(alpha: _isDark(context) ? 0.18 : 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  goodSignal ? Icons.network_check : Icons.warning_amber,
                  size: 16,
                  color: goodSignal ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    goodSignal
                        ? 'vitals.signal_good_badge'.tr()
                        : 'vitals.signal_poor_badge'.tr(),
                    style: TextStyle(
                      fontSize: context.sp(12),
                      fontWeight: FontWeight.w600,
                      color: goodSignal ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildResultChip({
    required IconData icon,
    required Color iconColor,
    required String value,
  }) {
    return Card(
      color: AppColors.primary.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: context.sp(15),
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep4CuffEntry() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: _isDark(context) ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, color: AppColors.primary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'vitals.bp_guide_calibration_banner'.tr(),
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: context.sp(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Icon(
            Icons.check_circle,
            size: 64,
            color: AppColors.success,
          ),
          const SizedBox(height: 16),
          Text(
            LocaleKeys.vitalsBpGuideSuccess.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(15),
              color: _textPrimary(context),
            ),
          ),
          if (_predictedHeartRate != null) ...[
            const SizedBox(height: 16),
            Card(
              color: AppColors.primary.withValues(alpha: 0.05),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.favorite, color: AppColors.error),
                    const SizedBox(width: 8),
                    Text(
                      '$_predictedHeartRate BPM',
                      style: TextStyle(
                        fontSize: context.sp(18),
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _systolicController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.vitalsSystolic.tr(),
                    suffixText: LocaleKeys.homeMmHg.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return LocaleKeys.errorsRequiredField.tr();
                    }
                    final n = int.tryParse(val);
                    if (n == null || n <= 0) {
                      return LocaleKeys.errorsRequiredField.tr();
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  controller: _diastolicController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.vitalsDiastolic.tr(),
                    suffixText: LocaleKeys.homeMmHg.tr(),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return LocaleKeys.errorsRequiredField.tr();
                    }
                    final n = int.tryParse(val);
                    if (n == null || n <= 0) {
                      return LocaleKeys.errorsRequiredField.tr();
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavButtons() {
    final bool showPrev = (_currentStep == 1 || _currentStep == 2) &&
        !widget.quickRecalibration &&
        !_isMeasuring &&
        !_measurementComplete;
    final bool showNext = _currentStep < 2;
    final bool requirementMet = _stepRequirementMet(_currentStep);
    final bool showRegularFinish =
        !_calibrationRequired && _currentStep == 2 && _measurementComplete;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showNext && !requirementMet)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.warning, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _currentStep == 0
                        ? 'vitals.bp_guide_next_disabled_device'.tr()
                        : 'vitals.bp_guide_next_disabled_sensors'.tr(),
                    style: TextStyle(
                      color: AppColors.warning,
                      fontSize: context.sp(12.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (showPrev)
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _currentStep--;
                  });
                },
                child: Text(LocaleKeys.back.tr()),
              )
            else
              const SizedBox.shrink(),
            if (showNext)
              ElevatedButton(
                onPressed: requirementMet
                    ? () {
                        setState(() {
                          _currentStep++;
                        });
                      }
                    : null,
                child: Text(LocaleKeys.next.tr()),
              )
            else if (_calibrationRequired && _currentStep == 3)
              Expanded(
                child: ElevatedButton(
                  onPressed: _isMeasuring ? null : _submitCuffReading,
                  child: _isMeasuring
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.white),
                        )
                      : Text(LocaleKeys.done.tr()),
                ),
              )
            else if (showRegularFinish)
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(LocaleKeys.done.tr()),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Shown after a non-dangerous cuff entry is saved -- surfaces the final
  /// recorded BP value before returning, instead of a fire-and-forget
  /// SnackBar the patient could easily miss.
  void _showFinalResultDialog(BuildContext context, dynamic vital) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.success, size: 28),
              const SizedBox(width: 8),
              Text(
                LocaleKeys.success.tr(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: dialogContext.sp(18),
                  color: _textPrimary(dialogContext),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Directionality(
                textDirection: ui.TextDirection.ltr,
                child: Text(
                  '${vital.systolic} / ${vital.diastolic}',
                  style: TextStyle(
                    fontSize: dialogContext.sp(36),
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                LocaleKeys.homeMmHg.tr(),
                style: TextStyle(
                  fontSize: dialogContext.sp(13),
                  color: _textSecondary(dialogContext),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close guide page
              },
              child: Text(LocaleKeys.done.tr()),
            ),
          ],
        );
      },
    );
  }

  void _showRiskDiagnosticDialog(BuildContext context, dynamic vital) {
    showDialog(
      context: context,
      barrierDismissible: false, // Must address this alert
      builder: (dialogContext) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.riskHigh, size: 28),
              const SizedBox(width: 8),
              Text(
                'vitals.bp_warning_title'.tr(),
                style: TextStyle(
                  color: AppColors.riskHigh,
                  fontWeight: FontWeight.bold,
                  fontSize: dialogContext.sp(18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vitals.bp_warning_message'.tr(
                  namedArgs: {
                    'reading': '${vital.systolic}/${vital.diastolic}'
                  },
                ),
                style: TextStyle(
                  fontSize: dialogContext.sp(14),
                  fontWeight: FontWeight.w500,
                  color: _textPrimary(dialogContext),
                ),
              ),
              const SizedBox(height: 16),
              _buildBulletPoint(
                  dialogContext, "• ${'vitals.bp_symptom_headache'.tr()}"),
              _buildBulletPoint(
                  dialogContext, "• ${'vitals.bp_symptom_dizziness'.tr()}"),
              _buildBulletPoint(
                  dialogContext, "• ${'vitals.bp_symptom_chest_pain'.tr()}"),
              _buildBulletPoint(
                  dialogContext, "• ${'vitals.bp_symptom_breathless'.tr()}"),
              _buildBulletPoint(dialogContext,
                  "• ${'vitals.bp_symptom_blurred_vision'.tr()}"),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close guide page
              },
              child: Text('vitals.bp_warning_no'.tr()),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.riskHigh,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext); // Close dialog
                Navigator.pop(context); // Close guide page
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        SymptomCheckerWizardPage(initialBpReading: vital),
                  ),
                );
              },
              child: Text('vitals.bp_warning_yes'.tr()),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _textSecondary(context),
        ),
      ),
    );
  }
}

/// A subtle pulsing ring drawn behind a status icon to draw the eye of a
/// non-technical user toward whichever sensor still needs attention.
class _PulsingStatusIcon extends StatefulWidget {
  final IconData icon;
  final bool active;
  final Color color;

  const _PulsingStatusIcon({
    required this.icon,
    required this.active,
    required this.color,
  });

  @override
  State<_PulsingStatusIcon> createState() => _PulsingStatusIconState();
}

class _PulsingStatusIconState extends State<_PulsingStatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 52,
      height: 52,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = widget.active ? _controller.value : 0.0;
          return Stack(
            alignment: Alignment.center,
            children: [
              if (widget.active)
                Container(
                  width: 44 + 14 * t,
                  height: 44 + 14 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: (1 - t) * 0.35),
                  ),
                ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.12),
                ),
                alignment: Alignment.center,
                child: Icon(widget.icon, color: widget.color, size: 24),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Self-contained illustrative animation (no external assets) looping the
/// fingertip-insertion motion, so non-technical / elderly users can see
/// exactly how to place the finger clip.
class _PPGTutorialAnimation extends StatefulWidget {
  const _PPGTutorialAnimation();

  @override
  State<_PPGTutorialAnimation> createState() => _PPGTutorialAnimationState();
}

class _PPGTutorialAnimationState extends State<_PPGTutorialAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 170,
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.primaryDark : AppColors.primary)
            .withValues(alpha: isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _PPGTutorialPainter(_controller.value, isDark),
          );
        },
      ),
    );
  }
}

class _PPGTutorialPainter extends CustomPainter {
  final double value;
  final bool isDark;

  _PPGTutorialPainter(this.value, this.isDark);

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final primary = AppColors.primary;
    final success = AppColors.success;
    final muted =
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
            .withValues(alpha: 0.6);
    final t = value;

    // Clip (sensor) body
    final clipRect =
        Rect.fromCenter(center: Offset(cx + 40, cy), width: 70, height: 46);
    final clipPaint = Paint()
      ..color = primary.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(clipRect, const Radius.circular(12)),
      clipPaint,
    );

    // Blinking LED
    final ledOpacity = (math.sin(t * 2 * math.pi * 3) + 1) / 2;
    canvas.drawCircle(
      Offset(clipRect.right - 10, clipRect.top + 10),
      3.5,
      Paint()
        ..color = Colors.redAccent.withValues(alpha: 0.4 + ledOpacity * 0.6),
    );

    // Finger sliding in, then holding, then a success pulse, looping.
    final insertT = (t / 0.6).clamp(0.0, 1.0);
    final fingerX = _lerp(cx - 110, clipRect.center.dx - 6, insertT);
    final fingerRect =
        Rect.fromCenter(center: Offset(fingerX, cy), width: 34, height: 72);
    final fingerPaint = Paint()..color = const Color(0xFFE8B08C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fingerRect, const Radius.circular(17)),
      fingerPaint,
    );

    if (t > 0.6) {
      final holdT = ((t - 0.6) / 0.4).clamp(0.0, 1.0);
      final ringRadius = 34 + 10 * (math.sin(holdT * 2 * math.pi));
      canvas.drawCircle(
        clipRect.center,
        ringRadius,
        Paint()
          ..color = success.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // Guiding arrow
    if (t < 0.6) {
      final arrowPaint = Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      final arrowY = cy + 46;
      canvas.drawLine(
          Offset(cx - 90, arrowY), Offset(cx - 20, arrowY), arrowPaint);
      canvas.drawLine(
          Offset(cx - 28, arrowY - 6), Offset(cx - 20, arrowY), arrowPaint);
      canvas.drawLine(
          Offset(cx - 28, arrowY + 6), Offset(cx - 20, arrowY), arrowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _PPGTutorialPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

/// Simplified torso diagram showing the three chest-electrode positions
/// using the confirmed cable convention: RED = upper right chest below the
/// collarbone, YELLOW = upper left chest below the collarbone, GREEN = lower
/// right torso below the ribs. Dots pulse in sequence to draw the eye.
class _ECGTutorialAnimation extends StatefulWidget {
  const _ECGTutorialAnimation();

  @override
  State<_ECGTutorialAnimation> createState() => _ECGTutorialAnimationState();
}

class _ECGTutorialAnimationState extends State<_ECGTutorialAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 190,
      width: double.infinity,
      decoration: BoxDecoration(
        color: (isDark ? AppColors.primaryDark : AppColors.primary)
            .withValues(alpha: isDark ? 0.15 : 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ECGTutorialPainter(_controller.value, isDark),
          );
        },
      ),
    );
  }
}

class _ECGTutorialPainter extends CustomPainter {
  final double value;
  final bool isDark;

  _ECGTutorialPainter(this.value, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final muted =
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary)
            .withValues(alpha: 0.6);

    // Simple torso silhouette
    final torsoPath = Path()
      ..moveTo(cx - 45, cy - 65)
      ..quadraticBezierTo(cx - 62, cy - 25, cx - 50, cy + 65)
      ..lineTo(cx + 50, cy + 65)
      ..quadraticBezierTo(cx + 62, cy - 25, cx + 45, cy - 65)
      ..quadraticBezierTo(cx, cy - 82, cx - 45, cy - 65)
      ..close();
    canvas.drawPath(torsoPath, Paint()..color = muted.withValues(alpha: 0.25));
    canvas.drawPath(
      torsoPath,
      Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Collarbone guide line
    canvas.drawLine(
      Offset(cx - 40, cy - 42),
      Offset(cx + 40, cy - 42),
      Paint()
        ..color = muted.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    final electrodes = [
      (
        Offset(cx + 26, cy - 30),
        Colors.redAccent
      ), // RED: upper right, below collarbone
      (
        Offset(cx - 26, cy - 30),
        const Color(0xFFE8C547)
      ), // YELLOW: upper left, below collarbone
      (
        Offset(cx + 22, cy + 40),
        AppColors.success
      ), // GREEN: lower right, below ribs
    ];

    final activeIndex = ((value * 3).floor()).clamp(0, 2);
    for (var i = 0; i < electrodes.length; i++) {
      final (pos, color) = electrodes[i];
      final isPulsing = i == activeIndex;
      final pulseT = isPulsing ? (value * 3 - activeIndex) : 0.0;
      final pulse =
          isPulsing ? (math.sin(pulseT * 2 * math.pi * 2) + 1) / 2 : 0.0;
      canvas.drawCircle(
        pos,
        9 + (isPulsing ? pulse * 3 : 0),
        Paint()..color = color.withValues(alpha: 0.9),
      );
      canvas.drawCircle(
        pos,
        9,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ECGTutorialPainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _WavePainter extends CustomPainter {
  final double value;
  final Color color;

  _WavePainter(this.value, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    final path = Path();
    final step = size.width / 100;

    path.moveTo(0, size.height / 2);
    for (int i = 0; i <= 100; i++) {
      final x = i * step;
      // Combine normal heartbeat pulses with animation timeline value
      final xScaled = (i / 10) - (value * 2 * math.pi);
      double y = size.height / 2;

      // Basic heartbeat shape trigger
      final cardiacTrigger = (i % 25 == 0) ? 1.0 : 0.0;
      if (cardiacTrigger > 0) {
        y -= 25.0 * math.sin(value * 2 * math.pi);
      } else {
        y += 5.0 * math.sin(xScaled * 1.5);
      }

      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}
