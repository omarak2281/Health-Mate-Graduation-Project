import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/medications_provider.dart';

/// Medications List Widget
/// Shows active medications with details

class MedicationsList extends ConsumerWidget {
  final bool compact;
  final String? patientId;

  const MedicationsList({super.key, this.compact = false, this.patientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medsState = patientId != null
        ? ref.watch(patientMedicationsNotifierProvider(patientId!))
        : ref.watch(medicationsNotifierProvider);

    if (medsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (medsState.medications.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.medication_outlined,
                size: 48,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                LocaleKeys.medicationsNoMedications.tr(),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (!compact && patientId == null) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddMedicationDialog(context, ref);
                  },
                  icon: const Icon(Icons.add),
                  label: Text(LocaleKeys.medicationsAddMedication.tr()),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final medications = compact
        ? medsState.activeMedications.take(3).toList()
        : medsState.activeMedications;

    return Column(
      children: [
        if (!compact)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  LocaleKeys.medicationsMyMedications.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (patientId == null)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      _showAddMedicationDialog(context, ref);
                    },
                  ),
              ],
            ),
          ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: medications.length,
          itemBuilder: (context, index) {
            final medication = medications[index];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.medication, color: AppColors.primary),
                ),
                title: Text(
                  medication.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${LocaleKeys.medicationsDosage.tr()}: ${medication.dosage}',
                    ),
                    Text(
                      '${LocaleKeys.medicationsFrequency.tr()}: ${medication.frequency}',
                    ),
                    if (medication.hasDrawer())
                      Text(
                        '${LocaleKeys.medicationsDrawer.tr()} ${medication.drawerNumber}',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
                trailing: medication.enableNotification
                    ? Icon(Icons.notifications_active, color: AppColors.success)
                    : null,
                onTap: () {
                  _showMedicationDetails(context, medication);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  void _showAddMedicationDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final frequencyController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LocaleKeys.medicationsAddMedication.tr()),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.medicationsMedicationName.tr(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dosageController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.medicationsDosage.tr(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: frequencyController,
                decoration: InputDecoration(
                  labelText: LocaleKeys.medicationsFrequency.tr(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.cancel.tr()),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty &&
                  dosageController.text.isNotEmpty &&
                  frequencyController.text.isNotEmpty) {
                await ref
                    .read(medicationsNotifierProvider.notifier)
                    .addMedication(
                      name: nameController.text,
                      dosage: dosageController.text,
                      frequency: frequencyController.text,
                      timeSlots: ['08:00', '20:00'], // Default
                    );
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: Text(LocaleKeys.save.tr()),
          ),
        ],
      ),
    );
  }

  void _showMedicationDetails(BuildContext context, medication) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medication.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow(LocaleKeys.medicationsDosage.tr(), medication.dosage),
            _detailRow(
              LocaleKeys.medicationsFrequency.tr(),
              medication.frequency,
            ),
            if (medication.instructions != null)
              _detailRow(
                LocaleKeys.medicationsInstructions.tr(),
                medication.instructions!,
              ),
            if (medication.hasDrawer())
              _detailRow(
                LocaleKeys.medicationsDrawer.tr(),
                medication.drawerNumber.toString(),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(LocaleKeys.close.tr()),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
