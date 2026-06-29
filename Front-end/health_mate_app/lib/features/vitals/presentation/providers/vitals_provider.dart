import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/vital_sign.dart';
import '../../data/vitals_repository.dart';

/// Vitals State Management
/// Clean Architecture - Presentation Layer

class VitalsState {
  final VitalSign? currentBP;
  final List<VitalSign> history;
  final Map<String, dynamic>? stats;
  final bool isLoading;
  final String? errorMessage;

  VitalsState({
    this.currentBP,
    this.history = const [],
    this.stats,
    this.isLoading = false,
    this.errorMessage,
  });

  VitalsState copyWith({
    VitalSign? currentBP,
    List<VitalSign>? history,
    Map<String, dynamic>? stats,
    bool? isLoading,
    String? errorMessage,
  }) {
    return VitalsState(
      currentBP: currentBP ?? this.currentBP,
      history: history ?? this.history,
      stats: stats ?? this.stats,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

// Vitals Notifier
class VitalsNotifier extends StateNotifier<VitalsState> {
  final VitalsRepository _repository;
  final String? patientId;

  VitalsNotifier(this._repository, {this.patientId}) : super(VitalsState()) {
    loadCurrentBP();
  }

  // Load current BP
  Future<void> loadCurrentBP() async {
    state = state.copyWith(isLoading: true);

    try {
      final bp = await _repository.getCurrentBP(patientId: patientId);
      state = state.copyWith(
        currentBP: bp,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      // Try cache
      final cachedBP = _repository.getCachedLatestBP();
      state = state.copyWith(
        currentBP: cachedBP,
        isLoading: false,
        errorMessage: cachedBP == null ? e.toString() : null,
      );
    }
  }

  // Create BP reading
  Future<void> createBPReading({
    required int systolic,
    required int diastolic,
    int? heartRate,
    String source = 'manual',
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      final newBP = await _repository.createBPReading(
        systolic: systolic,
        diastolic: diastolic,
        heartRate: heartRate,
        source: source,
      );

      state = state.copyWith(
        currentBP: newBP,
        isLoading: false,
        errorMessage: null,
      );

      // Reload history
      await loadHistory();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Load history
  Future<void> loadHistory() async {
    try {
      final history = await _repository.getBPHistory(patientId: patientId);
      state = state.copyWith(history: history);
    } catch (e) {
      // Keep existing history from cache
    }
  }

  // Load statistics
  Future<void> loadStats() async {
    try {
      final stats = await _repository
          .getBPStats(); // Stats maybe not needed for caregiver yet but kept generic
      state = state.copyWith(stats: stats);
    } catch (e) {
      // Ignore stats errors
    }
  }
}

// Provider for current user
final vitalsNotifierProvider =
    StateNotifierProvider<VitalsNotifier, VitalsState>((ref) {
      final repository = ref.watch(vitalsRepositoryProvider);
      return VitalsNotifier(repository);
    });

// Family provider for patients (for caregivers)
final patientVitalsNotifierProvider =
    StateNotifierProvider.family<VitalsNotifier, VitalsState, String>((
      ref,
      patientId,
    ) {
      final repository = ref.watch(vitalsRepositoryProvider);
      return VitalsNotifier(repository, patientId: patientId);
    });
