import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medications_provider.dart';
import '../../../../core/widgets/expert_app_bar.dart';

class AddMedicationPage extends ConsumerStatefulWidget {
  const AddMedicationPage({super.key});

  @override
  ConsumerState<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends ConsumerState<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _frequencyController = TextEditingController();
  final _instructionsController = TextEditingController();
  int? _selectedDrawer;
  bool _enableLed = true;
  bool _enableBuzzer = true;
  final bool _enableNotification = true;
  String? _imageUrl;
  bool _isUploading = false;
  final List<TimeOfDay> _timeSlots = [const TimeOfDay(hour: 8, minute: 0)];

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _frequencyController.dispose();
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
              content: Text(
                LocaleKeys.medicationsImageUploadError.tr(args: [e.toString()]),
                style: TextStyle(fontSize: context.sp(14)),
              ),
            ),
          );
        }
      } finally {
        setState(() => _isUploading = false);
      }
    }
  }

  Future<void> _pickTime(int index) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _timeSlots[index],
    );
    if (pickedTime != null) {
      setState(() {
        _timeSlots[index] = pickedTime;
      });
    }
  }

  void _addTimeSlot() {
    setState(() {
      _timeSlots.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  Future<void> _handleSave() async {
    if (_formKey.currentState!.validate()) {
      final timeSlotsStrings = _timeSlots.map((t) {
        final hour = t.hour.toString().padLeft(2, '0');
        final minute = t.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }).toList();

      await ref.read(medicationsNotifierProvider.notifier).addMedication(
            name: _nameController.text,
            dosage: _dosageController.text,
            frequency: _frequencyController.text,
            timeSlots: timeSlotsStrings,
            instructions: _instructionsController.text,
            drawerNumber: _selectedDrawer,
            enableLed: _enableLed,
            enableBuzzer: _enableBuzzer,
            enableNotification: _enableNotification,
            imageUrl: _imageUrl,
          );

      if (mounted &&
          ref.read(medicationsNotifierProvider).errorMessage == null) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.medicationsAddMedication.tr(),
      ),
      body: Container(
        height: double.infinity,
        padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(context.w(6)),
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
                      width: context.sp(120),
                      height: context.sp(120),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(15),
                        image: _imageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(_imageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _isUploading
                          ? Center(
                              child: SizedBox(
                                width: context.sp(30),
                                height: context.sp(30),
                                child: const CircularProgressIndicator(),
                              ),
                            )
                          : _imageUrl == null
                              ? Icon(
                                  Icons.add_a_photo,
                                  size: context.sp(40),
                                  color: AppColors.primary,
                                )
                              : null,
                    ),
                  ),
                ),
                SizedBox(height: context.h(3)),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.medicationsMedicationName.tr(),
                    prefixIcon: Icon(AppIcons.medication, size: context.sp(22)),
                    labelStyle: TextStyle(fontSize: context.sp(16)),
                    errorStyle: TextStyle(fontSize: context.sp(12)),
                  ),
                  style: TextStyle(fontSize: context.sp(16)),
                  validator: (value) => value!.isEmpty
                      ? LocaleKeys.errorsRequiredField.tr()
                      : null,
                ),
                SizedBox(height: context.h(2)),

                // Dosage & Frequency
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dosageController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.medicationsDosage.tr(),
                          prefixIcon:
                              Icon(AppIcons.dosage, size: context.sp(22)),
                          labelStyle: TextStyle(fontSize: context.sp(16)),
                          errorStyle: TextStyle(fontSize: context.sp(12)),
                        ),
                        style: TextStyle(fontSize: context.sp(16)),
                        validator: (value) => value!.isEmpty
                            ? LocaleKeys.errorsRequiredField.tr()
                            : null,
                      ),
                    ),
                    SizedBox(width: context.w(3)),
                    Expanded(
                      child: TextFormField(
                        controller: _frequencyController,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.medicationsFrequency.tr(),
                          prefixIcon:
                              Icon(AppIcons.repeat, size: context.sp(22)),
                          labelStyle: TextStyle(fontSize: context.sp(16)),
                          errorStyle: TextStyle(fontSize: context.sp(12)),
                        ),
                        style: TextStyle(fontSize: context.sp(16)),
                        validator: (value) => value!.isEmpty
                            ? LocaleKeys.errorsRequiredField.tr()
                            : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.h(2)),

                // Instructions
                TextFormField(
                  controller: _instructionsController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: LocaleKeys.medicationsInstructions.tr(),
                    prefixIcon:
                        Icon(AppIcons.description, size: context.sp(22)),
                    labelStyle: TextStyle(fontSize: context.sp(16)),
                    contentPadding: EdgeInsets.all(context.w(3)),
                  ),
                  style: TextStyle(fontSize: context.sp(16)),
                ),
                SizedBox(height: context.h(3)),

                // Time Slots
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocaleKeys.medicationsTimeSlots.tr(),
                      style: TextStyle(
                          fontSize: context.sp(18),
                          fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.add_circle,
                        color: AppColors.primary,
                        size: context.sp(28),
                      ),
                      onPressed: _addTimeSlot,
                    ),
                  ],
                ),
                ..._timeSlots.asMap().entries.map((entry) {
                  final index = entry.key;
                  final time = entry.value;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(AppIcons.time, size: context.sp(24)),
                    title: Text(time.format(context),
                        style: TextStyle(fontSize: context.sp(16))),
                    trailing: _timeSlots.length > 1
                        ? IconButton(
                            icon: Icon(Icons.remove_circle_outline,
                                size: context.sp(24)),
                            onPressed: () =>
                                setState(() => _timeSlots.removeAt(index)),
                          )
                        : null,
                    onTap: () => _pickTime(index),
                  );
                }),
                SizedBox(height: context.h(3)),

                // Smart Box Settings
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: EdgeInsets.all(context.w(4)),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              AppIcons.smartBox,
                              color: AppColors.primary,
                              size: context.sp(22),
                            ),
                            SizedBox(width: context.w(2)),
                            Text(
                              LocaleKeys.vitalsSmartMedicineBox.tr(),
                              style: TextStyle(
                                  fontSize: context.sp(16),
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        SizedBox(height: context.h(2)),
                        DropdownButtonFormField<int>(
                          value: _selectedDrawer,
                          decoration: InputDecoration(
                            labelText: LocaleKeys.medicationsDrawer.tr(),
                            labelStyle: TextStyle(fontSize: context.sp(16)),
                          ),
                          items: List.generate(
                            10,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(
                                '${LocaleKeys.medicationsDrawer.tr()} ${index + 1}',
                                style: TextStyle(fontSize: context.sp(14)),
                              ),
                            ),
                          ),
                          onChanged: (value) =>
                              setState(() => _selectedDrawer = value),
                        ),
                        SwitchListTile(
                          title: Text(LocaleKeys.medicationsEnableLed.tr(),
                              style: TextStyle(fontSize: context.sp(14))),
                          value: _enableLed,
                          onChanged: (v) => setState(() => _enableLed = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: Text(LocaleKeys.medicationsEnableBuzzer.tr(),
                              style: TextStyle(fontSize: context.sp(14))),
                          value: _enableBuzzer,
                          onChanged: (v) => setState(() => _enableBuzzer = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: context.h(4)),

                // Save Button
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: context.h(2)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    LocaleKeys.save.tr(),
                    style: TextStyle(
                        fontSize: context.sp(18), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
