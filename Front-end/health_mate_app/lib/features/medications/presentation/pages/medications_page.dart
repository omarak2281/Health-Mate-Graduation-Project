import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import '../../../../core/models/medication.dart';
import '../providers/medications_provider.dart';
import '../widgets/medications_list.dart';
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
    _checkAndShowTutorial();
  }

  void _checkAndShowTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sharedPrefs = ref.read(sharedPrefsCacheProvider);
      final hasSeenTutorial = sharedPrefs.hasSeenMedicineTutorial();

      if (!hasSeenTutorial && mounted) {
        await sharedPrefs.setMedicineTutorialCompleted(true);
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => const MedicineTutorialStep1Page()),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final medsState = ref.watch(medicationsNotifierProvider);
    final hasMedications = medsState.medications.isNotEmpty;
    final backgroundColor =
        isDark ? AppColors.backgroundDark : AppColors.pageBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: ExpertAppBar(
        title: LocaleKeys.medicationsMyMedications.tr(),
        actions: [
          if (hasMedications)
            _DemoAlarmButton(medications: medsState.medications),
        ],
      ),
      body: Container(
        height: double.infinity,
        color: backgroundColor,
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
    );
  }
}

class _DemoAlarmButton extends StatelessWidget {
  final List<Medication> medications;
  const _DemoAlarmButton({required this.medications});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: "Test Alarm UI",
      icon:
          Icon(Icons.alarm_rounded, size: context.sp(24), color: Colors.white),
      onPressed: () {
        if (medications.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  MedicationAlarmPage(medications: [medications.first]),
            ),
          );
        }
      },
    );
  }
}
