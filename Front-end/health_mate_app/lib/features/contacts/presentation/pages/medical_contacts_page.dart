import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medical_contacts_provider.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/models/medical_contact.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class MedicalContactsPage extends ConsumerWidget {
  const MedicalContactsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(medicalContactsNotifierProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.contactsTitle.tr(),
      ),
      body: state.isLoading && state.contacts.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Container(
              height: double.infinity,
              padding:
                  EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
              child: RefreshIndicator(
                onRefresh: () => ref
                    .read(medicalContactsNotifierProvider.notifier)
                    .loadContacts(),
                child: state.contacts.isEmpty
                    ? _buildEmptyState(context, ref)
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.w(4), vertical: context.h(2)),
                        itemCount: state.contacts.length,
                        itemBuilder: (context, index) {
                          final contact = state.contacts[index];
                          return _buildContactCard(context, ref, contact);
                        },
                      ),
              ),
            ),
      floatingActionButton: state.contacts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddContactDialog(context, ref),
              elevation: 4,
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(Icons.add_rounded,
                  size: context.sp(32), color: Colors.white),
            ),
    );
  }

  Widget _buildContactCard(
      BuildContext context, WidgetRef ref, MedicalContact contact) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeColor = _getTypeColor(contact.type);

    return Container(
      margin: EdgeInsets.only(bottom: context.h(2)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(
          color: isDark
              ? typeColor.withValues(alpha: 0.2)
              : typeColor.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _makePhoneCall(contact.phone),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: EdgeInsets.all(context.w(4)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(context.w(3)),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(contact.type),
                    color: typeColor,
                    size: context.sp(26),
                  ),
                ),
                SizedBox(width: context.w(4)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contact.name,
                        style: TextStyle(
                          fontSize: context.sp(17),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      SizedBox(height: context.h(0.5)),
                      Row(
                        children: [
                          Icon(Icons.phone_rounded,
                              size: context.sp(14),
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.color
                                  ?.withValues(alpha: 0.6)),
                          SizedBox(width: context.w(1.5)),
                          Text(
                            contact.phone,
                            style: TextStyle(
                              fontSize: context.sp(14),
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: context.h(0.5)),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: context.w(2.5),
                            vertical: context.h(0.4)),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTypeLabel(contact.type).toUpperCase(),
                          style: TextStyle(
                            fontSize: context.sp(10),
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionButton(
                      context,
                      icon: Icons.call_rounded,
                      color: AppColors.success,
                      onTap: () => _makePhoneCall(contact.phone),
                    ),
                    SizedBox(width: context.w(2)),
                    _buildActionButton(
                      context,
                      icon: Icons.delete_outline_rounded,
                      color: AppColors.error,
                      onTap: () => _confirmDelete(context, ref, contact.id),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required IconData icon,
      required Color color,
      required VoidCallback onTap}) {
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(context.w(8)),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              AppIcons.contacts,
              size: context.sp(80),
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
          ),
          SizedBox(height: context.h(4)),
          Text(
            LocaleKeys.contactsNoContacts.tr(),
            style: TextStyle(
                fontSize: context.sp(22),
                fontWeight: FontWeight.w900,
                color: Theme.of(context).textTheme.bodyLarge?.color),
          ),
          SizedBox(height: context.h(2)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: context.w(15)),
            child: Text(
              LocaleKeys.contactsAddInstructions.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: context.sp(15),
                  color: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.color
                      ?.withValues(alpha: 0.7),
                  height: 1.5),
            ),
          ),
          SizedBox(height: context.h(4)),
          ElevatedButton.icon(
            onPressed: () => _showAddContactDialog(context, ref),
            icon: Icon(Icons.add_rounded,
                size: context.sp(22), color: Colors.white),
            label: Text(
              LocaleKeys.contactsAddContact.tr(),
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            style: AppStyles.primaryButtonStyle.copyWith(
              minimumSize:
                  WidgetStateProperty.all(Size(context.w(60), context.h(6.5))),
              shape: WidgetStateProperty.all(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16))),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  void _showAddContactDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    String selectedType = 'doctor';
    final formKey = GlobalKey<FormState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          titlePadding: EdgeInsets.zero,
          contentPadding: EdgeInsets.symmetric(
              horizontal: context.w(6), vertical: context.h(2)),
          title: Container(
            padding: EdgeInsets.symmetric(vertical: context.h(3)),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.all(context.w(3)),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person_add_rounded,
                      color: Colors.white, size: context.sp(32)),
                ),
                SizedBox(height: context.h(1.5)),
                Text(
                  LocaleKeys.contactsAddContact.tr(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.sp(22),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLabel(context, LocaleKeys.authFullName.tr()),
                  SizedBox(height: context.h(1)),
                  _buildTextField(
                    context,
                    controller: nameController,
                    hint: LocaleKeys.authEnterName.tr(),
                    icon: Icons.person_outline_rounded,
                    validator: (value) => value!.isEmpty
                        ? LocaleKeys.errorsRequiredField.tr()
                        : null,
                  ),
                  SizedBox(height: context.h(2.5)),
                  _buildLabel(context, LocaleKeys.authPhone.tr()),
                  SizedBox(height: context.h(1)),
                  _buildTextField(
                    context,
                    controller: phoneController,
                    hint: LocaleKeys.authEnterPhone.tr(),
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value!.isEmpty
                        ? LocaleKeys.errorsRequiredField.tr()
                        : null,
                  ),
                  SizedBox(height: context.h(2.5)),
                  _buildLabel(context, LocaleKeys.contactsType.tr()),
                  SizedBox(height: context.h(1)),
                  _buildTypeDropdown(context, selectedType, (val) {
                    setState(() => selectedType = val!);
                  }),
                ],
              ),
            ),
          ),
          actionsPadding:
              EdgeInsets.fromLTRB(context.w(6), 0, context.w(6), context.h(3)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                LocaleKeys.cancel.tr(),
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: context.sp(14),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  ref.read(medicalContactsNotifierProvider.notifier).addContact(
                        nameController.text,
                        phoneController.text,
                        selectedType,
                      );
                  Navigator.pop(context);
                }
              },
              style: AppStyles.primaryButtonStyle.copyWith(
                minimumSize:
                    WidgetStateProperty.all(Size(context.w(40), context.h(6))),
                shape: WidgetStateProperty.all(RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
              ),
              child: Text(
                LocaleKeys.save.tr(),
                style: TextStyle(
                    fontSize: context.sp(16),
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: context.sp(13),
        fontWeight: FontWeight.w800,
        color: AppColors.primary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField(
    BuildContext context, {
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
          fontSize: context.sp(16),
          color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: AppStyles.inputDecoration(
        hint: hint,
        icon: icon,
      ).copyWith(
        fillColor: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : AppColors.backgroundLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown(
      BuildContext context, String value, Function(String?) onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DropdownButtonFormField<String>(
      value: value,
      items: [
        _buildDropdownItem(context, 'doctor', Icons.medical_services_rounded,
            AppColors.info, LocaleKeys.contactsDoctor.tr()),
        _buildDropdownItem(context, 'pharmacy', Icons.local_pharmacy_rounded,
            AppColors.success, LocaleKeys.contactsPharmacy.tr()),
        _buildDropdownItem(context, 'emergency', Icons.local_hospital_rounded,
            AppColors.error, LocaleKeys.contactsEmergency.tr()),
        _buildDropdownItem(context, 'family', Icons.people_rounded,
            AppColors.warning, LocaleKeys.contactsFamily.tr()),
      ],
      onChanged: onChanged,
      decoration: AppStyles.inputDecoration(
        hint: "",
        icon: Icons.category_outlined,
      ).copyWith(
        fillColor: isDark
            ? AppColors.surfaceDark.withValues(alpha: 0.5)
            : AppColors.backgroundLight,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              BorderSide(color: isDark ? Colors.white12 : Colors.black12),
        ),
      ),
      dropdownColor: isDark ? AppColors.surfaceDark : Colors.white,
      borderRadius: BorderRadius.circular(16),
    );
  }

  DropdownMenuItem<String> _buildDropdownItem(BuildContext context,
      String value, IconData icon, Color color, String label) {
    return DropdownMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: context.sp(20)),
          SizedBox(width: context.w(3)),
          Text(label, style: TextStyle(fontSize: context.sp(14))),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: AppColors.error, size: context.sp(28)),
            SizedBox(width: context.w(3)),
            Text(LocaleKeys.contactsDeleteConfirm.tr(),
                style: TextStyle(
                    fontSize: context.sp(18), fontWeight: FontWeight.w900)),
          ],
        ),
        content: Text(LocaleKeys.contactsDeleteWarning.tr(),
            style: TextStyle(
                fontSize: context.sp(15), color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(LocaleKeys.cancel.tr(),
                style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              minimumSize: Size(context.w(25), context.h(5.5)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              LocaleKeys.delete.tr(),
              style: TextStyle(
                fontSize: context.sp(14),
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      ref.read(medicalContactsNotifierProvider.notifier).deleteContact(id);
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'doctor':
        return Icons.medical_services_rounded;
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;
      case 'emergency':
        return Icons.local_hospital_rounded;
      case 'family':
        return Icons.people_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'doctor':
        return AppColors.info;
      case 'pharmacy':
        return AppColors.success;
      case 'emergency':
        return AppColors.error;
      case 'family':
        return AppColors.warning;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'doctor':
        return LocaleKeys.contactsDoctor.tr();
      case 'pharmacy':
        return LocaleKeys.contactsPharmacy.tr();
      case 'emergency':
        return LocaleKeys.contactsEmergency.tr();
      case 'family':
        return LocaleKeys.contactsFamily.tr();
      default:
        return type;
    }
  }
}
