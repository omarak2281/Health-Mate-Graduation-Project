import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/medication.dart';
import '../../data/medications_repository.dart';
import '../../../../core/services/alarm_scheduler_service.dart';

/// Medications State Management

class MedicationsState {
  final List<Medication> medications;
  final List<Medication> activeMedications;
  final List<Medication> inactiveMedications;
  final Set<int> assignedDrawerNumbers;
  final bool isLoading;
  final String? errorMessage;

  MedicationsState({
    this.medications = const [],
    this.activeMedications = const [],
    this.inactiveMedications = const [],
    this.assignedDrawerNumbers = const {},
    this.isLoading = false,
    this.errorMessage,
  });

  MedicationsState copyWith({
    List<Medication>? medications,
    bool? isLoading,
    String? errorMessage,
  }) {
    final newMedications = medications ?? this.medications;
    return MedicationsState(
      medications: newMedications,
      activeMedications: newMedications.where((m) => m.isActive).toList(),
      inactiveMedications: newMedications.where((m) => !m.isActive).toList(),
      assignedDrawerNumbers:
          newMedications.map((m) => m.drawerNumber).whereType<int>().toSet(),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MedicationsNotifier extends StateNotifier<MedicationsState> {
  final MedicationsRepository _repository;
  final AlarmSchedulerService? _scheduler;
  final String? patientId;

  MedicationsNotifier(this._repository,
      {AlarmSchedulerService? scheduler, this.patientId})
      : _scheduler = scheduler,
        super(MedicationsState()) {
    loadMedications();
  }

  // Load medications
  Future<void> loadMedications() async {
    state = state.copyWith(isLoading: true);
    try {
      final medications = await _repository.getMedications(
        patientId: patientId,
      );
      state = state.copyWith(
        medications: medications,
        isLoading: false,
        errorMessage: null,
      );

      // Successfully loaded medications from server/cache -> refresh local alarms
      if (patientId == null && _scheduler != null) {
        _scheduler.scheduleAll(medications);
      }
    } catch (e) {
      // Try cache
      final cachedMeds = _repository.getCachedMedications();
      state = state.copyWith(
        medications: cachedMeds ?? [],
        isLoading: false,
        errorMessage: cachedMeds == null ? e.toString() : null,
      );
    }
  }

  // Add medication
  Future<void> addMedication({
    required String name,
    required String dosage,
    required int timesPerDay,
    required List<String> scheduledTimes,
    String? instructions,
    bool useSmartBox = false,
    int? drawerNumber,
    String? imageUrl,
    String? patientId,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.createMedication(
        name: name,
        dosage: dosage,
        timesPerDay: timesPerDay,
        scheduledTimes: scheduledTimes,
        instructions: instructions,
        useSmartBox: useSmartBox,
        drawerNumber: drawerNumber,
        imageUrl: imageUrl,
        patientId: patientId ?? this.patientId,
      );

      // Reload medications
      await loadMedications();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Update medication
  Future<void> updateMedication(String id, Map<String, dynamic> updates) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.updateMedication(id, updates);
      await loadMedications();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Delete medication
  Future<void> deleteMedication(String id) async {
    try {
      await _repository.deleteMedication(id);

      // 1. Optimistically remove from state for instant UI feedback
      state = state.copyWith(
        medications: state.medications.where((m) => m.id != id).toList(),
      );

      // 2. Reload from server to ensure state is fully in sync with DB
      await loadMedications();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
      // Re-throw so the UI SnackBar can show the correct error message
      rethrow;
    }
  }

  // Confirm medication taken
  Future<void> confirmMedicationTaken(String id) async {
    try {
      await _repository.confirmMedication(id);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // Confirm multiple medications taken
  Future<void> confirmMultipleMedicationsTaken(List<String> ids) async {
    try {
      await _repository.confirmMultipleMedications(ids);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // Upload Image
  Future<String?> uploadMedicationImage(dynamic file) async {
    try {
      return await _repository.uploadMedicationImage(file);
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
      return null;
    }
  }
}

// Provider for current user
final medicationsNotifierProvider =
    StateNotifierProvider<MedicationsNotifier, MedicationsState>((ref) {
  final repository = ref.watch(medicationsRepositoryProvider);
  final scheduler = ref.watch(alarmSchedulerServiceProvider);
  return MedicationsNotifier(repository, scheduler: scheduler);
});

// Family provider for patients (for caregivers)
final patientMedicationsNotifierProvider =
    StateNotifierProvider.family<MedicationsNotifier, MedicationsState, String>(
  (ref, patientId) {
    final repository = ref.watch(medicationsRepositoryProvider);
    // Don't inject scheduler for patient views (caregiver app shouldn't schedule local alarms for patients)
    return MedicationsNotifier(repository, patientId: patientId);
  },
);
