import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_styles.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/medications_provider.dart';
import '../../../../core/models/medication.dart';
import '../../../home/presentation/providers/iot_provider.dart';
import '../widgets/medicine_box/smart_box_selection_section.dart';

class MedicineFormPage extends ConsumerStatefulWidget {
  final Medication? medication;
  final String? patientId;

  const MedicineFormPage({
    super.key,
    this.medication,
    this.patientId,
  });

  @override
  ConsumerState<MedicineFormPage> createState() => _MedicineFormPageState();
}

class _MedicineFormPageState extends ConsumerState<MedicineFormPage> {
  final _formKey = GlobalKey<FormState>();
  bool get _isEditMode => widget.medication != null;

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _doseController;
  late TextEditingController _instructionsController;

  // State
  int _timesPerDay = 1;
  late List<TimeOfDay> _scheduledTimes;
  int? _selectedDrawer;
  bool _useSmartBox = false;
  String? _imageUrl;
  bool _isUploading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.medication?.name);
    _doseController = TextEditingController(text: widget.medication?.dosage);
    _instructionsController =
        TextEditingController(text: widget.medication?.instructions);

    if (_isEditMode) {
      _timesPerDay = widget.medication!.timesPerDay;
      _scheduledTimes = widget.medication!.scheduledTimes.map((t) {
        final parts = t.split(':');
        return TimeOfDay(
            hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }).toList();
      _useSmartBox = widget.medication!.useSmartBox;
      _selectedDrawer = widget.medication!.drawerNumber;
      _imageUrl = widget.medication!.imageUrl;
    } else {
      _scheduledTimes = [const TimeOfDay(hour: 8, minute: 0)];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doseController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _updateTimesPerDay(int count) {
    setState(() {
      _timesPerDay = count;
      if (_scheduledTimes.length < count) {
        // Add new slots if needed, defaulting to later times
        for (int i = _scheduledTimes.length; i < count; i++) {
          final lastHour = _scheduledTimes.last.hour;
          _scheduledTimes.add(TimeOfDay(hour: (lastHour + 4) % 24, minute: 0));
        }
      } else if (_scheduledTimes.length > count) {
        // Remove extra slots
        _scheduledTimes = _scheduledTimes.sublist(0, count);
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _isUploading = true);
      try {
        final notifier = widget.patientId != null
            ? ref.read(
                patientMedicationsNotifierProvider(widget.patientId!).notifier)
            : ref.read(medicationsNotifierProvider.notifier);

        final url = await notifier
            .uploadMedicationImage(await MultipartFile.fromFile(image.path));
        setState(() => _imageUrl = url);
      } catch (e) {
        _showError(
            LocaleKeys.medicationsImageUploadError.tr(args: [e.toString()]));
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    if (_useSmartBox && _selectedDrawer == null) {
      _showError(LocaleKeys.medicationsSelectDrawerRequired.tr());
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = widget.patientId != null
          ? ref.read(
              patientMedicationsNotifierProvider(widget.patientId!).notifier)
          : ref.read(medicationsNotifierProvider.notifier);

      final scheduledTimesStrings = _scheduledTimes
          .map((t) =>
              '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
          .toList();

      if (_isEditMode) {
        await notifier.updateMedication(widget.medication!.id, {
          'name': _nameController.text,
          'dosage': _doseController.text,
          'instructions': _instructionsController.text,
          'times_per_day': _timesPerDay,
          'scheduled_times': scheduledTimesStrings,
          'use_smart_box': _useSmartBox,
          'drawer_number': _selectedDrawer,
          'image_url': _imageUrl,
        });
      } else {
        await notifier.addMedication(
          name: _nameController.text,
          dosage: _doseController.text,
          timesPerDay: _timesPerDay,
          scheduledTimes: scheduledTimesStrings,
          instructions: _instructionsController.text,
          useSmartBox: _useSmartBox,
          drawerNumber: _selectedDrawer,
          imageUrl: _imageUrl,
          patientId: widget.patientId,
        );
      }

      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iotState = ref.watch(iotNotifierProvider);
    final medsState = widget.patientId != null
        ? ref.watch(patientMedicationsNotifierProvider(widget.patientId!))
        : ref.watch(medicationsNotifierProvider);
    final fieldTextStyle = AppStyles.bodyStyle.copyWith(
      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
    );

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: AppBar(
        title: Text(_isEditMode
            ? LocaleKeys.edit.tr()
            : LocaleKeys.medicationsAddMedication.tr()),
        actions: [
          if (_isSaving)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child:
                        CircularProgressIndicator(color: AppColors.expertTeal)))
          else
            TextButton(
              onPressed: _handleSave,
              child: Text(LocaleKeys.save.tr(),
                  style: const TextStyle(
                      color: AppColors.expertTeal,
                      fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(6)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Image Picker (first)
              _buildImagePicker(isDark),
              SizedBox(height: context.h(3)),

              // 2. Name
              _buildLabel(LocaleKeys.medicationsMedicationName.tr(), isDark),
              TextFormField(
                controller: _nameController,
                style: fieldTextStyle,
                cursorColor: AppColors.expertTeal,
                decoration: AppStyles.inputDecoration(
                    context: context,
                    hint: LocaleKeys.medicationsMedicationNameHint.tr(),
                    icon: Icons.medication),
                validator: (v) => v == null || v.isEmpty
                    ? LocaleKeys.errorsFieldRequired.tr()
                    : null,
              ),
              SizedBox(height: context.h(3)),

              // 3. Instructions
              _buildLabel(LocaleKeys.medicationsInstructions.tr(), isDark),
              TextFormField(
                controller: _instructionsController,
                style: fieldTextStyle,
                cursorColor: AppColors.expertTeal,
                maxLines: 3,
                decoration: AppStyles.inputDecoration(
                    context: context,
                    hint: LocaleKeys.medicationsInstructionsHint.tr(),
                    icon: Icons.description),
              ),
              SizedBox(height: context.h(3)),

              // 4. Dose
              _buildLabel(LocaleKeys.medicationsDosage.tr(), isDark),
              TextFormField(
                controller: _doseController,
                style: fieldTextStyle,
                cursorColor: AppColors.expertTeal,
                decoration: AppStyles.inputDecoration(
                    context: context,
                    hint: LocaleKeys.medicationsDosageHint.tr(),
                    icon: Icons.monitor_weight),
                validator: (v) => v == null || v.isEmpty
                    ? LocaleKeys.errorsFieldRequired.tr()
                    : null,
              ),
              SizedBox(height: context.h(3)),

              // 5. Times per day
              _buildLabel(LocaleKeys.medicationsFrequency.tr(), isDark),
              DropdownButtonFormField<int>(
                initialValue: _timesPerDay,
                dropdownColor: isDark ? AppColors.surfaceDark : AppColors.white,
                style: fieldTextStyle,
                iconEnabledColor: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                items: List.generate(3, (i) => i + 1)
                    .map((val) => DropdownMenuItem(
                        value: val,
                        child: Text(LocaleKeys.medicationsTimesDaily.plural(val,
                            namedArgs: {'count': val.toString()}))))
                    .toList(),
                onChanged: (val) => _updateTimesPerDay(val ?? 1),
                decoration: AppStyles.inputDecoration(
                    context: context,
                    hint: LocaleKeys.medicationsFrequency.tr(),
                    icon: Icons.repeat),
              ),
              SizedBox(height: context.h(3)),

              // 6. Time Pickers
              _buildLabel(LocaleKeys.medicationsTimeSlots.tr(), isDark),
              ...List.generate(
                  _timesPerDay, (index) => _buildTimePicker(index, isDark)),
              SizedBox(height: context.h(3)),

              // 7. Smart Box Section
              _buildSmartBoxSection(context, iotState, medsState, isDark),
              SizedBox(height: context.h(4)),

              // 8. Bottom Save Button
              _buildSaveButton(context, isDark),
              SizedBox(height: context.h(4)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: AppStyles.labelStyle.copyWith(
              color: isDark ? AppColors.white70 : AppColors.textSecondary)),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Center(
      child: GestureDetector(
        onTap: _isUploading ? null : _pickImage,
        child: Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.white.withValues(alpha: 0.05)
                : AppColors.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: AppColors.expertTeal.withValues(alpha: 0.3), width: 2),
          ),
          child: _imageUrl != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(_imageUrl!, fit: BoxFit.cover))
              : _isUploading
                  ? const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.expertTeal))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_a_photo,
                            color: AppColors.expertTeal, size: 30),
                        const SizedBox(height: 8),
                        Text(LocaleKeys.medicationsAddPhoto.tr(),
                            style: const TextStyle(
                                color: AppColors.expertTeal, fontSize: 12)),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildTimePicker(int index, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () async {
          final picked = await showTimePicker(
              context: context, initialTime: _scheduledTimes[index]);
          if (picked != null) setState(() => _scheduledTimes[index] = picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isDark ? AppColors.borderDark : AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time, color: AppColors.expertTeal),
              const SizedBox(width: 12),
              Text(
                '${LocaleKeys.medicationsDoseNumber.tr(namedArgs: {
                      'num': (index + 1).toString()
                    })}: ${_scheduledTimes[index].format(context)}',
                style: AppStyles.bodyStyle.copyWith(
                    color: isDark ? AppColors.white : AppColors.textPrimary),
              ),
              const Spacer(),
              const Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartBoxSection(BuildContext context, IoTState iotState,
      MedicationsState medsState, bool isDark) {
    return SmartBoxSelectionSection(
      enableSmartBox: _useSmartBox,
      selectedDrawer: _selectedDrawer,
      drawers: iotState.drawers,
      assignedDrawerNumbers: medsState.assignedDrawerNumbers,
      onToggleEnabled: (val) => setState(() {
        _useSmartBox = val;
        if (!val) _selectedDrawer = null;
      }),
      onDrawerSelected: (drawerNum) =>
          setState(() => _selectedDrawer = drawerNum),
      isDark: isDark,
    );
  }

  Widget _buildSaveButton(BuildContext context, bool isDark) {
    return SizedBox(
      height: 56,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _handleSave,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Icon(Icons.check_rounded, color: Colors.white),
        label: Text(
          _isSaving
              ? LocaleKeys.loading.tr()
              : (_isEditMode
                  ? LocaleKeys.save.tr()
                  : LocaleKeys.medicationsAddMedication.tr()),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.expertTeal,
          disabledBackgroundColor: AppColors.expertTeal.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
          shadowColor: AppColors.expertTeal.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
