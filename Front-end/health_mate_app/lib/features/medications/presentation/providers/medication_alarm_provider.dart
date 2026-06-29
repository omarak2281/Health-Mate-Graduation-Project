import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/constants/iot_constants.dart';
import '../../../../core/services/iot_service.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/models/medication.dart';
import '../../data/medications_repository.dart';
import './medications_provider.dart';

// ─── Alarm State ──────────────────────────────────────────────────────────────

class MedicationAlarmState {
  final bool isTakenLoading;
  final bool isSnoozeLoading;
  final bool isSnoozed;
  final Duration snoozeRemaining;

  const MedicationAlarmState({
    this.isTakenLoading = false,
    this.isSnoozeLoading = false,
    this.isSnoozed = false,
    this.snoozeRemaining = Duration.zero,
  });

  MedicationAlarmState copyWith({
    bool? isTakenLoading,
    bool? isSnoozeLoading,
    bool? isSnoozed,
    Duration? snoozeRemaining,
  }) {
    return MedicationAlarmState(
      isTakenLoading: isTakenLoading ?? this.isTakenLoading,
      isSnoozeLoading: isSnoozeLoading ?? this.isSnoozeLoading,
      isSnoozed: isSnoozed ?? this.isSnoozed,
      snoozeRemaining: snoozeRemaining ?? this.snoozeRemaining,
    );
  }
}

// ─── Alarm Notifier ───────────────────────────────────────────────────────────

class MedicationAlarmNotifier extends StateNotifier<MedicationAlarmState> {
  final IoTService _iotService;
  final MedicationsRepository _medicationsRepository;
  final MedicationsNotifier _medicationsNotifier;
  final LocalNotificationService _localNotifications;
  final List<Medication> medications;

  Timer? _snoozeTimer;
  Timer? _countdownTimer;
  Timer? _autoSnoozeTimer;

  MedicationAlarmNotifier({
    required IoTService iotService,
    required MedicationsRepository medicationsRepository,
    required MedicationsNotifier medicationsNotifier,
    required LocalNotificationService localNotifications,
    required this.medications,
  })  : _iotService = iotService,
        _medicationsRepository = medicationsRepository,
        _medicationsNotifier = medicationsNotifier,
        _localNotifications = localNotifications,
        super(const MedicationAlarmState()) {
    // Auto-Snooze: If no action is taken within 5 minutes, snooze automatically
    _autoSnoozeTimer?.cancel();
    _autoSnoozeTimer = Timer(const Duration(minutes: 5), () {
      if (mounted && !state.isSnoozed) {
        snooze();
      }
    });
  }

  Future<void> markTaken() async {
    state = state.copyWith(isTakenLoading: true);
    _snoozeTimer?.cancel();
    _countdownTimer?.cancel();
    _autoSnoozeTimer?.cancel();

    await _localNotifications.cancelAllAlarms();
    final medIds = medications.map((m) => m.id).toList();

    try {
      await Future.wait([
        _iotService.controlDrawers([]),
        _medicationsNotifier.confirmMultipleMedicationsTaken(medIds),
      ]);
    } finally {
      state = state.copyWith(isTakenLoading: false);
    }
  }

  Future<void> snooze() async {
    state = state.copyWith(isSnoozeLoading: true);
    _autoSnoozeTimer?.cancel();

    try {
      await _medicationsRepository
          .snoozeHardware()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('⚠️ [Snooze] Hardware silence failed: $e');
    }

    final snoozeDuration =
        Duration(minutes: IoTConstants.snoozeDurationMinutes);
    final medIds = medications.map((m) => m.id).toList();

    state = state.copyWith(
      isSnoozeLoading: false,
      isSnoozed: true,
      snoozeRemaining: snoozeDuration,
    );

    // ☁️ CLOUD SNOOZE: Tell the backend to remind us in 5 minutes
    // This is 100% reliable even if the app process is killed.
    try {
      await _medicationsRepository.snoozeMedications(medIds);
      debugPrint('✅ [Snooze] Cloud snooze scheduled successfully');
    } catch (e) {
      debugPrint(
          '⚠️ [Snooze] Cloud snooze failed (falling back to local timer): $e');
    }

    await _localNotifications.cancelAllAlarms();

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _countdownTimer?.cancel();
        return;
      }
      final remaining = state.snoozeRemaining - const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _countdownTimer?.cancel();

        // 🚀 RE-TRIGGER HARDWARE when snooze expires
        final drawers = medications
            .where((m) => m.hasDrawer())
            .map((m) => m.drawerNumber!)
            .toList();
        if (drawers.isNotEmpty) {
          debugPrint(
              '⏰ [Snooze] Timer expired! Re-triggering hardware drawers: $drawers');
          _iotService.controlDrawers(drawers);
        }

        // 🌟 FORCE APP TO FOREGROUND so the UI can play sound/ring
        try {
          const platform = MethodChannel('com.example.health_mate_app/app');
          platform.invokeMethod('bringToForeground');
        } catch (e) {
          debugPrint('⚠️ [Snooze] Failed to bring app to foreground: $e');
        }

        state =
            state.copyWith(isSnoozed: false, snoozeRemaining: Duration.zero);
      } else {
        state = state.copyWith(snoozeRemaining: remaining);
      }
    });

    try {
      final medName = medications.length == 1
          ? medications.first.name
          : LocaleKeys.medicationsMyMedications.tr();
      final snoozeTitle = LocaleKeys.medicationsAlarmTitle.tr();
      final snoozeBody =
          LocaleKeys.medicationsTimeToTake.tr(namedArgs: {'name': medName});
      final snoozePayload = jsonEncode({
        'type': medications.length == 1 ? 'single' : 'grouped',
        medications.length == 1 ? 'medicine' : 'medicines':
            medications.length == 1
                ? medications.first.toJson()
                : medications.map((m) => m.toJson()).toList(),
      });

      await _localNotifications.scheduleSnoozeReminder(
        id: LocalNotificationService.defaultSnoozeId,
        title: snoozeTitle,
        body: snoozeBody,
        delay: snoozeDuration,
        payload: snoozePayload,
      );
    } catch (e) {
      debugPrint('❌ [Snooze] Notification schedule error: $e');
    }
  }

  @override
  void dispose() {
    _snoozeTimer?.cancel();
    _countdownTimer?.cancel();
    _autoSnoozeTimer?.cancel();
    super.dispose();
  }
}

final medicationAlarmNotifierProvider = StateNotifierProvider.family<
    MedicationAlarmNotifier, MedicationAlarmState, List<Medication>>(
  (ref, medications) => MedicationAlarmNotifier(
    iotService: ref.watch(iotServiceProvider),
    medicationsRepository: ref.watch(medicationsRepositoryProvider),
    medicationsNotifier: ref.read(medicationsNotifierProvider.notifier),
    localNotifications: ref.watch(localNotificationServiceProvider),
    medications: medications,
  ),
);
