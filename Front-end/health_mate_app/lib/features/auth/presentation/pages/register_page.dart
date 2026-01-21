import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/utils/navigation_utils.dart';
import '../providers/auth_provider.dart';
import 'email_verification_page.dart';
import '../../../../features/linking/presentation/pages/qr_scanner_page.dart';

class RegisterPage extends ConsumerStatefulWidget {
  final String initialRole;
  const RegisterPage({super.key, this.initialRole = 'patient'});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Patient specific fields
  final _birthDayController = TextEditingController();
  final _birthMonthController = TextEditingController();
  final _birthYearController = TextEditingController();
  String? _selectedGender;

  bool _obscurePassword = true;
  late String _selectedRole;
  File? _profileImage;
  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
    // Clear any existing errors when this page is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).clearError();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    _birthDayController.dispose();
    _birthMonthController.dispose();
    _birthYearController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(LocaleKeys.authSelectGender.tr())),
        );
        return;
      }

      String? birthDate;
      if (_birthYearController.text.isNotEmpty &&
          _birthMonthController.text.isNotEmpty &&
          _birthDayController.text.isNotEmpty) {
        // Format as YYYY-MM-DD
        final year = _birthYearController.text.padLeft(4, '0');
        final month = _birthMonthController.text.padLeft(2, '0');
        final day = _birthDayController.text.padLeft(2, '0');
        birthDate = '$year-$month-$day';
      }

      await ref.read(authNotifierProvider.notifier).register(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            fullName: _fullNameController.text.trim(),
            phone: _phoneController.text.trim(),
            role: _selectedRole,
            birthDate: birthDate,
            gender: _selectedGender,
            profileImage: _profileImage,
          );
    }
  }

  Future<void> _handleGoogleSignIn() async {
    // Show professional dialog to collect missing fields
    final result = await _showGoogleCompleteProfileDialog();

    if (result == true) {
      final birthDate =
          "${_birthYearController.text}-${_birthMonthController.text.padLeft(2, '0')}-${_birthDayController.text.padLeft(2, '0')}";

      await ref.read(authNotifierProvider.notifier).loginWithGoogle(
            role: _selectedRole,
            isSignup: true,
            phone: _phoneController.text.trim(),
            birthDate: birthDate,
            gender: _selectedGender,
          );
    }
  }

  Future<bool?> _showGoogleCompleteProfileDialog() async {
    final googleFormKey = GlobalKey<FormState>();

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            titlePadding: EdgeInsets.zero,
            contentPadding: EdgeInsets.symmetric(
                horizontal: context.w(6), vertical: context.h(2.5)),
            title: Container(
              padding: EdgeInsets.symmetric(vertical: context.h(3)),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.account_circle_outlined,
                      color: Colors.white, size: context.sp(48)),
                  SizedBox(height: context.h(1.5)),
                  Text(
                    LocaleKeys.authCompleteProfile.tr(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: context.sp(20),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            content: SingleChildScrollView(
              child: Form(
                key: googleFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleKeys.authCompleteProfileSubtitle.tr(),
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: context.sp(13)),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: context.h(3)),

                    // Phone Field
                    Text(LocaleKeys.authEnterPhone.tr(),
                        style: AppStyles.labelStyle
                            .copyWith(fontSize: context.sp(14))),
                    SizedBox(height: context.h(1)),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: LocaleKeys.authEnterPhone.tr(),
                      keyboardType: TextInputType.phone,
                      customIcon:
                          AppIcons.phone(color: AppColors.textSecondary),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        return null;
                      },
                    ),

                    SizedBox(height: context.h(2)),

                    // Birthday
                    Text(LocaleKeys.authBirthday.tr(),
                        style: AppStyles.labelStyle
                            .copyWith(fontSize: context.sp(14))),
                    SizedBox(height: context.h(1)),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _birthDayController,
                            hintText: LocaleKeys.authDay.tr(),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return LocaleKeys.errorsRequiredField.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: context.w(2)),
                        Expanded(
                          child: _buildTextField(
                            controller: _birthMonthController,
                            hintText: LocaleKeys.authMonth.tr(),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return LocaleKeys.errorsRequiredField.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: context.w(2)),
                        Expanded(
                          child: _buildTextField(
                            controller: _birthYearController,
                            hintText: LocaleKeys.authYear.tr(),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return LocaleKeys.errorsRequiredField.tr();
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: context.h(2)),

                    // Gender
                    Text(LocaleKeys.authGender.tr(),
                        style: AppStyles.labelStyle
                            .copyWith(fontSize: context.sp(14))),
                    SizedBox(height: context.h(1)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildGenderOption(
                                value: 'male',
                                label: LocaleKeys.authMale.tr(),
                                isSelected: _selectedGender == 'male',
                                onTap: () => setDialogState(
                                    () => _selectedGender = 'male'),
                                context: context,
                              ),
                            ),
                            SizedBox(width: context.w(3)),
                            Expanded(
                              child: _buildGenderOption(
                                value: 'female',
                                label: LocaleKeys.authFemale.tr(),
                                isSelected: _selectedGender == 'female',
                                onTap: () => setDialogState(
                                    () => _selectedGender = 'female'),
                                context: context,
                              ),
                            ),
                          ],
                        ),
                        if (_selectedGender == null) ...[
                          SizedBox(height: context.h(1)),
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Text(
                              LocaleKeys.errorsRequiredField.tr(),
                              style: TextStyle(
                                  color: AppColors.error,
                                  fontSize: context.sp(12)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actionsPadding: EdgeInsets.only(
                left: context.w(6), right: context.w(6), bottom: context.h(3)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(LocaleKeys.cancel.tr(),
                    style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  if (googleFormKey.currentState!.validate()) {
                    if (_selectedGender == null) {
                      setDialogState(() {}); // Trigger rebuild to show error
                      return;
                    }
                    Navigator.pop(context, true);
                  }
                },
                style: AppStyles.primaryButtonStyle.copyWith(
                  minimumSize: WidgetStateProperty.all(
                      Size(double.infinity, context.h(6.5))),
                ),
                child: Text(LocaleKeys.authFinishRegistration.tr()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildGenderOption({
    required String value,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: context.h(1.5)),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: context.sp(14),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Listen for unverified state
    ref.listen(authNotifierProvider, (previous, next) {
      if (next.status == AuthStatus.unverified) {
        Navigator.of(context).pushReplacement(
          FadePageRoute(page: const EmailVerificationPage()),
        );
      }
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Curved Header
            Stack(
              children: [
                ClipPath(
                  clipper: HeaderClipper(),
                  child: Container(
                    height: context.h(25),
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: context.h(8),
                  left: context.w(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocaleKeys.authRegister.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.sp(42),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        LocaleKeys.commonHello.tr(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: context.sp(28),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Back Button
                Positioned(
                  top: context.h(4),
                  left: context.w(2),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back_ios_new,
                        color: Colors.white, size: context.sp(20)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),

            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.w(6)),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: context.h(1)),
                    Text(
                      LocaleKeys.authCreateAccount.tr(),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: context.sp(26),
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    SizedBox(height: context.h(2)),

                    // Profile Picture Input
                    Center(
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Stack(
                          children: [
                            Container(
                              width: context.sp(100),
                              height: context.sp(100),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).dividerColor
                                    : Colors.grey[100],
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: _profileImage != null
                                  ? ClipOval(
                                      child: Image.file(
                                        _profileImage!,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Icon(Icons.camera_alt_outlined,
                                      size: context.sp(40),
                                      color: Colors.grey[400]),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                padding: EdgeInsets.all(context.w(1)),
                                decoration: const BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.add,
                                    color: Colors.white, size: context.sp(20)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: context.h(3)),

                    // Full Name
                    _buildLabel(LocaleKeys.authFullName.tr()),
                    _buildTextField(
                      controller: _fullNameController,
                      hintText: LocaleKeys.authEnterName.tr(),
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.h(2)),

                    // Email
                    _buildLabel(LocaleKeys.authEmail.tr()),
                    _buildTextField(
                      controller: _emailController,
                      hintText: LocaleKeys.authEnterEmail.tr(),
                      customIcon:
                          AppIcons.email(color: AppColors.textSecondary),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        if (!value.contains('@')) {
                          return LocaleKeys.errorsInvalidEmail.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.h(2)),

                    // Password
                    _buildLabel(LocaleKeys.authPassword.tr()),
                    _buildTextField(
                      controller: _passwordController,
                      hintText: LocaleKeys.authCreatePassword.tr(),
                      customIcon: AppIcons.password(
                          color: AppColors.textSecondary, size: context.sp(20)),
                      isPassword: true,
                      obscureText: _obscurePassword,
                      onTogglePassword: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        if (value.length < 8) {
                          return LocaleKeys.errorsPasswordTooShort.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.h(2)),

                    // Phone
                    _buildLabel(LocaleKeys.authPhone.tr()),
                    _buildTextField(
                      controller: _phoneController,
                      hintText: LocaleKeys.authEnterPhone.tr(),
                      customIcon:
                          AppIcons.phone(color: AppColors.textSecondary),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return LocaleKeys.errorsRequiredField.tr();
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: context.h(2)),

                    // Birthday
                    _buildLabel(LocaleKeys.authBirthday.tr()),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSmallTextField(
                            controller: _birthDayController,
                            hintText: LocaleKeys.authDay.tr(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return '';
                              final d = int.tryParse(value);
                              if (d == null || d < 1 || d > 31) return '';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: context.w(3)),
                        Expanded(
                          child: _buildSmallTextField(
                            controller: _birthMonthController,
                            hintText: LocaleKeys.authMonth.tr(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return '';
                              final m = int.tryParse(value);
                              if (m == null || m < 1 || m > 12) return '';
                              return null;
                            },
                          ),
                        ),
                        SizedBox(width: context.w(3)),
                        Expanded(
                          child: _buildSmallTextField(
                            controller: _birthYearController,
                            hintText: LocaleKeys.authYear.tr(),
                            validator: (value) {
                              if (value == null || value.isEmpty) return '';
                              final y = int.tryParse(value);
                              final now = DateTime.now().year;
                              if (y == null || y < 1900 || y > now) return '';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(2)),

                    // Gender
                    _buildLabel(LocaleKeys.authGender.tr()),
                    Row(
                      children: [
                        Expanded(
                            child: _buildRoleChip(
                                'male', LocaleKeys.authMale.tr(),
                                isGender: true)),
                        SizedBox(width: context.w(3)),
                        Expanded(
                            child: _buildRoleChip(
                                'female', LocaleKeys.authFemale.tr(),
                                isGender: true)),
                      ],
                    ),
                    if (_selectedGender == null)
                      Padding(
                        padding: EdgeInsetsDirectional.only(
                            top: context.h(0.5), start: context.w(2)),
                        child: Text(
                          LocaleKeys.errorsRequiredField.tr(),
                          style: TextStyle(
                              color: AppColors.error, fontSize: context.sp(12)),
                        ),
                      ),

                    if (_selectedRole == 'caregiver') ...[
                      // Caregiver QR Banner
                      SizedBox(height: context.h(3)),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const QRScannerPage()),
                          );
                        },
                        child: Container(
                          height: context.h(18),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            image: const DecorationImage(
                              image: NetworkImage(
                                  'https://img.freepik.com/free-vector/qr-code-concept-illustration_114360-5853.jpg'),
                              fit: BoxFit.cover,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                blurRadius: 15,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              gradient: LinearGradient(
                                colors: [
                                  AppColors.black.withValues(alpha: 0.7),
                                  AppColors.transparent
                                ],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                            ),
                            padding: EdgeInsets.all(context.w(5)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.qr_code_scanner,
                                        color: Colors.white,
                                        size: context.sp(24)),
                                    SizedBox(width: context.w(2)),
                                    Expanded(
                                      child: Text(
                                        LocaleKeys.authScanQrCodeOn.tr(),
                                        style: TextStyle(
                                            color: AppColors.white,
                                            fontSize: context.sp(18),
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.only(
                                      start: context.w(8)),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        LocaleKeys.authThePatients.tr(),
                                        style: TextStyle(
                                            color: AppColors.white
                                                .withValues(alpha: 0.9),
                                            fontSize: context.sp(16),
                                            fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        LocaleKeys.authDevice.tr(),
                                        style: TextStyle(
                                            color: AppColors.white
                                                .withValues(alpha: 0.9),
                                            fontSize: context.sp(16),
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],

                    SizedBox(height: context.h(4)),

                    // Error Message
                    if (authState.status == AuthStatus.error)
                      Padding(
                        padding: EdgeInsets.only(bottom: context.h(3)),
                        child: Container(
                          padding: EdgeInsets.all(context.w(3)),
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.error.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                AppIcons.error,
                                color: AppColors.error,
                                size: context.sp(20),
                              ),
                              SizedBox(width: context.w(2)),
                              Expanded(
                                child: Text(
                                  authState.errorMessage ??
                                      LocaleKeys.errorsServerError.tr(),
                                  style: TextStyle(
                                    color: AppColors.error,
                                    fontSize: context.sp(13),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Register Button
                    _buildPrimaryButton(
                      onPressed: isLoading ? null : _handleRegister,
                      isLoading: isLoading,
                      text: LocaleKeys.authRegister.tr(),
                    ),

                    SizedBox(height: context.h(2)),

                    // Google Register
                    _buildPrimaryButton(
                      onPressed: isLoading ? null : _handleGoogleSignIn,
                      isLoading: isLoading,
                      text: LocaleKeys.authRegisterGoogle.tr(),
                      icon: Image.network(
                        AssetsConstants.googleLogoUrl,
                        height: context.sp(24),
                      ),
                      isOutline: true,
                    ),

                    SizedBox(height: context.h(4)),

                    // Login Link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${LocaleKeys.authAlreadyHaveAccount.tr()} ',
                          style: TextStyle(
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              fontSize: context.sp(14)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Text(
                            LocaleKeys.authLoginNow.tr(),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: context.sp(14),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: context.h(5)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String value, String label, {bool isGender = false}) {
    bool isSelected =
        isGender ? _selectedGender == value : _selectedRole == value;
    return GestureDetector(
      onTap: () => setState(() {
        if (isGender) {
          _selectedGender = value;
        } else {
          _selectedRole = value;
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: context.h(2)),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey[300]!,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: FontWeight.bold,
              fontSize: context.sp(14),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(
          left: context.w(1), bottom: context.h(1), top: context.h(1)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: context.sp(16),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    Widget? customIcon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontSize: context.sp(16)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
        prefixIcon: customIcon != null
            ? Padding(
                padding: const EdgeInsets.all(12.0),
                child: customIcon,
              )
            : (icon != null
                ? Icon(icon, color: Theme.of(context).iconTheme.color)
                : null),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? AppIcons.visibility : AppIcons.visibilityOff,
                  color: Theme.of(context).iconTheme.color,
                  size: context.sp(20),
                ),
                onPressed: onTogglePassword,
              )
            : null,
      ),
    );
  }

  Widget _buildSmallTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      validator: validator,
      style: Theme.of(context)
          .textTheme
          .bodyLarge
          ?.copyWith(fontSize: context.sp(16)),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).inputDecorationTheme.hintStyle,
        contentPadding: EdgeInsets.symmetric(vertical: context.h(1.5)),
        errorStyle:
            const TextStyle(height: 0, fontSize: 0), // Hide text, show border
      ),
    );
  }

  Widget _buildPrimaryButton({
    required VoidCallback? onPressed,
    required String text,
    bool isLoading = false,
    Widget? icon,
    bool isOutline = false,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: (isOutline
              ? AppStyles.secondaryButtonStyle
              : AppStyles.primaryButtonStyle)
          .copyWith(
        minimumSize:
            WidgetStateProperty.all(Size(double.infinity, context.h(7))),
        shape: WidgetStateProperty.all(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        )),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isLoading)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(4)),
                child: SizedBox(
                  height: context.sp(24),
                  width: context.sp(24),
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else if (icon != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: context.w(4)),
                child: icon,
              ),
            ),
          Align(
            alignment: Alignment.center,
            child: Text(
              text,
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HeaderClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    var path = Path();
    path.lineTo(0, size.height - 60);
    path.quadraticBezierTo(
      size.width / 4,
      size.height,
      size.width / 2,
      size.height - 30,
    );
    path.quadraticBezierTo(
      size.width * 3 / 4,
      size.height - 60,
      size.width,
      size.height - 10,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
