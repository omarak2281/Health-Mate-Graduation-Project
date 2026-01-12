import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Edit Profile Page
/// Allows users to change their full name and phone number

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _nameController = TextEditingController(text: user?.fullName);
    _phoneController = TextEditingController(text: user?.phone);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      await ref
          .read(authNotifierProvider.notifier)
          .updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          );

      if (mounted &&
          ref.read(authNotifierProvider).status != AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.authProfileUpdated.tr())),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      appBar: AppBar(title: Text(LocaleKeys.authEditProfile.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.authFullName.tr(),
                  prefixIcon: const Icon(Icons.person_outlined),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return LocaleKeys.errorsRequiredField.tr();
                  }
                  if (value.length < 2) {
                    return LocaleKeys.errorsNameTooShort.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: LocaleKeys.authPhone.tr(),
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  if (value != null && value.isNotEmpty && value.length < 5) {
                    return LocaleKeys.errorsInvalidPhone.tr();
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: isLoading ? null : _handleSave,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    : Text(LocaleKeys.save.tr()),
              ),

              // Error Message
              if (authState.status == AuthStatus.error)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(
                    authState.errorMessage ?? LocaleKeys.errorsServerError.tr(),
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
