import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/medication.dart';
import '../providers/medication_alarm_provider.dart';
import '../widgets/alarm/alarm_action_button.dart';
import '../widgets/alarm/alarm_pulsing_icon.dart';
import '../widgets/alarm/alarm_info_card.dart';
import '../widgets/alarm/alarm_drawer_badge.dart';
import '../widgets/alarm/alarm_snooze_banner.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../home/presentation/pages/patient_home_page.dart';
import '../../../home/presentation/pages/caregiver_home_page.dart';
import '../../../../core/providers/navigation_provider.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/push_notification_service.dart';

class MedicationAlarmPage extends ConsumerStatefulWidget {
  final List<Medication> medications;
  final bool initialSnooze; // ✅ New flag

  const MedicationAlarmPage({
    super.key,
    required this.medications,
    this.initialSnooze = false,
  });

  @override
  ConsumerState<MedicationAlarmPage> createState() =>
      _MedicationAlarmPageState();
}

class _MedicationAlarmPageState extends ConsumerState<MedicationAlarmPage> {
  late AudioPlayer _audioPlayer;
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    // Only start sound if we aren't already in snooze mode
    if (!widget.initialSnooze) {
      _startAlarm();
    } else {
      // If we are already snoozed, ensure hardware is off (safety)
      // and let the notifier know it should enter snooze state
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The hardware-silence + cloud-snooze calls were already made by
        // PushNotificationService.handleNotificationAction before this page
        // was pushed -- skip them here to avoid a duplicate scheduler job.
        ref
            .read(medicationAlarmNotifierProvider(widget.medications).notifier)
            .snooze(skipNetworkCalls: true);
      });
    }
  }

  Future<void> _startAlarm() async {
    // 🛑 Cancel the system notification IMMEDIATELY so we don't have double sound
    await LocalNotificationService.instance.cancelAllAlarms();

    try {
      _isRinging = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      // Try local asset first; fall back to a system beep via HapticFeedback
      try {
        await _audioPlayer.play(AssetSource('audio/alarm.wav'));
      } catch (assetError) {
        debugPrint(
            '[AlarmPage] Local asset not found, using system sound: $assetError');
        // Use system notification sound as the reliable fallback
        await SystemSound.play(SystemSoundType.alert);
      }

      // Start vibration pattern
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
      debugPrint('[AlarmPage] Error starting alarm sound: $e');
      // Ensure at minimum the vibration fires
      try {
        if (await Vibration.hasVibrator()) {
          Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
        }
      } catch (_) {}
    }
  }

  Future<void> _stopAlarm() async {
    if (_isRinging) {
      try {
        await _audioPlayer.stop();
      } catch (_) {}
      try {
        Vibration.cancel();
      } catch (_) {}

      // ✅ Cancel the system notification (stops looping sound/banner)
      await LocalNotificationService.instance.cancelAllAlarms();

      _isRinging = false;
    }
  }

  @override
  void dispose() {
    _stopAlarm();
    _audioPlayer.dispose();
    PushNotificationService.instance.notifyAlarmScreenClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final medications = widget.medications;

    // 🎧 Listen for snooze expiration to restart UI-side alarm (sound/vibration)
    ref.listen(medicationAlarmNotifierProvider(medications), (previous, next) {
      if (previous?.isSnoozed == true && next.isSnoozed == false) {
        debugPrint('⏰ [Snooze] Expired! Re-triggering UI alarm...');
        _startAlarm();
      }
    });

    final state = ref.watch(medicationAlarmNotifierProvider(medications));
    final notifier =
        ref.read(medicationAlarmNotifierProvider(medications).notifier);

    // Listen for snooze state to navigate away automatically (for both manual and auto-snooze)
    ref.listen<MedicationAlarmState>(
      medicationAlarmNotifierProvider(medications),
      (previous, next) {
        if (next.isSnoozed && !(previous?.isSnoozed ?? false)) {
          _navigateHome(ref, isSnooze: true);
        }
      },
    );

    final accentColor = AppColors.expertTeal;
    final isGrouped = medications.length > 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          _buildBackgroundGradient(),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildAlarmIcon(medications, isGrouped, accentColor),
                const SizedBox(height: 40),
                _buildMedicationHeader(medications, accentColor),
                const SizedBox(height: 16),
                _buildDrawerBadges(medications, accentColor),
                const Spacer(flex: 2),
                _buildInfoSection(medications, isGrouped, accentColor),
                const SizedBox(height: 24),
                if (state.isSnoozed)
                  AlarmSnoozeBanner(remaining: state.snoozeRemaining),
                const Spacer(flex: 3),
                _buildActionButtons(context, state, notifier, accentColor),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradient() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.surfaceDark, AppColors.backgroundDark],
        ),
      ),
    );
  }

  Widget _buildAlarmIcon(
      List<Medication> meds, bool isGrouped, Color accentColor) {
    if (!isGrouped) {
      return AlarmPulsingIcon(
        imageUrl: meds.first.imageUrl,
        glowColor: accentColor,
      );
    }
    return AlarmPulsingIcon(
      iconData: Icons.medication_liquid_rounded,
      glowColor: accentColor,
    );
  }

  Widget _buildMedicationHeader(List<Medication> meds, Color accentColor) {
    final titleText = meds.length == 1
        ? meds.first.name
        : LocaleKeys.medicationsMultipleTitle
            .tr(args: [meds.length.toString()]);

    return Column(
      children: [
        Text(
          LocaleKeys.medicationsTimeTo.tr().toUpperCase(),
          style: TextStyle(
            color: accentColor.withValues(alpha: 0.6),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            titleText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawerBadges(List<Medication> meds, Color accentColor) {
    final drawers = meds
        .where((m) => m.hasDrawer())
        .map((m) => m.drawerNumber!)
        .toSet()
        .toList();

    if (drawers.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: drawers
          .map((drawerNum) =>
              AlarmDrawerBadge(drawerNumber: drawerNum, glowColor: accentColor))
          .toList(),
    );
  }

  Widget _buildInfoSection(
      List<Medication> meds, bool isGrouped, Color accentColor) {
    if (!isGrouped) {
      return AlarmInfoCard(medication: meds.first, accentColor: accentColor);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.35,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accentColor.withValues(alpha: 0.12)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            itemCount: meds.length,
            separatorBuilder: (context, index) =>
                const Divider(color: AppColors.white12, height: 24),
            itemBuilder: (context, index) {
              final med = meds[index];
              return Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(med.name,
                            style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 17)),
                        const SizedBox(height: 4),
                        Text(
                            '${med.dosage} • ${_getLocalizedTime(context, med.scheduledTimes.isNotEmpty ? med.scheduledTimes.first : "")}',
                            style: const TextStyle(
                                color: AppColors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (med.hasDrawer())
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                          LocaleKeys.medicationsDrawerShort.tr(
                              namedArgs: {'num': med.drawerNumber.toString()}),
                          style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 12)),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, MedicationAlarmState state,
      MedicationAlarmNotifier notifier, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Row(
        children: [
          AlarmActionButton(
            onTap: state.isSnoozed
                ? null
                : () async {
                    await _stopAlarm();
                    // Navigation is handled by ref.listen when isSnoozed → true.
                    // Do NOT call _navigateHome here to avoid double navigation.
                    await notifier.snooze();
                  },
            label: LocaleKeys.medicationsSnooze.tr(),
            icon: Icons.snooze_rounded,
            backgroundColor: AppColors.cardDark,
            foregroundColor:
                state.isSnoozed ? AppColors.white24 : AppColors.white70,
            isLoading: state.isSnoozeLoading,
          ),
          const SizedBox(width: 16),
          AlarmActionButton(
            onTap: () async {
              await _stopAlarm();
              await notifier.markTaken();
              if (context.mounted) {
                _navigateHome(ref, isSnooze: false);
              }
            },
            label: LocaleKeys.medicationsTakeNow.tr(),
            icon: Icons.check_circle_rounded,
            backgroundColor: accentColor,
            foregroundColor: AppColors.white,
            isLoading: state.isTakenLoading,
          ),
        ],
      ),
    );
  }

  void _navigateHome(WidgetRef ref, {required bool isSnooze}) {
    // 1. Reset navigation index to Dashboard (0)
    ref.read(navigationProvider.notifier).setIndex(0);

    final state = ref.read(authNotifierProvider);
    final Widget homeScreen = (state.user?.isPatient ?? true)
        ? const PatientHomePage()
        : const CaregiverHomePage();

    // 2. Clear stack and go home
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => homeScreen),
      (route) => false,
    );

    // 3. Complete navigation and return control to the system.
    // If it was Snooze, we move the app to BACKGROUND (like pressing the Home button).
    // Using `false` is critical — it does NOT finish/destroy the Activity,
    // which keeps the Flutter process alive so the OS can bring it back
    // when the scheduled snooze notification fires.
    if (isSnooze) {
      debugPrint('💤 [Snooze] Minimizing app to stay alive...');
      Future.delayed(const Duration(milliseconds: 1000), () async {
        try {
          const platform = MethodChannel('com.example.health_mate_app/app');
          await platform.invokeMethod('minimizeApp');
        } catch (e) {
          debugPrint('❌ Error minimizing app: $e');
        }
      });
    }
  }

  String _getLocalizedTime(BuildContext context, String timeStr) {
    if (timeStr.isEmpty) return "--:--";
    try {
      final parts = timeStr.split(':');
      final tod =
          TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      return tod.format(context);
    } catch (e) {
      return timeStr;
    }
  }
}
