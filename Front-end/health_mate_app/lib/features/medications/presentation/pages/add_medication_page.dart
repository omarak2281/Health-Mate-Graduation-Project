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
import './medication_box_page.dart';

class AddMedicationPage extends ConsumerStatefulWidget {
  const AddMedicationPage({super.key});

  @override
  ConsumerState<AddMedicationPage> createState() => _AddMedicationPageState();
}

class _AddMedicationPageState extends ConsumerState<AddMedicationPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _instructionsController = TextEditingController();

  String? _selectedFormFactor = 'tablet';
  String _frequency = 'Daily';
  String _interval = '8 hours';
  DateTime _startDate = DateTime.now();
  int? _selectedDrawer;
  bool _enableLed = true;
  bool _enableBuzzer = true;
  final bool _enableNotification = true;
  String? _imageUrl;
  bool _isUploading = false;
  final List<TimeOfDay> _timeSlots = [const TimeOfDay(hour: 8, minute: 0)];
  final List<String> _frequencies = ['Daily', 'Weekly', 'Monthly', 'As Needed'];
  final List<String> _intervals = [
    '4 hours',
    '6 hours',
    '8 hours',
    '12 hours',
    'Once daily'
  ];

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
              content: Text(
                LocaleKeys.medicationsImageUploadError.tr(args: [e.toString()]),
                style: AppStyles.labelStyle.copyWith(color: AppColors.white),
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
      if (_selectedDrawer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleKeys.authRoleSelectionRequired.tr(),
              style: AppStyles.labelStyle.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final timeSlotsStrings = _timeSlots.map((t) {
        final hour = t.hour.toString().padLeft(2, '0');
        final minute = t.minute.toString().padLeft(2, '0');
        return '$hour:$minute';
      }).toList();

      await ref.read(medicationsNotifierProvider.notifier).addMedication(
            name: _nameController.text,
            dosage: _dosageController.text,
            frequency: _frequency,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleKeys.medicationsConfirmed.tr(),
              style: AppStyles.labelStyle.copyWith(color: AppColors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showFrequencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(LocaleKeys.medicationsFrequency.tr(),
                  style: AppStyles.headingStyle.copyWith(fontSize: 20)),
            ),
            ..._frequencies.map((f) => ListTile(
                  title: Text(f),
                  trailing: _frequency == f
                      ? const Icon(Icons.check_circle,
                          color: AppColors.expertTeal)
                      : null,
                  onTap: () {
                    setState(() => _frequency = f);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showIntervalPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.cardDark
              : AppColors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(LocaleKeys.medicationsInterval.tr(),
                  style: AppStyles.headingStyle.copyWith(fontSize: 20)),
            ),
            ..._intervals.map((i) => ListTile(
                  title: Text(i),
                  trailing: _interval == i
                      ? const Icon(Icons.check_circle,
                          color: AppColors.expertTeal)
                      : null,
                  onTap: () {
                    setState(() => _interval = i);
                    Navigator.pop(context);
                  },
                )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _showStartDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.expertTeal,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _startDate = picked);
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
          LocaleKeys.medicationsAddMedication.tr(),
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
                                fit: BoxFit.cover,
                              )
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
                                    Icon(
                                      Icons.add_a_photo_rounded,
                                      size: context.sp(40),
                                      color: AppColors.expertTeal,
                                    ),
                                    SizedBox(height: context.h(1)),
                                    Text(
                                      LocaleKeys.medicationsAddPhoto.tr(),
                                      style: AppStyles.labelStyle.copyWith(
                                          color: AppColors.expertTeal),
                                    ),
                                  ],
                                )
                              : null,
                    ),
                  ),
                ),
                SizedBox(height: context.h(4)),

                // Medication Name Section
                Text(
                  LocaleKeys.medicationsMedicationName.tr().toUpperCase(),
                  style: AppStyles.labelStyle.copyWith(
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark
                        ? AppColors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: context.h(1)),
                TextFormField(
                  controller: _nameController,
                  style: AppStyles.bodyStyle.copyWith(
                    color: isDark ? AppColors.white : AppColors.textPrimary,
                  ),
                  decoration: AppStyles.inputDecoration(
                    hint: 'e.g Lisinopril',
                    icon: Icons.search_rounded,
                  ).copyWith(
                    fillColor: isDark ? AppColors.cardDark : AppColors.white,
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  ),
                  validator: (value) => value!.isEmpty
                      ? LocaleKeys.errorsRequiredField.tr()
                      : null,
                ),
                SizedBox(height: context.h(3)),

                // Form Factor Section
                Text(
                  LocaleKeys.medicationsFormFactor.tr().toUpperCase(),
                  style: AppStyles.labelStyle.copyWith(
                    fontSize: context.sp(12),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: isDark
                        ? AppColors.white.withValues(alpha: 0.6)
                        : AppColors.textSecondary,
                  ),
                ),
                SizedBox(height: context.h(1.5)),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFormFactorOption('tablet', Icons.adjust_rounded,
                          LocaleKeys.medicationsTablet.tr()),
                      _buildFormFactorOption(
                          'capsule',
                          Icons.medication_rounded,
                          LocaleKeys.medicationsCapsule.tr()),
                      _buildFormFactorOption(
                          'injection',
                          Icons.vaccines_rounded,
                          LocaleKeys.medicationsInjection.tr()),
                      _buildFormFactorOption('liquid', Icons.opacity_rounded,
                          LocaleKeys.medicationsLiquid.tr()),
                    ],
                  ),
                ),
                SizedBox(height: context.h(4)),

                // Schedule Section
                Text(
                  LocaleKeys.medicationsSchedule.tr(),
                  style: AppStyles.headingStyle.copyWith(
                    fontSize: context.sp(24),
                    fontWeight: FontWeight.bold,
                    color: isDark ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: context.h(2)),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildScheduleItem(
                        icon: Icons.refresh_rounded,
                        label: LocaleKeys.medicationsFrequency.tr(),
                        value: _frequency,
                        onTap: _showFrequencyPicker,
                      ),
                      Divider(
                          height: 1,
                          indent: 60,
                          color: AppColors.border.withValues(alpha: 0.3)),
                      _buildScheduleItem(
                        icon: Icons.timer_outlined,
                        label: LocaleKeys.medicationsInterval.tr(),
                        value: _interval,
                        onTap: _showIntervalPicker,
                      ),
                      Divider(
                          height: 1,
                          indent: 60,
                          color: AppColors.border.withValues(alpha: 0.3)),
                      _buildScheduleItem(
                        icon: Icons.calendar_today_rounded,
                        label: LocaleKeys.medicationsStartDate.tr(),
                        value: DateFormat('MMM dd, yyyy').format(_startDate),
                        onTap: _showStartDatePicker,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: context.h(4)),

                // Smart Box Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      LocaleKeys.medicationsSmartBoxSection.tr(),
                      style: AppStyles.headingStyle.copyWith(
                        fontSize: context.sp(24),
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const MedicationBoxPage()),
                      ),
                      child: Text(
                        LocaleKeys.medicationsViewMore.tr(),
                        style: TextStyle(
                          color: AppColors.expertTeal,
                          fontWeight: FontWeight.bold,
                          fontSize: context.sp(14),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  LocaleKeys.medicationsAssignToDrawer.tr(),
                  style: AppStyles.labelStyle.copyWith(
                    fontSize: context.sp(13),
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(height: context.h(2)),
                Container(
                  padding: EdgeInsets.all(context.w(4)),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.cardDark : AppColors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.05),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5,
                      mainAxisSpacing: context.w(3),
                      crossAxisSpacing: context.w(3),
                      childAspectRatio: 1,
                    ),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      final drawerNum = index + 1;
                      final isSelected = _selectedDrawer == drawerNum;
                      final medsState = ref.watch(medicationsNotifierProvider);
                      final isAssigned = medsState.medications
                          .any((m) => m.drawerNumber == drawerNum);

                      return GestureDetector(
                        onTap: isAssigned
                            ? null
                            : () => setState(() => _selectedDrawer = drawerNum),
                        child: Container(
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.expertTeal
                                : (isAssigned
                                    ? AppColors.border.withValues(alpha: 0.2)
                                    : Colors.transparent),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.expertTeal
                                  : (isAssigned
                                      ? Colors.transparent
                                      : AppColors.border
                                          .withValues(alpha: 0.5)),
                              width: 1.5,
                            ),
                          ),
                          child: Center(
                            child: isAssigned
                                ? Icon(Icons.lock_outline_rounded,
                                    size: 20,
                                    color: AppColors.textSecondary
                                        .withValues(alpha: 0.3))
                                : Text(
                                    '$drawerNum',
                                    style: TextStyle(
                                      fontSize: context.sp(14),
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.white
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: context.h(4)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormFactorOption(String id, IconData icon, String label) {
    final isSelected = _selectedFormFactor == id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => setState(() => _selectedFormFactor = id),
      child: Container(
        margin: EdgeInsets.only(right: context.w(3)),
        padding: EdgeInsets.symmetric(
            horizontal: context.w(5), vertical: context.h(1.2)),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.expertTeal
              : (isDark
                  ? AppColors.white.withValues(alpha: 0.1)
                  : AppColors.border.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.white : AppColors.textSecondary,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: context.sp(15),
                fontWeight: FontWeight.bold,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: context.w(5), vertical: context.h(2.2)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.expertTeal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.expertTeal, size: 20),
            ),
            SizedBox(width: context.w(4)),
            Text(
              label,
              style: TextStyle(
                fontSize: context.sp(16),
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              value,
              style: TextStyle(
                fontSize: context.sp(15),
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
            ),
            SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.border, size: 20),
          ],
        ),
      ),
    );
  }
}
