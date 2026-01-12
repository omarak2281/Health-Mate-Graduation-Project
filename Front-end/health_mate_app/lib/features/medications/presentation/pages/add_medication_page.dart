import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/medications_provider.dart';

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

      await ref
          .read(medicationsNotifierProvider.notifier)
          .addMedication(
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
      appBar: AppBar(title: Text(LocaleKeys.medicationsAddMedication.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
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
                    width: 120,
                    height: 120,
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
                        ? const Center(child: CircularProgressIndicator())
                        : _imageUrl == null
                        ? const Icon(
                            Icons.add_a_photo,
                            size: 40,
                            color: AppColors.primary,
                          )
                        : null,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.medicationsMedicationName.tr(),
                  prefixIcon: const Icon(Icons.medication),
                ),
                validator: (value) =>
                    value!.isEmpty ? LocaleKeys.errorsRequiredField.tr() : null,
              ),
              const SizedBox(height: 16),

              // Dosage & Frequency
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _dosageController,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.medicationsDosage.tr(),
                        prefixIcon: const Icon(Icons.shutter_speed),
                      ),
                      validator: (value) => value!.isEmpty
                          ? LocaleKeys.errorsRequiredField.tr()
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _frequencyController,
                      decoration: InputDecoration(
                        labelText: LocaleKeys.medicationsFrequency.tr(),
                        prefixIcon: const Icon(Icons.repeat),
                      ),
                      validator: (value) => value!.isEmpty
                          ? LocaleKeys.errorsRequiredField.tr()
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Instructions
              TextFormField(
                controller: _instructionsController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: LocaleKeys.medicationsInstructions.tr(),
                  prefixIcon: const Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 24),

              // Time Slots
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocaleKeys.medicationsTimeSlots.tr(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.add_circle,
                      color: AppColors.primary,
                    ),
                    onPressed: _addTimeSlot,
                  ),
                ],
              ),
              ..._timeSlots.asMap().entries.map((entry) {
                final index = entry.key;
                final time = entry.value;
                return ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(time.format(context)),
                  trailing: _timeSlots.length > 1
                      ? IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () =>
                              setState(() => _timeSlots.removeAt(index)),
                        )
                      : null,
                  onTap: () => _pickTime(index),
                );
              }),
              const SizedBox(height: 24),

              // Smart Box Settings
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            LocaleKeys.vitalsSmartMedicineBox.tr(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        initialValue: _selectedDrawer,
                        decoration: InputDecoration(
                          labelText: LocaleKeys.medicationsDrawer.tr(),
                        ),
                        items: List.generate(
                          6,
                          (index) => DropdownMenuItem(
                            value: index + 1,
                            child: Text(
                              '${LocaleKeys.medicationsDrawer.tr()} ${index + 1}',
                            ),
                          ),
                        ),
                        onChanged: (value) =>
                            setState(() => _selectedDrawer = value),
                      ),
                      SwitchListTile(
                        title: Text(LocaleKeys.medicationsEnableLed.tr()),
                        value: _enableLed,
                        onChanged: (v) => setState(() => _enableLed = v),
                      ),
                      SwitchListTile(
                        title: Text(LocaleKeys.medicationsEnableBuzzer.tr()),
                        value: _enableBuzzer,
                        onChanged: (v) => setState(() => _enableBuzzer = v),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Save Button
              ElevatedButton(
                onPressed: _handleSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  LocaleKeys.save.tr(),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
