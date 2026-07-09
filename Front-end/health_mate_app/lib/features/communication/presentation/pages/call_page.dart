import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../controllers/call_controller.dart';

/// Call Page
/// Fully functional WebRTC Video/Audio Call

class CallPage extends ConsumerStatefulWidget {
  final bool isVideo;
  final String contactName;
  final String? contactImage;
  final String contactId;
  final bool isCaller; // true if initiating, false if answering
  final String? callId;
  final String? remoteOfferSdp;
  final String? remoteOfferType;

  const CallPage({
    super.key,
    required this.isVideo,
    required this.contactName,
    this.contactImage,
    required this.contactId,
    required this.isCaller,
    this.callId,
    this.remoteOfferSdp,
    this.remoteOfferType,
  });

  @override
  ConsumerState<CallPage> createState() => _CallPageState();
}

class _CallPageState extends ConsumerState<CallPage> {
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  String? _callId;
  bool _starting = true;
  bool _connected = false;
  bool _ended = false;
  Timer? _durationTimer;
  Timer? _statusPoll;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId;
    _initializeCall();
  }

  Future<void> _initializeCall() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    await _startCall();
  }

  Future<void> _startCall() async {
    final socket = ref.read(socketServiceProvider);
    final currentUser = ref.read(authNotifierProvider).user;
    String? remoteOfferSdp = widget.remoteOfferSdp;
    String remoteOfferType = widget.remoteOfferType ?? 'offer';

    if (widget.isCaller) {
      final session = await ref
          .read(callControllerProvider.notifier)
          .startCall(calleeId: widget.contactId, isVideo: widget.isVideo);
      if (session == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      _callId = session.id;
    } else if (_callId != null) {
      if (remoteOfferSdp == null || remoteOfferSdp.trim().isEmpty) {
        final session =
            await ref.read(callControllerProvider.notifier).getCall(_callId!);
        remoteOfferSdp = session?.offerSdp;
      }
      if (remoteOfferSdp == null || remoteOfferSdp.trim().isEmpty) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final accepted =
          await ref.read(callControllerProvider.notifier).acceptCall(_callId!);
      if (accepted == null) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }

    _startStatusPoll();

    // 1. Create Peer Connection
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
      ],
    });

    // 2. Get User Media
    final mediaConstraints = {
      'audio': true,
      'video': widget.isVideo ? {'facingMode': 'user'} : false,
    };

    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localRenderer.srcObject = _localStream;

    // 3. Add tracks to peer connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // 4. Handle Remote Stream
    _peerConnection!.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {});
      }
    };

    // Start the visible call timer once media is actually flowing between
    // both peers, not from the moment we started dialing.
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _startDurationTimer();
      }
    };

    // 5. Handle ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      socket.sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'target': widget.contactId,
        'sessionId': _callId,
      });
    };

    // 6. Signaling Listeners
    socket.onCallAnswer((data) async {
      if (_peerConnection != null) {
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(data['sdp'], data['type']),
        );
      }
    });

    socket.onIceCandidate((data) async {
      if (_peerConnection != null) {
        await _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate'],
            data['sdpMid'],
            data['sdpMLineIndex'],
          ),
        );
      }
    });

    socket.onCallDeclined((data) => _handleRemoteHangup(data));
    socket.onCallEnded((data) => _handleRemoteHangup(data));

    // 7. Create Offer (if caller)
    if (widget.isCaller) {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      if (_callId != null && offer.sdp != null) {
        final savedOffer =
            await ref.read(callControllerProvider.notifier).sendOffer(
                  callId: _callId!,
                  sdp: offer.sdp!,
                  type: offer.type ?? 'offer',
                );
        if (savedOffer == null) {
          if (mounted) Navigator.of(context).pop();
          return;
        }
      }
      socket.sendOffer({
        'sdp': offer.sdp,
        'type': offer.type,
        'target': widget.contactId,
        'sessionId': _callId,
        'callerId': currentUser?.id,
        'callerName': currentUser?.fullName,
        'callerImage': currentUser?.profileImage,
        'isVideo': widget.isVideo,
      });
    } else if (remoteOfferSdp != null) {
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(remoteOfferSdp, remoteOfferType),
      );
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);
      socket.sendAnswer({
        'sdp': answer.sdp,
        'type': answer.type,
        'target': widget.contactId,
        'sessionId': _callId,
      });
    }

    if (mounted) {
      setState(() => _starting = false);
    }
  }

  // Socket delivery of call_ended/call_declined isn't guaranteed (reconnect
  // gaps, WebRTC setup briefly hogging the main thread). Poll the call's
  // REST status as a fallback so both sides always converge on the same
  // outcome even if the realtime event is missed.
  void _startStatusPoll() {
    if (_callId == null) return;
    _statusPoll = Timer.periodic(const Duration(seconds: 3), (_) async {
      final session =
          await ref.read(callControllerProvider.notifier).getCall(_callId!);
      if (session != null &&
          ['ended', 'rejected', 'busy'].contains(session.status)) {
        _handleRemoteHangup({'sessionId': _callId});
      }
    });
  }

  void _handleRemoteHangup(dynamic data) {
    final sessionId = data is Map ? data['sessionId']?.toString() : null;
    if (_callId != null && sessionId != null && sessionId != _callId) return;
    if (_ended || !mounted) return;
    _ended = true;
    Navigator.of(context).pop();
  }

  void _startDurationTimer() {
    if (_connected) return;
    _connected = true;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  String get _elapsedLabel {
    final minutes = _elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = _elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _statusPoll?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _localStream?.dispose();
    _peerConnection?.close();
    super.dispose();
  }

  void _toggleMic() {
    setState(() {
      _micEnabled = !_micEnabled;
      _localStream?.getAudioTracks().forEach((track) {
        track.enabled = _micEnabled;
      });
    });
  }

  void _toggleCamera() {
    if (!widget.isVideo) return;
    setState(() {
      _cameraEnabled = !_cameraEnabled;
      _localStream?.getVideoTracks().forEach((track) {
        track.enabled = _cameraEnabled;
      });
    });
  }

  void _endCall() {
    _ended = true;
    if (_callId != null) {
      ref.read(callControllerProvider.notifier).endCall(_callId!);
      ref.read(socketServiceProvider).sendCallEnded({
        'target': widget.contactId,
        'sessionId': _callId,
      });
    }
    Navigator.of(context).pop();
  }

  String get _statusLabel {
    if (_starting) return LocaleKeys.communicationConnecting.tr();
    if (!_connected) return LocaleKeys.communicationRinging.tr();
    return _elapsedLabel;
  }

  bool get _hasImage => (widget.contactImage ?? '').trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video (Full Screen)
          if (widget.isVideo)
            Positioned.fill(
              child: RTCVideoView(
                _remoteRenderer,
                objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              ),
            ),

          // Local Video (Small Overlay)
          if (widget.isVideo)
            Positioned(
              right: 20,
              top: 50,
              width: 100,
              height: 150,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: RTCVideoView(
                  _localRenderer,
                  mirror: true,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              ),
            ),

          // Name + status overlay (top, always shown)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: widget.isVideo
                    ? BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.transparent,
                          ],
                        ),
                      )
                    : null,
                child: Column(
                  children: [
                    Text(
                      widget.contactName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _statusLabel,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Call Controls (Bottom)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCallButton(
                  icon: _micEnabled ? Icons.mic : Icons.mic_off,
                  backgroundColor: _micEnabled
                      ? Colors.grey[800]!
                      : Colors.white,
                  iconColor: _micEnabled ? Colors.white : Colors.black,
                  onTap: _toggleMic,
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                  onTap: _endCall,
                  size: 72,
                ),
                if (widget.isVideo)
                  _buildCallButton(
                    icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    backgroundColor: _cameraEnabled
                        ? Colors.grey[800]!
                        : Colors.white,
                    iconColor: _cameraEnabled ? Colors.white : Colors.black,
                    onTap: _toggleCamera,
                  ),
              ],
            ),
          ),

          if (!widget.isVideo)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25), width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 64,
                      backgroundColor: AppColors.primary,
                      backgroundImage:
                          _hasImage ? NetworkImage(widget.contactImage!.trim()) : null,
                      child: !_hasImage
                          ? Text(
                              widget.contactName.isNotEmpty
                                  ? widget.contactName.substring(0, 1).toUpperCase()
                                  : '?',
                              style:
                                  const TextStyle(fontSize: 48, color: Colors.white),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),

          if (_starting)
            const Positioned.fill(
              child: ColoredBox(
                color: Colors.black45,
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}
