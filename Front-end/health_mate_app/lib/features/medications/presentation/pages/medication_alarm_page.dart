import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/constants/locale_keys.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/medication.dart';
import '../../../home/data/iot_repository.dart';

class MedicationAlarmPage extends ConsumerWidget {
  final Medication medication;

  const MedicationAlarmPage({super.key, required this.medication});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              // Header
              Text(
                LocaleKeys.medicationsAlarmTitle.tr().toUpperCase(),
                style: const TextStyle(
                  color: AppColors.white70,
                  fontSize: 16,
                  letterSpacing: 2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                DateFormat('HH:mm').format(DateTime.now()),
                style: const TextStyle(
                  color: AppColors.white,
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                ),
              ),
              const SizedBox(height: 40),

              // Medicine Image/Icon
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withValues(alpha: 0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: medication.imageUrl != null
                        ? Image.network(
                            medication.imageUrl!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Center(
                            child: Icon(
                              Icons.medication,
                              size: 100,
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Details
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  children: [
                    Text(
                      medication.name,
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${medication.dosage} • ${medication.frequency}',
                      style: const TextStyle(
                        color: AppColors.white70,
                        fontSize: 18,
                      ),
                    ),
                    if (medication.hasDrawer()) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white24,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: AppColors.drawerIcon,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${LocaleKeys.medicationsDrawer.tr()} ${medication.drawerNumber}',
                              style: const TextStyle(
                                color: AppColors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 60),

              // Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Row(
                  children: [
                    // Snooze
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Handle Snooze logic (placeholder)
                          Navigator.pop(context);
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.white),
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          LocaleKeys.medicationsSnooze.tr(),
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Take Now
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Deactivate IoT Drawer
                          if (medication.hasDrawer()) {
                            await ref
                                .read(iotRepositoryProvider)
                                .deactivateDrawer(medication.drawerNumber!);
                          }
                          // Mark as taken (placeholder logic)
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  LocaleKeys.medicationsConfirmed.tr(),
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: Text(
                          LocaleKeys.medicationsTakeNow.tr(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
