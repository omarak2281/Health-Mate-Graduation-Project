import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/constants.dart';
import '../../../../core/utils/responsive.dart';
import '../../../../core/widgets/expert_app_bar.dart';
import '../../../linking/presentation/providers/linking_provider.dart';
import '../widgets/linked_user_card.dart';

/// Dedicated read-only list of the patient's linked caregivers, opened from
/// Settings → "manage linked caregivers". Reuses the same card design pinned
/// in [MedicalContactsPage]'s "Linked caregivers" section, instead of sending
/// the patient to the full Medical Contacts page.
class LinkedCaregiversPage extends ConsumerWidget {
  const LinkedCaregiversPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkingState = ref.watch(linkingNotifierProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.pageBackground,
      appBar: ExpertAppBar(
        title: LocaleKeys.contactsLinkedCaregivers.tr(),
        onBackTap: () => Navigator.of(context).pop(),
      ),
      body: linkingState.isLoading && linkingState.linkedUsers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(linkingNotifierProvider.notifier).getLinkedUsers(),
              child: linkingState.linkedUsers.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: EdgeInsets.symmetric(
                        horizontal: context.w(4),
                        vertical: context.h(2),
                      ),
                      children: linkingState.linkedUsers
                          .map((user) => LinkedUserCard(user: user))
                          .toList(),
                    ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(
        horizontal: context.w(8),
        vertical: context.h(10),
      ),
      children: [
        Icon(
          Icons.people_outline_rounded,
          size: context.sp(80),
          color: AppColors.primary.withValues(alpha: 0.5),
        ),
        SizedBox(height: context.h(3)),
        Text(
          LocaleKeys.contactsNoLinkedCaregivers.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(20),
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
          ),
        ),
        SizedBox(height: context.h(1.5)),
        Text(
          LocaleKeys.contactsNoLinkedCaregiversDesc.tr(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: context.sp(14),
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
