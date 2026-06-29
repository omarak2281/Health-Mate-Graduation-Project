import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/models/user.dart';
import '../../../../core/widgets/connectivity_status_widget.dart';

/// Caregiver User Header Widget
/// Identical gradient style to PatientHomePage header for consistent branding
class CaregiverUserHeader extends StatelessWidget {
  final User? user;

  const CaregiverUserHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final fullName = user?.fullName.trim() ?? '';
    final nameParts = fullName.isNotEmpty ? fullName.split(' ') : [];
    final firstName =
        nameParts.isNotEmpty ? nameParts.first : LocaleKeys.commonHello.tr();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.9),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: Stack(
          children: [
            // Decorative Circles matching ExpertAppBar
            Positioned(
              top: -15,
              right: -15,
              child: CircleAvatar(
                radius: 45,
                backgroundColor: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            Positioned(
              bottom: -20,
              left: -10,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.white.withValues(alpha: 0.03),
              ),
            ),

            // Header Content
            Padding(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 16,
                left: context.w(5),
                right: context.w(5),
              ),
              child: Row(
                children: [
                  // Profile Picture
                  Container(
                    width: context.sp(48),
                    height: context.sp(48),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                    ),
                    child: ClipOval(
                      child: user?.profileImage != null
                          ? Image.network(
                              user!.profileImage!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return _buildDefaultAvatar(context);
                              },
                            )
                          : _buildDefaultAvatar(context),
                    ),
                  ),
                  SizedBox(width: context.w(4)),

                  // Greeting Text
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          LocaleKeys.commonHello.tr(),
                          style: TextStyle(
                            fontSize: context.sp(14),
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Text(
                          firstName,
                          style: TextStyle(
                            fontSize: context.sp(20),
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Caregiver badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: context.w(3),
                      vertical: context.h(0.5),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.medical_services_outlined,
                          size: context.sp(12),
                          color: Colors.white,
                        ),
                        SizedBox(width: context.w(1)),
                        Text(
                          LocaleKeys.authCaregiver.tr(),
                          style: TextStyle(
                            fontSize: context.sp(11),
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ConnectivityStatusWidget(showText: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar(BuildContext context) {
    return Container(
      color: Colors.white.withValues(alpha: 0.2),
      child: Icon(
        Icons.person_outline,
        color: Colors.white,
        size: context.sp(24),
      ),
    );
  }
}

/// Caregiver Stats Overview Card
/// Shows at-a-glance summary of linked patients
class CaregiverStatsCard extends StatelessWidget {
  final int patientCount;
  final int activeAlerts;

  const CaregiverStatsCard({
    super.key,
    required this.patientCount,
    required this.activeAlerts,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatColumn(
              context,
              icon: AppIcons.people,
              iconColor: AppColors.primary,
              value: patientCount.toString(),
              label: LocaleKeys.homeLinkedPatients.tr(),
            ),
          ),
          Container(
            width: 1,
            height: context.h(6),
            color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
          ),
          Expanded(
            child: _buildStatColumn(
              context,
              icon: AppIcons.notifications,
              iconColor:
                  activeAlerts > 0 ? AppColors.riskHigh : AppColors.riskNormal,
              value: activeAlerts.toString(),
              label: LocaleKeys.homeRecentAlerts.tr(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(context.w(2.5)),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: context.sp(22), color: iconColor),
        ),
        SizedBox(height: context.h(1)),
        Text(
          value,
          style: TextStyle(
            fontSize: context.sp(24),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.displayLarge?.color,
          ),
        ),
        SizedBox(height: context.h(0.3)),
        Text(
          label,
          style: TextStyle(
            fontSize: context.sp(11),
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// Linked Patient Premium Card
/// Rich card matching the premium patient dashboard card style
class LinkedPatientCard extends StatelessWidget {
  final User patient;
  final VoidCallback onTap;
  final String? lastBpReading;
  final String? statusLabel;
  final Color? statusColor;

  const LinkedPatientCard({
    super.key,
    required this.patient,
    required this.onTap,
    this.lastBpReading,
    this.statusLabel,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveStatusColor = statusColor ?? AppColors.riskNormal;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: context.h(2)),
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with online indicator
            Stack(
              children: [
                Container(
                  width: context.sp(52),
                  height: context.sp(52),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: ClipOval(
                    child: patient.profileImage != null
                        ? Image.network(
                            patient.profileImage!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildDefaultPatientAvatar(context),
                          )
                        : _buildDefaultPatientAvatar(context),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: context.sp(14),
                    height: context.sp(14),
                    decoration: BoxDecoration(
                      color: effectiveStatusColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color:
                            Theme.of(context).cardTheme.color ?? Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(width: context.w(4)),

            // Patient Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    patient.fullName,
                    style: TextStyle(
                      fontSize: context.sp(16),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.h(0.4)),
                  Text(
                    patient.email,
                    style: TextStyle(
                      fontSize: context.sp(12),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: context.h(0.8)),

                  // Last BP reading chip
                  if (lastBpReading != null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(2),
                        vertical: context.h(0.3),
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcons.bloodPressure(
                            size: context.sp(12),
                            color: AppColors.primary,
                          ),
                          SizedBox(width: context.w(1)),
                          Text(
                            lastBpReading!,
                            style: TextStyle(
                              fontSize: context.sp(11),
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Status chip
                  if (statusLabel != null && lastBpReading == null)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(2),
                        vertical: context.h(0.3),
                      ),
                      decoration: BoxDecoration(
                        color: effectiveStatusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusLabel!,
                        style: TextStyle(
                          fontSize: context.sp(11),
                          color: effectiveStatusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Chevron
            Icon(
              AppIcons.chevronRight,
              size: context.sp(20),
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultPatientAvatar(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.1),
      child: Icon(
        AppIcons.person,
        size: context.sp(28),
        color: AppColors.primary,
      ),
    );
  }
}

/// Caregiver Quick Action Card
/// Premium quick-action tile for scanner and other actions
class CaregiverQuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const CaregiverQuickActionCard({
    super.key,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: isDark ? 0.25 : 0.12),
              color.withValues(alpha: isDark ? 0.15 : 0.06),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(3)),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: context.sp(22)),
            ),
            SizedBox(width: context.w(3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: context.h(0.3)),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: context.sp(11),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              AppIcons.chevronRight,
              color: color.withValues(alpha: 0.7),
              size: context.sp(18),
            ),
          ],
        ),
      ),
    );
  }
}

/// Caregiver Alert Card
/// Premium alert card for recent patient alerts
class CaregiverAlertCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isEmpty;

  const CaregiverAlertCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.isEmpty = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isEmpty) {
      return Container(
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(context.w(2.5)),
              decoration: BoxDecoration(
                color: AppColors.riskNormal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                size: context.sp(22),
                color: AppColors.riskNormal,
              ),
            ),
            SizedBox(width: context.w(3)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleKeys.homeNoActiveAlerts.tr(),
                    style: TextStyle(
                      fontSize: context.sp(14),
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  SizedBox(height: context.h(0.3)),
                  Text(
                    LocaleKeys.homeAlertsSubtitle.tr(),
                    style: TextStyle(
                      fontSize: context.sp(12),
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(context.w(4)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(context.w(2.5)),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: context.sp(22), color: color),
          ),
          SizedBox(width: context.w(3)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: context.sp(14),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                SizedBox(height: context.h(0.3)),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: context.sp(12),
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty Linked State Widget
/// Premium empty state for when no patients are linked
class CaregiverEmptyLinkedState extends StatelessWidget {
  const CaregiverEmptyLinkedState({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        vertical: context.h(5),
        horizontal: context.w(6),
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(context.w(5)),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.people,
              size: context.sp(52),
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: context.h(2.5)),
          Text(
            LocaleKeys.homeNoLinkedPatients.tr(),
            style: TextStyle(
              fontSize: context.sp(18),
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: context.h(1)),
          Text(
            LocaleKeys.homeScanToLinkSubtitle.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.sp(14),
              color: Theme.of(context).textTheme.bodyMedium?.color,
              height: 1.5,
            ),
          ),
          SizedBox(height: context.h(1)),
        ],
      ),
    );
  }
}

/// Section Header Widget — reusable premium section title
class CaregiverSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const CaregiverSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: context.sp(17),
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
