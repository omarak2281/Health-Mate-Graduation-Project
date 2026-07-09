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
    bool clearCurrentBP = false,
  }) {
    return VitalsState(
      currentBP: clearCurrentBP ? null : currentBP ?? this.currentBP,
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
        clearCurrentBP: bp == null,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      if (patientId != null) {
        state = state.copyWith(
          clearCurrentBP: true,
          isLoading: false,
          errorMessage: e.toString(),
        );
        return;
      }

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
  Future<VitalSign?> createBPReading({
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
      return newBP;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return null;
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

/// State for the 8-hour BP reminder settings section.
class BPReminderState {
  final List<String> scheduledTimes; // "HH:MM", ordered
  final bool isLoading;
  final String? errorMessage;

  BPReminderState({
    this.scheduledTimes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  BPReminderState copyWith({
    List<String>? scheduledTimes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return BPReminderState(
      scheduledTimes: scheduledTimes ?? this.scheduledTimes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class BPReminderNotifier extends StateNotifier<BPReminderState> {
  final VitalsRepository _repository;

  BPReminderNotifier(this._repository) : super(BPReminderState()) {
    loadReminders();
  }

  Future<void> loadReminders() async {
    state = state.copyWith(isLoading: true);
    try {
      final reminders = await _repository.getBPReminders();
      final times = reminders.map((r) => r['scheduled_time'] as String).toList()
        ..sort();
      state = state.copyWith(
          scheduledTimes: times, isLoading: false, errorMessage: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<bool> scheduleDaily(String startTime) async {
    state = state.copyWith(isLoading: true);
    try {
      final reminders = await _repository.scheduleDailyBPReminders(startTime);
      final times = reminders.map((r) => r['scheduled_time'] as String).toList()
        ..sort();
      state = state.copyWith(
          scheduledTimes: times, isLoading: false, errorMessage: null);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
      return false;
    }
  }
}

final bpReminderNotifierProvider =
    StateNotifierProvider<BPReminderNotifier, BPReminderState>((ref) {
  final repository = ref.watch(vitalsRepositoryProvider);
  return BPReminderNotifier(repository);
});
