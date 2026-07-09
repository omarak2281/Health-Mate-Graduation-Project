import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/user.dart';
import '../../../../core/constants/constants.dart';
import '../../../communication/presentation/pages/call_page.dart';

/// Card used to display a linked caregiver/patient with quick call actions.
/// Shared between [MedicalContactsPage]'s pinned "linked" section and the
/// dedicated linked-caregivers/linked-patients list pages.
class LinkedUserCard extends StatelessWidget {
  final User user;

  const LinkedUserCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phone = user.phone?.trim() ?? '';
    final hasPhone = phone.isNotEmpty;

    return Container(
      margin: EdgeInsets.only(bottom: context.h(1.5)),
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: context.sp(24),
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage:
                user.profileImage != null ? NetworkImage(user.profileImage!) : null,
            child: user.profileImage == null
                ? Text(
                    user.fullName.isNotEmpty
                        ? user.fullName.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: context.sp(18),
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          SizedBox(width: context.w(3.5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStyles.cardTitleStyle.copyWith(
                    fontSize: context.sp(16),
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: context.h(0.4)),
                Row(
                  children: [
                    Icon(
                      hasPhone ? Icons.phone_rounded : Icons.phone_disabled_rounded,
                      size: context.sp(14),
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    SizedBox(width: context.w(1.2)),
                    Expanded(
                      child: Text(
                        hasPhone
                            ? phone
                            : LocaleKeys.communicationNoPhoneNumber.tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppStyles.bodyStyle.copyWith(
                          fontSize: context.sp(13),
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildActionButton(
            context,
            icon: Icons.call_rounded,
            color: AppColors.success,
            onTap: () => _openInAppCall(context, user, isVideo: false),
          ),
          SizedBox(width: context.w(1.5)),
          _buildActionButton(
            context,
            icon: Icons.videocam_rounded,
            color: AppColors.primary,
            onTap: () => _openInAppCall(context, user, isVideo: true),
          ),
          if (hasPhone) ...[
            SizedBox(width: context.w(1.5)),
            _buildActionButton(
              context,
              icon: Icons.phone_android_rounded,
              color: AppColors.info,
              onTap: () => _makePhoneCall(phone),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(context.w(2.5)),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: context.sp(22)),
      ),
    );
  }

  void _openInAppCall(BuildContext context, User user, {required bool isVideo}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CallPage(
          isVideo: isVideo,
          contactName: user.fullName,
          contactImage: user.profileImage,
          contactId: user.id,
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
}
