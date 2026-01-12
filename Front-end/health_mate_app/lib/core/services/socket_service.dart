import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Socket Service
/// Handles real-time signaling for WebRTC

class SocketService {
  io.Socket? _socket;
  final String _baseUrl;

  SocketService(this._baseUrl);

  // Initialize connection
  void init(String token) {
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket Connected');
    });

    _socket!.onConnectError((data) => debugPrint('Socket Error: $data'));
    _socket!.onDisconnect((_) => debugPrint('Socket Disconnected'));
  }

  // Listen for call events
  void onCallOffer(Function(dynamic data) callback) {
    _socket?.on('call_offer', callback);
  }

  void onCallAnswer(Function(dynamic data) callback) {
    _socket?.on('call_answer', callback);
  }

  void onIceCandidate(Function(dynamic data) callback) {
    _socket?.on('ice_candidate', callback);
  }

  // Emit call events
  void sendOffer(dynamic data) {
    _socket?.emit('make_offer', data);
  }

  void sendAnswer(dynamic data) {
    _socket?.emit('make_answer', data);
  }

  void sendIceCandidate(dynamic data) {
    _socket?.emit('send_ice_candidate', data);
  }

  void dispose() {
    _socket?.dispose();
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  // Use base URL without /api/v1 for socket
  // Adjust if your socket server is on a different port/path
  final url = ApiConstants.baseUrl.replaceAll('/api/v1', '');
  return SocketService(url);
});
