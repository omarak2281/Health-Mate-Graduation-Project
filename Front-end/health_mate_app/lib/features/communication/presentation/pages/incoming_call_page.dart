import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:vibration/vibration.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/services/local_notification_service.dart';
import '../../../../core/services/socket_service.dart';
import '../controllers/call_controller.dart';
import 'call_page.dart';

/// Incoming Call Screen
/// Shown when receiving a call offer

class IncomingCallPage extends ConsumerStatefulWidget {
  final String callerName;
  final String callerId;
  final bool isVideo;
  final String? callId;
  final String? callerImage;
  final String? offerSdp;
  final String? offerType;

  const IncomingCallPage({
    super.key,
    required this.callerName,
    required this.callerId,
    required this.isVideo,
    this.callId,
    this.callerImage,
    this.offerSdp,
    this.offerType,
  });

  @override
  ConsumerState<IncomingCallPage> createState() => _IncomingCallPageState();
}

class _IncomingCallPageState extends ConsumerState<IncomingCallPage> {
  bool _dismissed = false;
  Timer? _statusPoll;

  @override
  void initState() {
    super.initState();
    _startIncomingFeedback();
    // If the caller hangs up (or the call goes stale) while this ringing
    // screen is still showing, nothing else would ever close it -- the
    // callee would be left ringing at a call that no longer exists.
    final socket = ref.read(socketServiceProvider);
    socket.onCallEnded((data) => _dismissIfMatchingSession(data));
    socket.onCallDeclined((data) => _dismissIfMatchingSession(data));

    // Socket delivery isn't guaranteed (reconnect gaps, backgrounding), so
    // poll the call's REST status as a fallback -- it's the one source of
    // truth both sides always agree on.
    if (widget.callId != null) {
      _statusPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
        final session =
            await ref.read(callControllerProvider.notifier).getCall(widget.callId!);
        if (session != null && session.status != 'ringing') {
          _dismissIfMatchingSession({'sessionId': widget.callId});
        }
      });
    }
  }

  void _dismissIfMatchingSession(dynamic data) {
    final sessionId = data is Map ? data['sessionId']?.toString() : null;
    if (widget.callId != null && sessionId != widget.callId) return;
    if (_dismissed || !mounted) return;
    _dismissed = true;
    _stopIncomingFeedback();
    Navigator.of(context).pop();
  }

  Future<void> _startIncomingFeedback() async {
    // The actual ring comes from the persistent, insistent-looping system
    // notification (see LocalNotificationService.showIncomingCall) which
    // stays posted for as long as this screen is up -- we only need to
    // add vibration here, not a second competing sound.
    try {
      if (await Vibration.hasVibrator()) {
        Vibration.vibrate(pattern: [0, 900, 500, 900], repeat: 0);
      }
    } catch (_) {}
  }

  Future<void> _stopIncomingFeedback() async {
    _statusPoll?.cancel();
    try {
      Vibration.cancel();
    } catch (_) {}
    if (widget.callId != null) {
      await LocalNotificationService.instance.cancelIncomingCall(widget.callId!);
    }
  }

  Future<void> _declineCall() async {
    if (_dismissed) return;
    _dismissed = true;
    await _stopIncomingFeedback();
    if (widget.callId != null) {
      await ref.read(callControllerProvider.notifier).rejectCall(widget.callId!);
      ref.read(socketServiceProvider).sendCallDeclined({
        'target': widget.callerId,
        'sessionId': widget.callId,
      });
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _acceptCall() async {
    if (_dismissed) return;
    _dismissed = true;
    await _stopIncomingFeedback();
    var offerSdp = widget.offerSdp;
    var offerType = widget.offerType ?? 'offer';

    if ((offerSdp == null || offerSdp.trim().isEmpty) &&
        widget.callId != null) {
      final session =
          await ref.read(callControllerProvider.notifier).getCall(widget.callId!);
      offerSdp = session?.offerSdp;
      offerType = 'offer';
    }

    if (offerSdp == null || offerSdp.trim().isEmpty) {
      if (mounted) Navigator.pop(context);
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: widget.isVideo,
          contactName: widget.callerName,
          contactImage: widget.callerImage,
          contactId: widget.callerId,
          isCaller: false,
          callId: widget.callId,
          remoteOfferSdp: offerSdp,
          remoteOfferType: offerType,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _statusPoll?.cancel();
    try {
      Vibration.cancel();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (widget.callerImage ?? '').trim().isNotEmpty;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.95),
              const Color(0xFF0a1f1c),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.1),
              Text(
                widget.isVideo
                    ? LocaleKeys.communicationIncomingVideoCall.tr()
                    : LocaleKeys.communicationIncomingAudioCall.tr(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3), width: 2),
                ),
                child: CircleAvatar(
                  radius: 64,
                  backgroundColor: Colors.white.withValues(alpha: 0.15),
                  backgroundImage: hasImage
                      ? NetworkImage(widget.callerImage!.trim())
                      : null,
                  child: !hasImage
                      ? Text(
                          widget.callerName.isNotEmpty
                              ? widget.callerName.substring(0, 1).toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.callerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _CallCircleButton(
                      icon: Icons.call_end_rounded,
                      backgroundColor: AppColors.error,
                      label: LocaleKeys.communicationDecline.tr(),
                      onTap: _declineCall,
                    ),
                    _CallCircleButton(
                      icon: Icons.call_rounded,
                      backgroundColor: AppColors.success,
                      label: LocaleKeys.communicationAccept.tr(),
                      onTap: _acceptCall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final String label;
  final VoidCallback onTap;

  const _CallCircleButton({
    required this.icon,
    required this.backgroundColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(22),
            backgroundColor: backgroundColor,
            elevation: 6,
          ),
          child: Icon(icon, size: 32, color: Colors.white),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
