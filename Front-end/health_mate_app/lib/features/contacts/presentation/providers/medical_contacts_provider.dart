import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/medical_contact.dart';
import '../../data/medical_contacts_repository.dart';

class MedicalContactsState {
  final List<MedicalContact> contacts;
  final bool isLoading;
  final String? errorMessage;

  MedicalContactsState({
    this.contacts = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  MedicalContactsState copyWith({
    List<MedicalContact>? contacts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MedicalContactsState(
      contacts: contacts ?? this.contacts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class MedicalContactsNotifier extends StateNotifier<MedicalContactsState> {
  final MedicalContactsRepository _repository;

  MedicalContactsNotifier(this._repository) : super(MedicalContactsState()) {
    loadContacts();
  }

  Future<void> loadContacts() async {
    state = state.copyWith(isLoading: true);
    try {
      final contacts = await _repository.getContacts();
      state = state.copyWith(
        isLoading: false,
        contacts: contacts,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addContact(String name, String phone, String type) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.createContact(name: name, phone: phone, type: type);
      await loadContacts(); // Reload
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> deleteContact(String id) async {
    try {
      await _repository.deleteContact(id);
      await loadContacts();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final medicalContactsNotifierProvider =
    StateNotifierProvider<MedicalContactsNotifier, MedicalContactsState>((ref) {
      final repo = ref.watch(medicalContactsRepositoryProvider);
      return MedicalContactsNotifier(repo);
    });
