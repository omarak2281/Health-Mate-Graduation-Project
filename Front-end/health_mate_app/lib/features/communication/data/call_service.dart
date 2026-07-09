import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';

class CallSession {
  final String id;
  final String callerId;
  final String calleeId;
  final String callType;
  final String status;
  final String? offerSdp;
  final String? answerSdp;

  CallSession({
    required this.id,
    required this.callerId,
    required this.calleeId,
    required this.callType,
    required this.status,
    this.offerSdp,
    this.answerSdp,
  });

  factory CallSession.fromJson(Map<String, dynamic> json) {
    return CallSession(
      id: json['id']?.toString() ?? '',
      callerId: json['caller_id']?.toString() ?? '',
      calleeId: json['callee_id']?.toString() ?? '',
      callType: json['call_type']?.toString() ?? 'audio',
      status: json['status']?.toString() ?? 'idle',
      offerSdp: json['offer_sdp']?.toString(),
      answerSdp: json['answer_sdp']?.toString(),
    );
  }
}

class CallService {
  final DioClient _dioClient;

  CallService(this._dioClient);

  Future<CallSession> startCall({
    required String calleeId,
    required bool isVideo,
  }) async {
    final response = await _dioClient.dio.post(
      ApiConstants.calls,
      data: {
        'callee_id': calleeId,
        'call_type': isVideo ? 'video' : 'audio',
      },
    );
    return CallSession.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<CallSession> getCall(String callId) async {
    final response = await _dioClient.dio.get(ApiConstants.call(callId));
    return CallSession.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<CallSession> sendOffer({
    required String callId,
    required String sdp,
    String type = 'offer',
  }) async {
    final response = await _dioClient.dio.post(
      ApiConstants.callOffer(callId),
      data: {
        'sdp': sdp,
        'type': type,
      },
    );
    return CallSession.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<CallSession> acceptCall(String callId) async {
    final response = await _dioClient.dio.post(ApiConstants.callAccept(callId));
    return CallSession.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<CallSession> rejectCall(String callId) async {
    final response = await _dioClient.dio.post(ApiConstants.callReject(callId));
    return CallSession.fromJson(Map<String, dynamic>.from(response.data));
  }

  Future<void> endCall(String callId) async {
    await _dioClient.dio.post(ApiConstants.callEnd(callId));
  }
}

final callServiceProvider = Provider<CallService>((ref) {
  return CallService(ref.watch(dioClientProvider));
});
