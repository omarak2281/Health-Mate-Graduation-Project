import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../providers/medications_provider.dart';
import '../widgets/medications_list.dart';
import './add_medication_page.dart';
import './medication_alarm_page.dart';
import './medicine_tutorial_step1_page.dart';

import '../../../../core/widgets/expert_app_bar.dart';

class MedicationsPage extends ConsumerStatefulWidget {
  const MedicationsPage({super.key});

  @override
  ConsumerState<MedicationsPage> createState() => _MedicationsPageState();
}

class _MedicationsPageState extends ConsumerState<MedicationsPage> {
  @override
  void initState() {
    super.initState();
    // Check and show tutorial on first visit
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowTutorial();
    });
  }

  Future<void> _checkAndShowTutorial() async {
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);
    final hasSeenTutorial = sharedPrefs.hasSeenMedicineTutorial();

    if (!hasSeenTutorial && mounted) {
      // Mark as seen immediately so it doesn't trigger again if page rebuilds
      await sharedPrefs.setMedicineTutorialCompleted(true);

      // Navigate to tutorial
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const MedicineTutorialStep1Page(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final medsState = ref.watch(medicationsNotifierProvider);
    final hasMedications = medsState.medications.isNotEmpty;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.medicationsMyMedications.tr(),
        actions: [
          if (hasMedications)
            IconButton(
              icon: Icon(Icons.alarm_rounded,
                  size: context.sp(24), color: Colors.white),
              onPressed: () {
                final meds = medsState.medications;
                if (meds.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          MedicationAlarmPage(medication: meds.first),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.backgroundDark : AppColors.pageBackground,
        ),
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
      floatingActionButton: hasMedications
          ? FloatingActionButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddMedicationPage()),
              ),
              elevation: 4,
              backgroundColor: AppColors.expertTeal,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Icon(AppIcons.add,
                  size: context.sp(28), color: AppColors.white),
            )
          : null,
    );
  }
}
