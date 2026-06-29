import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/notifications_provider.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsState = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.notificationsTitle.tr(),
            style: TextStyle(
                fontSize: context.sp(20), fontWeight: FontWeight.bold)),
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
                style: TextStyle(color: Colors.white, fontSize: context.sp(14)),
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
              size: context.sp(80),
              color: AppColors.textSecondary,
            ),
            SizedBox(height: context.h(2)),
            Text(
              LocaleKeys.notificationsNoNotifications.tr(),
              style: TextStyle(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: context.h(1)),
      itemCount: state.notifications.length,
      itemBuilder: (context, index) {
        final notification = state.notifications[index];

        return Dismissible(
          key: Key(notification.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: EdgeInsets.only(right: context.w(5)),
            color: AppColors.error,
            child:
                Icon(Icons.delete, color: Colors.white, size: context.sp(24)),
          ),
          onDismissed: (direction) {
            ref
                .read(notificationsNotifierProvider.notifier)
                .deleteNotification(notification.id);
          },
          child: Card(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: EdgeInsets.symmetric(
                horizontal: context.w(3), vertical: context.h(0.6)),
            color: notification.isRead
                ? null
                : AppColors.primary.withValues(alpha: 0.05),
            child: ListTile(
              leading: CircleAvatar(
                radius: context.sp(22),
                backgroundColor: _getNotificationColor(
                  notification.type,
                ).withValues(alpha: 0.1),
                child: Icon(
                  _getNotificationIcon(notification.type),
                  color: _getNotificationColor(notification.type),
                  size: context.sp(20),
                ),
              ),
              title: Text(
                notification.title,
                style: TextStyle(
                  fontSize: context.sp(16),
                  fontWeight:
                      notification.isRead ? FontWeight.normal : FontWeight.bold,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: context.h(0.5)),
                  Text(notification.message,
                      style: TextStyle(fontSize: context.sp(14))),
                  SizedBox(height: context.h(0.5)),
                  Text(
                    DateFormat.yMMMd().add_jm().format(notification.createdAt),
                    style: TextStyle(
                        fontSize: context.sp(12),
                        color: AppColors.textSecondary),
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
