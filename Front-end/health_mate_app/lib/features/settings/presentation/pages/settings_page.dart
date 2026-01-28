import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../linking/presentation/pages/qr_code_page.dart';
import '../../../linking/presentation/providers/linking_provider.dart';

import './edit_profile_page.dart';
import './change_password_page.dart';
import '../../../auth/presentation/pages/splash_page.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../../core/widgets/expert_app_bar.dart';
import '../../../contacts/presentation/pages/medical_contacts_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    // Navigate to splash on logout/delete
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.unauthenticated) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const SplashPage()),
          (route) => false,
        );
      }
    });

    final user = ref.watch(authNotifierProvider).user;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = context.locale;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.settingsTitle.tr(),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.pageBackground,
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            context.w(5),
            ExpertAppBar.getAppBarPadding(context),
            context.w(5),
            context.h(4),
          ),
          children: [
            // Profile Section
            _buildProfileSection(user, isDark),
            SizedBox(height: context.h(3)),

            // QR Code Section (Only for patients)
            if (user?.isPatient == true) ...[
              _buildQRCodeCard(isDark),
              SizedBox(height: context.h(3)),
            ],

            // Linked Companions Section
            _buildLinkedCompanionsSection(isDark),
            SizedBox(height: context.h(3)),

            // General Section
            _buildGeneralSection(currentLocale, isDark),
            SizedBox(height: context.h(3)),

            // Account Section
            _buildAccountSection(isDark),
            SizedBox(height: context.h(4)),

            // Logout Button
            _buildLogoutButton(isDark),

            SizedBox(height: context.h(2)),
            // Version Info
            Center(
              child: Text(
                '${LocaleKeys.settingsVersion.tr()} ${AppConstants.appVersion}',
                style: TextStyle(
                  fontSize: context.sp(12),
                  color: isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.5)
                      : AppColors.textSecondary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(dynamic user, bool isDark) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: context.sp(55),
                backgroundColor: isDark
                    ? AppColors.surfaceDark
                    : AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: user?.profileImage != null
                    ? NetworkImage(user!.profileImage!)
                    : null,
                child: user?.profileImage == null
                    ? Icon(
                        AppIcons.person,
                        size: context.sp(50),
                        color:
                            isDark ? AppColors.primaryLight : AppColors.primary,
                      )
                    : null,
              ),
            ),
            Positioned(
              right: 8,
              bottom: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfilePage()),
                ),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.primary : AppColors.primaryLight,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.edit,
                    size: context.sp(18),
                    color: isDark ? Colors.white : AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(2)),
        Text(
          user?.fullName ?? '',
          style: TextStyle(
            fontSize: context.sp(22),
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.h(0.8)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: context.w(4),
                vertical: context.h(0.5),
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.25)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                (user?.isPatient == true
                        ? LocaleKeys.authPatient.tr()
                        : LocaleKeys.authCaregiver.tr())
                    .toUpperCase(),
                style: TextStyle(
                  fontSize: context.sp(10),
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(2)),
        // Personal Metrics Row (Expert Style)
        Container(
          margin: EdgeInsets.symmetric(vertical: context.h(1)),
          padding: EdgeInsets.symmetric(
              horizontal: context.w(4), vertical: context.h(1.8)),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark
                  ? AppColors.borderDark
                  : AppColors.primary.withValues(alpha: 0.1),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildExpertMetricItem(
                context,
                icon: Icons.cake_outlined,
                value: '${_calculateAge(user?.birthDate) ?? '--'}',
                label: LocaleKeys.settingsYears.tr(),
                color: AppColors.primary,
                isDark: isDark,
              ),
              Container(
                height: context.h(4),
                width: 1.5,
                margin: EdgeInsets.symmetric(horizontal: context.w(4)),
                color: isDark
                    ? Colors.white12
                    : AppColors.primary.withValues(alpha: 0.1),
              ),
              _buildExpertMetricItem(
                context,
                icon: user?.gender == 'female' ? Icons.female : Icons.male,
                value: user?.gender != null
                    ? (user!.gender == 'male'
                        ? LocaleKeys.authMale.tr()
                        : LocaleKeys.authFemale.tr())
                    : '--',
                label: LocaleKeys.authGender.tr(),
                color: user?.gender == 'female' ? Colors.pink : Colors.blue,
                isDark: isDark,
              ),
            ],
          ),
        ),
        SizedBox(height: context.h(2)),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditProfilePage()),
          ),
          icon: Icon(Icons.edit_note,
              size: context.sp(20),
              color: isDark ? AppColors.primaryLight : AppColors.primary),
          label: Text(
            LocaleKeys.authEditProfile.tr(),
            style: TextStyle(
              fontSize: context.sp(14),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  int? _calculateAge(String? birthDate) {
    if (birthDate == null || birthDate.isEmpty) return null;
    try {
      final birth = DateTime.parse(birthDate);
      final now = DateTime.now();
      int age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  Widget _buildQRCodeCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(context.w(5)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? AppColors.borderDark
              : AppColors.primary.withValues(alpha: 0.1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  AppIcons.qrCode,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                  size: context.sp(24),
                ),
              ),
              SizedBox(width: context.w(4)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.linkingMyQrCode.tr(),
                      style: TextStyle(
                        fontSize: context.sp(16),
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      LocaleKeys.settingsQrShareSubtitle.tr(),
                      style: TextStyle(
                        fontSize: context.sp(12),
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.h(2.5)),
          ElevatedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const QRCodePage(),
              ),
            ),
            style: AppStyles.primaryButtonStyle.copyWith(
              minimumSize:
                  WidgetStateProperty.all(Size(double.infinity, context.h(6))),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              )),
            ),
            child: Text(
              LocaleKeys.settingsRevealCode.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkedCompanionsSection(bool isDark) {
    final linkingState = ref.watch(linkingNotifierProvider);
    final user = ref.read(authNotifierProvider).user;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              user?.isPatient == true
                  ? LocaleKeys.settingsLinkedCompanions.tr()
                  : LocaleKeys.homeLinkedPatients.tr(),
              style: TextStyle(
                fontSize: context.sp(18),
                fontWeight: FontWeight.bold,
                color:
                    isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => const MedicalContactsPage()),
                );
              },
              child: Text(
                LocaleKeys.manage.tr(),
                style: TextStyle(
                  fontSize: context.sp(14),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(1)),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: isDark ? Border.all(color: AppColors.borderDark) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: linkingState.linkedUsers.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(context.w(5)),
                  child: Center(
                    child: Text(
                      LocaleKeys.contactsNoContacts.tr(),
                      style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(vertical: context.h(1)),
                  itemCount: linkingState.linkedUsers.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: context.w(15),
                    endIndent: context.w(5),
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.textSecondary.withValues(alpha: 0.1),
                  ),
                  itemBuilder: (context, index) {
                    final linkedUser = linkingState.linkedUsers[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 22,
                        backgroundColor: isDark
                            ? AppColors.primary.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.1),
                        backgroundImage: linkedUser.profileImage != null
                            ? NetworkImage(linkedUser.profileImage!)
                            : null,
                        child: linkedUser.profileImage == null
                            ? Icon(Icons.person,
                                color: isDark
                                    ? AppColors.primaryLight
                                    : AppColors.primary)
                            : null,
                      ),
                      title: Text(
                        linkedUser.fullName,
                        style: TextStyle(
                          fontSize: context.sp(15),
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${LocaleKeys.status.tr()}: ${LocaleKeys.active.tr()}',
                            style: TextStyle(
                              fontSize: context.sp(12),
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: isDark
                            ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                            : AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGeneralSection(Locale currentLocale, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settingsTitle.tr(),
          style: TextStyle(
            fontSize: context.sp(18),
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.h(1.5)),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: isDark ? Border.all(color: AppColors.borderDark) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Language
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.blue.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcons.language(
                      color: isDark ? Colors.blue[300] : Colors.blue[700],
                      size: context.sp(20)),
                ),
                title: Text(
                  LocaleKeys.settingsLanguage.tr(),
                  style: TextStyle(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.backgroundDark.withValues(alpha: 0.5)
                        : AppColors.backgroundLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildLangOption(
                        AppIcons.ukFlag(size: 24),
                        currentLocale.languageCode == 'en',
                        () => context.setLocale(const Locale('en')),
                        isDark,
                      ),
                      const SizedBox(width: 4),
                      _buildLangOption(
                        AppIcons.egyptFlag(size: 24),
                        currentLocale.languageCode == 'ar',
                        () => context.setLocale(const Locale('ar')),
                        isDark,
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                height: 1,
                indent: context.w(15),
                endIndent: context.w(5),
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.textSecondary.withValues(alpha: 0.1),
              ),
              // Dark Mode
              Consumer(builder: (context, ref, _) {
                final themeMode = ref.watch(themeProvider);
                final isCurrentDark = themeMode == ThemeMode.dark;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.indigo.withValues(alpha: 0.2)
                          : Colors.indigo.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.dark_mode_outlined,
                        color: isDark ? Colors.indigo[300] : Colors.indigo[700],
                        size: context.sp(20)),
                  ),
                  title: Text(
                    LocaleKeys.settingsThemeDark.tr(),
                    style: TextStyle(
                      fontSize: context.sp(15),
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: Switch.adaptive(
                    value: isCurrentDark,
                    activeColor: AppColors.primaryLight,
                    activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                    onChanged: (val) {
                      ref.read(themeProvider.notifier).toggleTheme();
                    },
                  ),
                );
              }),
              Divider(
                height: 1,
                indent: context.w(15),
                endIndent: context.w(5),
                color: isDark
                    ? AppColors.borderDark
                    : AppColors.textSecondary.withValues(alpha: 0.1),
              ),
              // Change Password
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: AppIcons.password(
                      color:
                          isDark ? AppColors.primaryLight : AppColors.primary,
                      size: context.sp(18)),
                ),
                title: Text(
                  LocaleKeys.settingsChangePassword.tr(),
                  style: TextStyle(
                    fontSize: context.sp(15),
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark
                      ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                      : AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChangePasswordPage()),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLangOption(
      Widget flag, bool isSelected, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.primary.withValues(alpha: 0.15))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (isDark ? AppColors.primaryLight : AppColors.primary)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: flag,
      ),
    );
  }

  Widget _buildAccountSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          LocaleKeys.settingsAccount.tr(),
          style: TextStyle(
            fontSize: context.sp(18),
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.h(1.5)),
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            border: isDark ? Border.all(color: AppColors.borderDark) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.error.withValues(alpha: 0.2)
                    : AppColors.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delete_outline,
                  color: isDark ? AppColors.accentRed : AppColors.error,
                  size: context.sp(20)),
            ),
            title: Text(
              LocaleKeys.settingsDeleteAccount.tr(),
              style: TextStyle(
                fontSize: context.sp(15),
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.accentRed : AppColors.error,
              ),
            ),
            subtitle: Text(
              LocaleKeys.settingsDeleteAccountDesc.tr(),
              style: TextStyle(
                fontSize: context.sp(11),
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            trailing: Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textSecondaryDark.withValues(alpha: 0.4)
                  : AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            onTap: () => _handleDeleteAccount(isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildExpertMetricItem(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
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
                    fontSize: context.sp(12),
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: context.h(0.5)),
      child: ElevatedButton(
        onPressed: () => _handleLogout(isDark),
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? Colors.redAccent.withValues(alpha: 0.15)
              : AppColors.error.withValues(alpha: 0.08),
          foregroundColor: isDark ? Colors.redAccent : AppColors.error,
          elevation: 0,
          padding: EdgeInsets.symmetric(vertical: context.h(2)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isDark
                    ? Colors.redAccent.withValues(alpha: 0.4)
                    : AppColors.error.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout_rounded, size: context.sp(20)),
            SizedBox(width: context.w(2)),
            Text(
              LocaleKeys.authLogout.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogout(bool isDark) async {
    final confirm = await _showExpertConfirmDialog(
      context,
      title: LocaleKeys.authLogout.tr(),
      message: LocaleKeys.settingsLogoutConfirm.tr(),
      confirmText: LocaleKeys.authLogout.tr(),
      isDestructive: true,
      isDark: isDark,
    );

    if (confirm == true && mounted) {
      await ref.read(authNotifierProvider.notifier).logout();
    }
  }

  Future<void> _handleDeleteAccount(bool isDark) async {
    final confirm = await _showExpertConfirmDialog(
      context,
      title: LocaleKeys.settingsDeleteAccount.tr(),
      message: LocaleKeys.settingsDeleteAccountDesc.tr(),
      confirmText: LocaleKeys.delete.tr(),
      isDestructive: true,
      isDark: isDark,
    );

    if (confirm == true && mounted) {
      try {
        await ref.read(authNotifierProvider.notifier).deleteAccount();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  Future<bool?> _showExpertConfirmDialog(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
    required bool isDark,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.symmetric(
            horizontal: context.w(6), vertical: context.h(2)),
        title: Container(
          padding: EdgeInsets.symmetric(vertical: context.h(2.5)),
          decoration: BoxDecoration(
            color: isDestructive
                ? AppColors.error.withValues(alpha: 0.1)
                : AppColors.primary.withValues(alpha: 0.1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              Icon(
                isDestructive
                    ? Icons.warning_amber_rounded
                    : Icons.info_outline,
                color: isDestructive ? AppColors.error : AppColors.primary,
                size: context.sp(40),
              ),
              SizedBox(height: context.h(1)),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: context.sp(20),
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(15),
            color: isDark ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
        actionsPadding:
            EdgeInsets.fromLTRB(context.w(4), 0, context.w(4), context.h(2.5)),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: context.h(1.8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    LocaleKeys.cancel.tr(),
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: context.sp(14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: context.w(3)),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        isDestructive ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: context.h(1.8)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    confirmText,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: context.sp(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
