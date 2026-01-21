import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../providers/medications_provider.dart';
import '../widgets/medications_list.dart';
import './add_medication_page.dart';
import './medication_alarm_page.dart';

import '../../../../core/widgets/expert_app_bar.dart';

class MedicationsPage extends ConsumerWidget {
  const MedicationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.medicationsMyMedications.tr(),
        actions: [
          IconButton(
            icon: Icon(Icons.alarm, size: context.sp(24), color: Colors.white),
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
                  SnackBar(
                    content: Text(LocaleKeys.medicationsDemoAdd.tr(),
                        style: TextStyle(fontSize: context.sp(14))),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: Icon(AppIcons.add, size: context.sp(24), color: Colors.white),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddMedicationPage()),
            ),
          ),
        ],
      ),
      body: Container(
        height: double.infinity,
        padding: EdgeInsets.only(top: ExpertAppBar.getAppBarPadding(context)),
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(medicationsNotifierProvider.notifier).loadMedications(),
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: MedicationsList(),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AddMedicationPage()),
        ),
        child: Icon(AppIcons.add, size: context.sp(28)),
      ),
    );
  }
}
