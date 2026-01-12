import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/notifications_provider.dart';

/// Notifications Page
/// Shows all notifications with mark as read functionality

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.notificationsTitle.tr()),
        actions: [
          if (notificationsState.unreadCount > 0)
            TextButton(
              onPressed: () {
                ref
                    .read(notificationsNotifierProvider.notifier)
                    .markAllAsRead();
              },
              child: Text(
                LocaleKeys.notificationsMarkAllRead.tr(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref
              .read(notificationsNotifierProvider.notifier)
              .loadNotifications();
        },
        child: _buildBody(context, ref, notificationsState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    NotificationsState state,
  ) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.notifications_none,
              size: 80,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              LocaleKeys.notificationsNoNotifications.tr(),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: state.notifications.length,
      itemBuilder: (context, index) {
        final notification = state.notifications[index];

        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: AppColors.error,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            ref
                .read(notificationsNotifierProvider.notifier)
                .deleteNotification(notification.id);
          },
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: notification.isRead
                ? null
                : AppColors.primary.withValues(alpha: 0.05),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getNotificationColor(
                  notification.type,
                ).withValues(alpha: 0.1),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                ),
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontWeight: notification.isRead
                      ? FontWeight.normal
                      : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  Text(notification.message),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.yMMMd().add_jm().format(notification.createdAt),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              onTap: () {
                if (!notification.isRead) {
                  ref.read(notificationsNotifierProvider.notifier).markAsRead([
                    notification.id,
                  ]);
                }
              },
            ),
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'emergency_alert':
        return Icons.warning;
      case 'medication_reminder':
        return Icons.medication;
      case 'call_incoming':
        return Icons.call;
      default:
        return Icons.notifications;
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'emergency_alert':
        return AppColors.error;
      case 'medication_reminder':
        return AppColors.primary;
      case 'call_incoming':
        return AppColors.success;
      default:
        return AppColors.info;
    }
  }
}
