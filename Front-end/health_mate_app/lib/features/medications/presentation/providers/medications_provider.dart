import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/medication.dart';
import '../../data/medications_repository.dart';

/// Medications State Management

class MedicationsState {
  final List<Medication> medications;
  final bool isLoading;
  final String? errorMessage;

  MedicationsState({
    this.medications = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MedicationsState copyWith({
    List<Medication>? medications,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MedicationsState(
      medications: medications ?? this.medications,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<Medication> get activeMedications =>
      medications.where((m) => m.isActive).toList();

  List<Medication> get inactiveMedications =>
      medications.where((m) => !m.isActive).toList();
}

// Medications Notifier
class MedicationsNotifier extends StateNotifier<MedicationsState> {
  final MedicationsRepository _repository;
  final String? patientId;

  MedicationsNotifier(this._repository, {this.patientId})
      : super(MedicationsState()) {
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
    required String frequency,
    required List<String> timeSlots,
    String? instructions,
    int? drawerNumber,
    bool enableLed = true,
    bool enableBuzzer = true,
    bool enableNotification = true,
    String? imageUrl,
  }) async {
    state = state.copyWith(isLoading: true);

    try {
      await _repository.createMedication(
        name: name,
        dosage: dosage,
        frequency: frequency,
        timeSlots: timeSlots,
        instructions: instructions,
        drawerNumber: drawerNumber,
        enableLed: enableLed,
        enableBuzzer: enableBuzzer,
        enableNotification: enableNotification,
        imageUrl: imageUrl,
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

      // Remove from state
      state = state.copyWith(
        medications: state.medications.where((m) => m.id != id).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
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
  return MedicationsNotifier(repository);
});

// Family provider for patients (for caregivers)
final patientMedicationsNotifierProvider =
    StateNotifierProvider.family<MedicationsNotifier, MedicationsState, String>(
  (ref, patientId) {
    final repository = ref.watch(medicationsRepositoryProvider);
    return MedicationsNotifier(repository, patientId: patientId);
  },
);
