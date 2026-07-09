import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Socket Service
/// Handles real-time signaling for WebRTC

class SocketService {
  io.Socket? _socket;
  final String _baseUrl;
  String? _currentToken;
  Function(dynamic data)? _onCallOffer;
  Function(dynamic data)? _onCallAnswer;
  Function(dynamic data)? _onIceCandidate;
  Function(dynamic data)? _onCallDeclined;
  Function(dynamic data)? _onCallEnded;

  SocketService(this._baseUrl);

  // Initialize connection
  void init(String token) {
    if (_socket?.connected == true && _currentToken == token) {
      _attachCallListeners();
      return;
    }
    _currentToken = token;
    _socket?.dispose();
    _socket = io.io(
      _baseUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setExtraHeaders({'Authorization': 'Bearer $token'})
          .setAuth({'token': token})
          .enableAutoConnect()
          .build(),
    );

    _socket!.onConnect((_) {
      debugPrint('Socket Connected');
      _attachCallListeners();
    });

    _socket!.onConnectError((data) => debugPrint('Socket Error: $data'));
    _socket!.onDisconnect((_) => debugPrint('Socket Disconnected'));
    _attachCallListeners();
  }

  void _attachCallListeners() {
    final socket = _socket;
    if (socket == null) return;

    socket.off('call_offer');
    if (_onCallOffer != null) {
      socket.on('call_offer', _onCallOffer!);
    }

    socket.off('call_answer');
    if (_onCallAnswer != null) {
      socket.on('call_answer', _onCallAnswer!);
    }

    socket.off('ice_candidate');
    if (_onIceCandidate != null) {
      socket.on('ice_candidate', _onIceCandidate!);
    }

    socket.off('call_declined');
    if (_onCallDeclined != null) {
      socket.on('call_declined', _onCallDeclined!);
    }

    socket.off('call_ended');
    if (_onCallEnded != null) {
      socket.on('call_ended', _onCallEnded!);
    }
  }

  // Listen for call events
  void onCallOffer(Function(dynamic data) callback) {
    _onCallOffer = callback;
    _attachCallListeners();
  }

  void onCallAnswer(Function(dynamic data) callback) {
    _onCallAnswer = callback;
    _attachCallListeners();
  }

  void onIceCandidate(Function(dynamic data) callback) {
    _onIceCandidate = callback;
    _attachCallListeners();
  }

  void onCallDeclined(Function(dynamic data) callback) {
    _onCallDeclined = callback;
    _attachCallListeners();
  }

  void onCallEnded(Function(dynamic data) callback) {
    _onCallEnded = callback;
    _attachCallListeners();
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

  void sendCallDeclined(dynamic data) {
    _socket?.emit('call_declined', data);
  }

  void sendCallEnded(dynamic data) {
    _socket?.emit('call_ended', data);
  }

  void dispose() {
    _socket?.dispose();
    _socket = null;
    _currentToken = null;
    _onCallOffer = null;
    _onCallAnswer = null;
    _onIceCandidate = null;
    _onCallDeclined = null;
    _onCallEnded = null;
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  // Use base URL without /api/v1 for socket
  // Adjust if your socket server is on a different port/path
  final url = ApiConstants.baseUrl.replaceAll('/api/v1', '');
  return SocketService(url);
});
