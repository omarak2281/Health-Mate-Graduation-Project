import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/linking_repository.dart';
import '../../../../core/models/user.dart';

/// Linking State Management

class LinkingState {
  final List<User> linkedUsers;
  final bool isLoading;
  final String? errorMessage;

  LinkingState({
    this.linkedUsers = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  LinkingState copyWith({
    List<User>? linkedUsers,
    bool? isLoading,
    String? errorMessage,
  }) {
    return LinkingState(
      linkedUsers: linkedUsers ?? this.linkedUsers,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

class LinkingNotifier extends StateNotifier<LinkingState> {
  final LinkingRepository _repository;

  LinkingNotifier(this._repository) : super(LinkingState()) {
    getLinkedUsers();
  }

  Future<void> getLinkedUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final usersJson = await _repository.getLinkedUsers();
      final users = usersJson.map((json) => User.fromJson(json)).toList();
      state = state.copyWith(
        linkedUsers: users,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> linkPatient(String patientId) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repository.linkPatient(patientId: patientId);
      await getLinkedUsers();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> unlinkUser(String userId) async {
    try {
      await _repository.unlinkUser(userId);
      state = state.copyWith(
        linkedUsers: state.linkedUsers.where((u) => u.id != userId).toList(),
      );
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }
}

final linkingNotifierProvider =
    StateNotifierProvider<LinkingNotifier, LinkingState>((ref) {
      final repository = ref.watch(linkingRepositoryProvider);
      return LinkingNotifier(repository);
    });
