import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';
import '../network/dio_client.dart';

/// Connectivity Service for monitoring ESP32 Hardware status.
class ConnectivityService extends ChangeNotifier with WidgetsBindingObserver {
  final Dio _dio;

  Timer? _timer;
  bool _isHardwareConnected = false;

  bool get isHardwareConnected => _isHardwareConnected;

  ConnectivityService(this._dio) {
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _checkStatus();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    try {
      final response = await _dio.get(ApiConstants.hardwareStatus);
      if (response.statusCode == 200) {
        final data = response.data['data'];
        final connected = data['connected'] as bool;
        if (_isHardwareConnected != connected) {
          _isHardwareConnected = connected;
          notifyListeners();
          debugPrint('Hardware Connectivity changed: $connected');
        }
      }
    } catch (e) {
      if (_isHardwareConnected != false) {
        _isHardwareConnected = false;
        notifyListeners();
        debugPrint('Hardware Status Check failed: $e');
      }
    }
  }

  /// Manually trigger an immediate connectivity check outside of the timer.
  Future<void> checkNow() => _checkStatus();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}

final connectivityServiceProvider =
    ChangeNotifierProvider<ConnectivityService>((ref) {
  final dio = ref.watch(dioProvider);
  return ConnectivityService(dio);
});

// A wrapper provider that just returns the bool value directly for easier watching
final hardwareStatusProvider = Provider<bool>((ref) {
  return ref.watch(connectivityServiceProvider).isHardwareConnected;
});
