import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/models/notification.dart';
import '../../../core/constants/api_constants.dart';

/// Notifications Repository
/// Clean Architecture - Data Layer

class NotificationsRepository {
  final DioClient _dioClient;

  NotificationsRepository(this._dioClient);

  // Get notifications
  Future<List<NotificationModel>> getNotifications({
    int skip = 0,
    int limit = 20,
  }) async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.notifications,
        queryParameters: {'skip': skip, 'limit': limit},
      );

      return (response.data as List)
          .map((json) => NotificationModel.fromJson(json))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // Get unread count
  Future<int> getUnreadCount() async {
    try {
      final response = await _dioClient.dio.get(
        ApiConstants.notificationUnreadCount,
      );
      return response.data['unread_count'];
    } catch (e) {
      return 0;
    }
  }

  // Mark as read
  Future<void> markAsRead(List<String> ids) async {
    try {
      await _dioClient.dio.put(
        ApiConstants.notificationMarkRead,
        data: {'notification_ids': ids},
      );
    } catch (e) {
      rethrow;
    }
  }

  // Delete notification
  Future<void> deleteNotification(String id) async {
    try {
      await _dioClient.dio.delete('${ApiConstants.notifications}/$id');
    } catch (e) {
      rethrow;
    }
  }
}

// Provider
final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final dioClient = ref.watch(dioClientProvider);
  return NotificationsRepository(dioClient);
});
