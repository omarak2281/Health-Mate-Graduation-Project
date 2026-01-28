import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/storage/shared_prefs_cache.dart';
import 'medicine_tutorial_step1_page.dart';

/// Medicine Tutorial Wrapper
/// Checks if user has seen the tutorial before and navigates accordingly
class MedicineTutorialPage extends ConsumerStatefulWidget {
  const MedicineTutorialPage({super.key});

  @override
  ConsumerState<MedicineTutorialPage> createState() =>
      _MedicineTutorialPageState();
}

class _MedicineTutorialPageState extends ConsumerState<MedicineTutorialPage> {
  @override
  void initState() {
    super.initState();
    _checkFirstTime();
  }

  Future<void> _checkFirstTime() async {
    final sharedPrefs = ref.read(sharedPrefsCacheProvider);
    final hasSeenTutorial = sharedPrefs.hasSeenMedicineTutorial();

    if (!hasSeenTutorial) {
      // Show tutorial - navigate to step 1
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MedicineTutorialStep1Page()),
        );
      }
    } else {
      // Skip tutorial - navigate to medications page
      // TODO: Replace with actual medications page navigation
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Center(
        child: CircularProgressIndicator(
          color: AppColors.primaryLight,
        ),
      ),
    );
  }
}
