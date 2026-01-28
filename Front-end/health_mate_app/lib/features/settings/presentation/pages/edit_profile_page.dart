import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});

  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _birthdayController;
  String? _selectedGender;
  XFile? _selectedImage;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authNotifierProvider).user;
    _nameController = TextEditingController(text: user?.fullName);
    _phoneController = TextEditingController(text: user?.phone);
    _birthdayController = TextEditingController(text: user?.birthDate);
    _selectedGender = user?.gender;
    if (user?.birthDate != null) {
      try {
        _selectedDate = DateTime.parse(user!.birthDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      // 1. Upload image if selected
      if (_selectedImage != null) {
        await ref.read(authNotifierProvider.notifier).uploadProfileImage(
            await MultipartFile.fromFile(_selectedImage!.path));
      }

      // 2. Update profile information
      await ref.read(authNotifierProvider.notifier).updateProfile(
            fullName: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
            birthDate: _birthdayController.text.trim(),
            gender: _selectedGender,
          );

      if (mounted &&
          ref.read(authNotifierProvider).status != AuthStatus.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.authProfileUpdated.tr(),
                style: TextStyle(fontSize: context.sp(14))),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isLoading = authState.status == AuthStatus.loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.authEditProfile.tr(),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.pageBackground.withValues(alpha: 0.05)
              : AppColors.pageBackground,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            context.w(6),
            ExpertAppBar.getAppBarPadding(context),
            context.w(6),
            context.h(4),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Profile Image Selection
                _buildImagePicker(user),
                SizedBox(height: context.h(4)),

                // Input Fields Container
                Container(
                  padding: EdgeInsets.all(context.w(5)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      _buildTextField(
                        controller: _nameController,
                        label: LocaleKeys.authFullName.tr(),
                        icon: Icons.person_outline,
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
                      SizedBox(height: context.h(2.5)),

                      // Phone
                      _buildTextField(
                        controller: _phoneController,
                        label: LocaleKeys.authPhone.tr(),
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value != null &&
                              value.isNotEmpty &&
                              value.length < 5) {
                            return LocaleKeys.errorsInvalidPhone.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: context.h(2.5)),

                      // Birth Date
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: _buildTextField(
                            controller: _birthdayController,
                            label: LocaleKeys.authBirthday.tr(),
                            icon: Icons.calendar_today_outlined,
                          ),
                        ),
                      ),
                      SizedBox(height: context.h(2.5)),

                      // Gender Selection
                      Text(
                        LocaleKeys.authGender.tr(),
                        style: TextStyle(
                          fontSize: context.sp(14),
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: context.h(1.2)),
                      _buildGenderSelector(),
                    ],
                  ),
                ),
                SizedBox(height: context.h(6)),

                // Action Buttons
                _buildActionButtons(isLoading),

                // Error Message
                if (authState.status == AuthStatus.error)
                  _buildErrorContainer(authState.errorMessage),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Row(
      children: [
        Expanded(
          child: _genderOption(
            label: LocaleKeys.authMale.tr(),
            value: 'male',
            icon: Icons.male,
          ),
        ),
        SizedBox(width: context.w(3)),
        Expanded(
          child: _genderOption(
            label: LocaleKeys.authFemale.tr(),
            value: 'female',
            icon: Icons.female,
          ),
        ),
      ],
    );
  }

  Widget _genderOption({
    required String label,
    required String value,
    required IconData icon,
  }) {
    final isSelected = _selectedGender == value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedGender = value),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: context.h(1.5)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : (isDark
                  ? AppColors.cardDark.withValues(alpha: 0.3)
                  : AppColors.backgroundLight.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.border.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
              size: context.sp(20),
            ),
            SizedBox(width: context.w(2)),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: context.sp(14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker(dynamic user) {
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
                  color: AppColors.primary.withValues(alpha: 0.2),
                  width: 2,
                ),
              ),
              child: CircleAvatar(
                radius: context.sp(60),
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: _selectedImage != null
                    ? FileImage(File(_selectedImage!.path)) as ImageProvider
                    : (user?.profileImage != null
                        ? NetworkImage(user!.profileImage!)
                        : null),
                child: _selectedImage == null && user?.profileImage == null
                    ? Icon(
                        Icons.person_outline,
                        size: context.sp(50),
                        color: AppColors.primary,
                      )
                    : null,
              ),
            ),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt,
                  size: context.sp(20),
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: context.h(1.5)),
        Text(
          LocaleKeys.authEditProfile.tr(),
          style: TextStyle(
            fontSize: context.sp(14),
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: context.sp(16),
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.textSecondary,
          fontSize: context.sp(14),
        ),
        prefixIcon: Icon(
          icon,
          color: AppColors.primary.withValues(alpha: 0.7),
          size: context.sp(22),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: AppColors.border.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.cardDark.withValues(alpha: 0.3)
            : AppColors.backgroundLight.withValues(alpha: 0.5),
      ),
      validator: validator,
    );
  }

  Widget _buildActionButtons(bool isLoading) {
    return Column(
      children: [
        ElevatedButton(
          onPressed: isLoading ? null : _handleSave,
          style: AppStyles.primaryButtonStyle.copyWith(
            minimumSize:
                WidgetStateProperty.all(Size(double.infinity, context.h(7))),
            shape: WidgetStateProperty.all(RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            )),
          ),
          child: isLoading
              ? SizedBox(
                  height: context.sp(24),
                  width: context.sp(24),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                )
              : Text(
                  LocaleKeys.save.tr().toUpperCase(),
                  style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                    color: Colors.white,
                  ),
                ),
        ),
        SizedBox(height: context.h(2)),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            LocaleKeys.cancel.tr(),
            style: TextStyle(
              fontSize: context.sp(16),
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContainer(String? message) {
    return Padding(
      padding: EdgeInsets.only(top: context.h(3)),
      child: Container(
        padding: EdgeInsets.all(context.w(4)),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline,
                color: AppColors.error, size: context.sp(20)),
            SizedBox(width: context.w(3)),
            Expanded(
              child: Text(
                message ?? LocaleKeys.errorsSomethingWentWrong.tr(),
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: context.sp(13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
