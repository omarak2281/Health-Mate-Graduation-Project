import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/bp_reminder_alarm_provider.dart';
import '../../../medications/presentation/widgets/alarm/alarm_action_button.dart';
import '../../../medications/presentation/widgets/alarm/alarm_pulsing_icon.dart';
import '../../../medications/presentation/widgets/alarm/alarm_snooze_banner.dart';
import 'bp_measurement_guide_page.dart';

import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/push_notification_service.dart';

/// Full-screen ringing alarm for the scheduled BP measurement reminder,
/// mirroring MedicationAlarmPage's ring/vibrate/snooze/dismiss behavior
/// instead of silently opening the measurement walkthrough.
class BPReminderAlarmPage extends ConsumerStatefulWidget {
  final bool initialSnooze;

  const BPReminderAlarmPage({super.key, this.initialSnooze = false});

  @override
  ConsumerState<BPReminderAlarmPage> createState() =>
      _BPReminderAlarmPageState();
}

class _BPReminderAlarmPageState extends ConsumerState<BPReminderAlarmPage> {
  late AudioPlayer _audioPlayer;
  bool _isRinging = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();

    if (!widget.initialSnooze) {
      _startAlarm();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(bpReminderAlarmNotifierProvider.notifier)
            .snooze(skipNotificationCancel: true);
      });
    }
  }

  Future<void> _startAlarm() async {
    await LocalNotificationService.instance.cancelAllAlarms();

    try {
      _isRinging = true;
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);

      try {
        await _audioPlayer.play(AssetSource('audio/alarm.wav'));
      } catch (assetError) {
        await SystemSound.play(SystemSoundType.alert);
      }

      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
      }
    } catch (e) {
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
    ref.listen(bpReminderAlarmNotifierProvider, (previous, next) {
      if (previous?.isSnoozed == true && next.isSnoozed == false) {
        _startAlarm();
      }
    });

    final state = ref.watch(bpReminderAlarmNotifierProvider);
    final notifier = ref.read(bpReminderAlarmNotifierProvider.notifier);
    const accentColor = AppColors.expertTeal;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.surfaceDark, AppColors.backgroundDark],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const AlarmPulsingIcon(
                  iconData: Icons.favorite_rounded,
                  glowColor: accentColor,
                ),
                const SizedBox(height: 40),
                Column(
                  children: [
                    Text(
                      LocaleKeys.vitalsBpReminderKicker.tr().toUpperCase(),
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
                        LocaleKeys.vitalsBpReminderTitle.tr(),
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
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceDark,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: accentColor.withValues(alpha: 0.12)),
                    ),
                    child: Text(
                      LocaleKeys.vitalsBpReminderBody.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.white70,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ),
                ),
                const Spacer(flex: 2),
                if (state.isSnoozed)
                  AlarmSnoozeBanner(remaining: state.snoozeRemaining),
                const Spacer(flex: 3),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Row(
                    children: [
                      AlarmActionButton(
                        onTap: state.isSnoozed
                            ? null
                            : () async {
                                await _stopAlarm();
                                await notifier.snooze();
                              },
                        label: LocaleKeys.medicationsSnooze.tr(),
                        icon: Icons.snooze_rounded,
                        backgroundColor: AppColors.cardDark,
                        foregroundColor: state.isSnoozed
                            ? AppColors.white24
                            : AppColors.white70,
                      ),
                      const SizedBox(width: 16),
                      AlarmActionButton(
                        onTap: () async {
                          await _stopAlarm();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const BPMeasurementGuidePage(),
                              ),
                            );
                          }
                        },
                        label: LocaleKeys.vitalsBpMeasureNow.tr(),
                        icon: Icons.monitor_heart_rounded,
                        backgroundColor: accentColor,
                        foregroundColor: AppColors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
