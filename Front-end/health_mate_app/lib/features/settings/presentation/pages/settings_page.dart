import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../linking/presentation/pages/qr_code_page.dart';
import 'package:dio/dio.dart';
import './edit_profile_page.dart';
import './change_password_page.dart';

/// Settings Page
/// Profile, language, theme, logout

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleKeys.authUploadingImage.tr())),
      );

      await ref
          .read(authNotifierProvider.notifier)
          .uploadProfileImage(await MultipartFile.fromFile(image.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authNotifierProvider).user;
    final currentLocale = context.locale;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.settingsTitle.tr())),
      body: ListView(
        children: [
          // Profile Section
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      InkWell(
                        onTap: _pickImage,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primaryLight,
                          backgroundImage: user?.profileImage != null
                              ? NetworkImage(user!.profileImage!)
                              : null,
                          child: user?.profileImage == null
                              ? const Icon(
                                  Icons.person,
                                  size: 50,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: InkWell(
                          onTap: user?.isPatient == true
                              ? () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const QRCodePage(),
                                  ),
                                )
                              : null,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              user?.isPatient == true
                                  ? Icons.qr_code
                                  : Icons.camera_alt,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user?.fullName ?? '',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const EditProfilePage(),
                      ),
                    ),
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(LocaleKeys.authEditProfile.tr()),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ChangePasswordPage(),
                      ),
                    ),
                    icon: const Icon(Icons.lock_outline, size: 16),
                    label: Text(LocaleKeys.settingsChangePassword.tr()),
                  ),
                ],
              ),
            ),
          ),

          // Language Section
          _buildSection(
            context,
            LocaleKeys.settingsLanguage.tr(),
            Icons.language,
            [
              ListTile(
                title: const Text('English'),
                trailing: currentLocale.languageCode == 'en'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  context.setLocale(const Locale('en'));
                },
              ),
              ListTile(
                title: const Text('العربية'),
                trailing: currentLocale.languageCode == 'ar'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  context.setLocale(const Locale('ar'));
                },
              ),
            ],
          ),

          // Theme Section
          _buildSection(context, LocaleKeys.settingsTheme.tr(), Icons.palette, [
            ListTile(
              title: Text(LocaleKeys.settingsThemeLight.tr()),
              trailing: const Icon(Icons.light_mode),
              onTap: () {
                // Future: Theme toggle
              },
            ),
            ListTile(
              title: Text(LocaleKeys.settingsThemeDark.tr()),
              trailing: const Icon(Icons.dark_mode),
              onTap: () {
                // Future: Theme toggle
              },
            ),
          ]),

          // About Section
          _buildSection(context, LocaleKeys.settingsAbout.tr(), Icons.info, [
            ListTile(
              title: Text(LocaleKeys.settingsVersion.tr()),
              subtitle: const Text('1.0.0'),
              trailing: const Icon(Icons.smartphone),
            ),
          ]),

          const SizedBox(height: 24),

          // Logout Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(LocaleKeys.authLogout.tr()),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(LocaleKeys.cancel.tr()),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                        ),
                        child: Text(LocaleKeys.authLogout.tr()),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  await ref.read(authNotifierProvider.notifier).logout();
                }
              },
              icon: const Icon(Icons.logout),
              label: Text(LocaleKeys.authLogout.tr()),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                padding: const EdgeInsets.all(16),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(children: children),
        ),
      ],
    );
  }
}
