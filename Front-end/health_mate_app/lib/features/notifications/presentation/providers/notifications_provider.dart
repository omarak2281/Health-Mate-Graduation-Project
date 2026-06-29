import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/notification.dart';
import '../../data/notifications_repository.dart';

/// Notifications State Management

class NotificationsState {
  final List<NotificationModel> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? errorMessage;

  NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.errorMessage,
  });

  NotificationsState copyWith({
    List<NotificationModel>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? errorMessage,
  }) {
    return NotificationsState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  List<NotificationModel> get unreadNotifications =>
      notifications.where((n) => !n.isRead).toList();
}

// Notifications Notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;

  NotificationsNotifier(this._repository) : super(NotificationsState()) {
    loadNotifications();
    loadUnreadCount();
  }

  // Load notifications
  Future<void> loadNotifications() async {
    state = state.copyWith(isLoading: true);

    try {
      final notifications = await _repository.getNotifications();
      state = state.copyWith(
        notifications: notifications,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  // Load unread count
  Future<void> loadUnreadCount() async {
    try {
      final count = await _repository.getUnreadCount();
      state = state.copyWith(unreadCount: count);
    } catch (e) {
      // Ignore error
    }
  }

  // Mark as read
  Future<void> markAsRead(List<String> ids) async {
    try {
      await _repository.markAsRead(ids);

      // Update local state
      final updatedNotifications = state.notifications.map((n) {
        if (ids.contains(n.id)) {
          return NotificationModel(
            id: n.id,
            userId: n.userId,
            title: n.title,
            message: n.message,
            type: n.type,
            isRead: true,
            createdAt: n.createdAt,
          );
        }
        return n;
      }).toList();

      state = state.copyWith(notifications: updatedNotifications);
      await loadUnreadCount();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // Delete notification
  Future<void> deleteNotification(String id) async {
    try {
      await _repository.deleteNotification(id);

      state = state.copyWith(
        notifications: state.notifications.where((n) => n.id != id).toList(),
      );
      await loadUnreadCount();
    } catch (e) {
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    final unreadIds = state.unreadNotifications.map((n) => n.id).toList();
    if (unreadIds.isNotEmpty) {
      await markAsRead(unreadIds);
    }
  }
}

// Provider
final notificationsNotifierProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
      final repository = ref.watch(notificationsRepositoryProvider);
      return NotificationsNotifier(repository);
    });
