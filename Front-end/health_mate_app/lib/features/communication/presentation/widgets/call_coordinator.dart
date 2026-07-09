import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/socket_service.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class CallCoordinator extends ConsumerStatefulWidget {
  final Widget child;

  const CallCoordinator({super.key, required this.child});

  @override
  ConsumerState<CallCoordinator> createState() => _CallCoordinatorState();
}

class _CallCoordinatorState extends ConsumerState<CallCoordinator> {
  String? _activeIncomingSessionId;
  String? _boundUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocketListeners());
  }

  @override
  void didUpdateWidget(covariant CallCoordinator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindSocketListeners();
  }

  void _bindSocketListeners() {
    final auth = ref.read(authNotifierProvider);
    if (auth.status != AuthStatus.authenticated) return;
    if (_boundUserId == auth.user?.id) return;
    _boundUserId = auth.user?.id;

    ref.read(socketServiceProvider).onCallOffer((data) {
      final sessionId = data['sessionId']?.toString() ?? data['callId']?.toString();
      if (sessionId != null && _activeIncomingSessionId == sessionId) return;
      _activeIncomingSessionId = sessionId;

      PushNotificationService.instance.showIncomingCallAlert({
        'notification_type': 'incoming_call',
        'caller_name': data['callerName']?.toString() ?? '',
        'caller_id': data['callerId']?.toString() ?? '',
        'caller_avatar': data['callerImage']?.toString() ?? '',
        'call_type': (data['isVideo'] == true ||
                data['callType']?.toString() == 'video')
            ? 'video'
            : 'audio',
        'session_id': sessionId ?? '',
      }).whenComplete(() => _activeIncomingSessionId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    if (auth.status == AuthStatus.authenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _bindSocketListeners());
    } else {
      _boundUserId = null;
    }
    return widget.child;
  }
}
