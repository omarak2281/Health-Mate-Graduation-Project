import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medications_provider.dart';
import '../../../../core/models/medication.dart';

class EditMedicationPage extends ConsumerStatefulWidget {
  final Medication medication;

  const EditMedicationPage({super.key, required this.medication});

  @override
  ConsumerState<EditMedicationPage> createState() => _EditMedicationPageState();
}

class _EditMedicationPageState extends ConsumerState<EditMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;

  late String? _selectedFormFactor;
  late String _frequency;
  late DateTime _startDate;
  late int? _selectedDrawer;
  late bool _enableLed;
  late bool _enableBuzzer;
  bool _isUploading = false;
  late String? _imageUrl;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication.name);
    _dosageController = TextEditingController(text: widget.medication.dosage);
    _instructionsController =
        TextEditingController(text: widget.medication.instructions);
    _selectedFormFactor = widget.medication.formFactor ?? 'tablet';
    _frequency = widget.medication.frequency;
    _startDate = widget.medication.startDate;
    _selectedDrawer = widget.medication.drawerNumber;
    _enableLed = widget.medication.enableLed;
    _enableBuzzer = widget.medication.enableBuzzer;
    _imageUrl = widget.medication.imageUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final url = await ref
            .read(medicationsNotifierProvider.notifier)
            .uploadMedicationImage(await MultipartFile.fromFile(image.path));
        setState(() => _imageUrl = url);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to upload image'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final updates = {
        'name': _nameController.text,
        'dosage': _dosageController.text,
        'frequency': _frequency,
        'instructions': _instructionsController.text,
        'drawer_number': _selectedDrawer,
        'enable_led': _enableLed,
        'enable_buzzer': _enableBuzzer,
        'image_url': _imageUrl,
        'form_factor': _selectedFormFactor,
        'start_date': _startDate.toIso8601String(),
      };

      await ref
          .read(medicationsNotifierProvider.notifier)
          .updateMedication(widget.medication.id, updates);

      if (mounted &&
          ref.read(medicationsNotifierProvider).errorMessage == null) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocaleKeys.medicationsConfirmed.tr()),
            backgroundColor: AppColors.success,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.close_rounded,
              color: isDark ? AppColors.white : AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          LocaleKeys.edit.tr(),
          style: AppStyles.headingStyle.copyWith(
            fontSize: context.sp(22),
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _handleSave,
            child: Text(
              LocaleKeys.save.tr(),
              style: TextStyle(
                color: AppColors.expertTeal,
                fontWeight: FontWeight.bold,
                fontSize: context.sp(16),
              ),
            ),
          ),
          SizedBox(width: context.w(2)),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
              horizontal: context.w(6), vertical: context.h(2)),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Picker
                Center(
                  child: GestureDetector(
                    onTap: _isUploading ? null : _pickImage,
                    child: Container(
                      width: context.sp(140),
                      height: context.sp(140),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.white.withValues(alpha: 0.05)
                            : AppColors.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark
                              ? AppColors.white.withValues(alpha: 0.1)
                              : AppColors.primary.withValues(alpha: 0.1),
                          width: 2,
                        ),
                        image: _imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_imageUrl!),
                                fit: BoxFit.cover)
                            : null,
                      ),
                      child: _isUploading
                          ? const Center(
                              child: CircularProgressIndicator(
                                  color: AppColors.expertTeal))
                          : _imageUrl == null
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded,
                                        size: context.sp(40),
                                        color: AppColors.expertTeal),
                                    SizedBox(height: context.h(1)),
                                    Text(LocaleKeys.medicationsAddPhoto.tr(),
                                        style: AppStyles.labelStyle.copyWith(
                                            color: AppColors.expertTeal)),
                                  ],
                                )
                              : null,
                    ),
                  ),
                ),
                SizedBox(height: context.h(4)),

                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: AppStyles.inputDecoration(
                      hint: 'Medication Name', icon: Icons.medication),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: context.h(2)),

                // Dosage
                TextFormField(
                  controller: _dosageController,
                  decoration: AppStyles.inputDecoration(
                      hint: 'Dosage (e.g. 50mg)', icon: Icons.scale),
                  validator: (value) => value!.isEmpty ? 'Required' : null,
                ),
                SizedBox(height: context.h(2)),

                // Instructions
                TextFormField(
                  controller: _instructionsController,
                  decoration: AppStyles.inputDecoration(
                      hint: 'Instructions', icon: Icons.description),
                  maxLines: 3,
                ),
                SizedBox(height: context.h(4)),

                // Drawer
                Text(
                  LocaleKeys.medicationsSmartBoxSection.tr(),
                  style: AppStyles.headingStyle.copyWith(fontSize: 20),
                ),
                SizedBox(height: context.h(2)),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: 10,
                  itemBuilder: (context, index) {
                    final num = index + 1;
                    final isSelected = _selectedDrawer == num;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDrawer = num),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.expertTeal
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.expertTeal),
                        ),
                        child: Center(
                          child: Text(
                            '$num',
                            style: TextStyle(
                              color: isSelected
                                  ? AppColors.white
                                  : (isDark
                                      ? AppColors.white
                                      : AppColors.textPrimary),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                SizedBox(height: context.h(4)),

                // Switches for alerts
                SwitchListTile(
                  title: Text(LocaleKeys.medicationsEnableLed.tr()),
                  value: _enableLed,
                  onChanged: (val) => setState(() => _enableLed = val),
                  activeColor: AppColors.expertTeal,
                ),
                SwitchListTile(
                  title: Text(LocaleKeys.medicationsEnableBuzzer.tr()),
                  value: _enableBuzzer,
                  onChanged: (val) => setState(() => _enableBuzzer = val),
                  activeColor: AppColors.expertTeal,
                ),
                SizedBox(height: context.h(4)),

                // Confirm Delete button at the bottom
                ElevatedButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline),
                  label: Text(LocaleKeys.delete.tr()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.delete.tr()),
        content: const Text('Are you sure you want to delete this medication?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(LocaleKeys.cancel.tr())),
          TextButton(
            onPressed: () async {
              await ref
                  .read(medicationsNotifierProvider.notifier)
                  .deleteMedication(widget.medication.id);
              if (mounted) {
                Navigator.pop(context); // Pop dialog
                Navigator.pop(context); // Pop edit page
              }
            },
            child: Text(LocaleKeys.delete.tr(),
                style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
