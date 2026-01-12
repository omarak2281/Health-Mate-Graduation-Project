import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/iot_repository.dart';

class IoTState {
  final List<dynamic> sensors;
  final List<dynamic> drawers;
  final bool isLoading;
  final String? error;

  IoTState({
    this.sensors = const [],
    this.drawers = const [],
    this.isLoading = false,
    this.error,
  });

  IoTState copyWith({
    List<dynamic>? sensors,
    List<dynamic>? drawers,
    bool? isLoading,
    String? error,
  }) {
    return IoTState(
      sensors: sensors ?? this.sensors,
      drawers: drawers ?? this.drawers,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class IoTNotifier extends StateNotifier<IoTState> {
  final IoTRepository _repository;

  IoTNotifier(this._repository) : super(IoTState()) {
    loadStatus();
  }

  Future<void> loadStatus() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final sensors = await _repository.getSensorsStatus();
      final drawers = await _repository.getDrawers();
      state = state.copyWith(
        sensors: sensors,
        drawers: drawers,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> testDrawer(int drawerNumber) async {
    try {
      await _repository.activateDrawer(drawerNumber);
      // Wait for a bit and deactivate
      await Future.delayed(const Duration(seconds: 3));
      await _repository.deactivateDrawer(drawerNumber);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final iotNotifierProvider = StateNotifierProvider<IoTNotifier, IoTState>((ref) {
  final repository = ref.watch(iotRepositoryProvider);
  return IoTNotifier(repository);
});
