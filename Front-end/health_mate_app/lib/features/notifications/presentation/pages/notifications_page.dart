import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../communication/presentation/pages/call_page.dart';
import '../providers/notifications_provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
                  if (notification.isEmergency)
                    _buildEmergencyActions(context, notification),
                ],
              ),
              onTap: () {
                if (!notification.isRead) {
                  ref.read(notificationsNotifierProvider.notifier).markAsRead([
                    notification.id,
                  ]);
                }
              },
              // Explicit delete button -- the swipe-to-dismiss gesture above
              // isn't discoverable on its own.
              trailing: IconButton(
                icon: Icon(Icons.delete_outline_rounded,
                    color: AppColors.textSecondary, size: context.sp(22)),
                tooltip: LocaleKeys.delete.tr(),
                onPressed: () {
                  ref
                      .read(notificationsNotifierProvider.notifier)
                      .deleteNotification(notification.id);
                },
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getNotificationIcon(String type) {
    switch (type) {
      case 'emergency_alert':
      case 'emergency_bp_alert':
      case 'EMERGENCY_BP_ALERT':
      case 'symptom_assessment_alert':
      case 'SYMPTOM_ASSESSMENT_ALERT':
        return Icons.warning;
      case 'medication_reminder':
        return Icons.medication;
      case 'call_incoming':
        return Icons.call;
      default:
        return Icons.notifications;
    }
  }

  Widget _buildEmergencyActions(BuildContext context, notification) {
    final patientId = notification.data['patient_id']?.toString() ?? '';
    final patientName =
        notification.data['patient_name']?.toString() ?? notification.title;
    final phone = notification.data['phone']?.toString().trim() ?? '';
    if (patientId.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: context.h(1)),
      child: Wrap(
        spacing: context.w(2),
        runSpacing: context.h(0.8),
        children: [
          _buildNotificationActionChip(
            context,
            icon: Icons.call_rounded,
            label: LocaleKeys.communicationAudioCall.tr(),
            color: AppColors.success,
            onTap: () => _openCall(context, patientId, patientName, false),
          ),
          _buildNotificationActionChip(
            context,
            icon: Icons.videocam_rounded,
            label: LocaleKeys.communicationVideoCall.tr(),
            color: AppColors.primary,
            onTap: () => _openCall(context, patientId, patientName, true),
          ),
          if (phone.isNotEmpty)
            _buildNotificationActionChip(
              context,
              icon: Icons.phone_android_rounded,
              label: LocaleKeys.communicationPhoneCall.tr(),
              color: AppColors.info,
              onTap: () => _makePhoneCall(phone),
            ),
        ],
      ),
    );
  }

  Widget _buildNotificationActionChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.w(2.5),
          vertical: context.h(0.7),
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: context.sp(15), color: color),
            SizedBox(width: context.w(1)),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: context.sp(12),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openCall(
    BuildContext context,
    String patientId,
    String patientName,
    bool isVideo,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: isVideo,
          contactName: patientName,
          contactId: patientId,
          isCaller: true,
        ),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final launchUri = Uri(scheme: 'tel', path: phoneNumber);
    final launched = await launchUrl(
      launchUri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('No dialer app can handle $launchUri');
    }
  }

  Color _getNotificationColor(String type) {
    switch (type) {
      case 'emergency_alert':
      case 'emergency_bp_alert':
      case 'EMERGENCY_BP_ALERT':
      case 'symptom_assessment_alert':
      case 'SYMPTOM_ASSESSMENT_ALERT':
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
