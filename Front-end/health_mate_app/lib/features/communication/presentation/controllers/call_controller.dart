import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/call_service.dart';

class CallControllerState {
  final bool isLoading;
  final String? errorMessage;
  final CallSession? session;

  const CallControllerState({
    this.isLoading = false,
    this.errorMessage,
    this.session,
  });

  CallControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    CallSession? session,
  }) {
    return CallControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      session: session ?? this.session,
    );
  }
}

class CallController extends StateNotifier<CallControllerState> {
  final CallService _service;

  CallController(this._service) : super(const CallControllerState());

  Future<CallSession?> startCall({
    required String calleeId,
    required bool isVideo,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final session = await _service.startCall(calleeId: calleeId, isVideo: isVideo);
      state = state.copyWith(isLoading: false, session: session);
      return session;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
    }
  }

  Future<CallSession?> acceptCall(String callId) async {
    try {
      final session = await _service.acceptCall(callId);
      state = state.copyWith(session: session);
      return session;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<CallSession?> getCall(String callId) async {
    try {
      final session = await _service.getCall(callId);
      state = state.copyWith(session: session);
      return session;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<CallSession?> sendOffer({
    required String callId,
    required String sdp,
    String type = 'offer',
  }) async {
    try {
      final session = await _service.sendOffer(
        callId: callId,
        sdp: sdp,
        type: type,
      );
      state = state.copyWith(session: session);
      return session;
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }

  Future<void> rejectCall(String callId) async {
    try {
      final session = await _service.rejectCall(callId);
      state = state.copyWith(session: session);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> endCall(String callId) async {
    try {
      await _service.endCall(callId);
    } catch (_) {}
  }
}

final callControllerProvider =
    StateNotifierProvider<CallController, CallControllerState>((ref) {
  return CallController(ref.watch(callServiceProvider));
});
