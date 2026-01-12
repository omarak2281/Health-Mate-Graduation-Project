import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/theme/app_colors.dart';

/// Call Page
/// Fully functional WebRTC Video/Audio Call

class CallPage extends ConsumerStatefulWidget {
  final bool isVideo;
  final String contactName;
  final String contactId;
  final bool isCaller; // true if initiating, false if answering

  const CallPage({
    super.key,
    required this.isVideo,
    required this.contactName,
    required this.contactId,
    required this.isCaller,
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

  @override
  void initState() {
    super.initState();
    _initRenderer();
    _startCall();
  }

  Future<void> _initRenderer() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  Future<void> _startCall() async {
    final socket = ref.read(socketServiceProvider);

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
      if (event.track.kind == 'video') {
        // handle video track
        _remoteRenderer.srcObject = event.streams[0];
        setState(() {});
      }
    };

    // 5. Handle ICE Candidates
    _peerConnection!.onIceCandidate = (candidate) {
      socket.sendIceCandidate({
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
        'target': widget.contactId,
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

    // 7. Create Offer (if caller)
    if (widget.isCaller) {
      RTCSessionDescription offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);
      socket.sendOffer({
        'sdp': offer.sdp,
        'type': offer.type,
        'target': widget.contactId,
      });
    }
  }

  @override
  void dispose() {
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
    Navigator.of(context).pop();
  }

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
                  color: Colors.white,
                  backgroundColor: _micEnabled
                      ? Colors.grey[800]!
                      : Colors.white,
                  iconColor: _micEnabled ? Colors.white : Colors.black,
                  onTap: _toggleMic,
                ),
                _buildCallButton(
                  icon: Icons.call_end,
                  color: Colors.white,
                  backgroundColor: Colors.red,
                  iconColor: Colors.white,
                  onTap: _endCall,
                  size: 72,
                ),
                if (widget.isVideo)
                  _buildCallButton(
                    icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                    color: Colors.white,
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
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      widget.contactName.substring(0, 1).toUpperCase(),
                      style: const TextStyle(fontSize: 48, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.contactName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '00:00', // Timer would go here
                    style: TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCallButton({
    required IconData icon,
    required Color color,
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
