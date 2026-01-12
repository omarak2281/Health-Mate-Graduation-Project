import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../providers/medications_provider.dart';
import '../widgets/medications_list.dart';
import './add_medication_page.dart';
import './medication_alarm_page.dart';

class MedicationsPage extends ConsumerWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text(LocaleKeys.medicationsMyMedications.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            onPressed: () {
              // Demo Alarm with first medication or mock
              final meds = ref.read(medicationsNotifierProvider).medications;
              if (meds.isNotEmpty) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MedicationAlarmPage(medication: meds.first),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please add a medication first to see demo'),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMedicationPage()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(medicationsNotifierProvider.notifier).loadMedications(),
        child: const SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: MedicationsList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicationPage()),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
