import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_styles.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/constants/locale_keys.dart';
import '../../../../../core/constants/iot_constants.dart';
import '../../../../../core/models/iot_drawer.dart';
import '../../../../../core/widgets/connectivity_status_widget.dart';
import '../../pages/medication_box_page.dart';

class SmartBoxSelectionSection extends StatelessWidget {
  final bool enableSmartBox;
  final int? selectedDrawer;
  final List<IoTDrawer> drawers;
  final Set<int> assignedDrawerNumbers;
  final Function(bool) onToggleEnabled;
  final Function(int) onDrawerSelected;
  final bool isDark;

  const SmartBoxSelectionSection({
    super.key,
    required this.enableSmartBox,
    required this.selectedDrawer,
    required this.drawers,
    required this.assignedDrawerNumbers,
    required this.onToggleEnabled,
    required this.onDrawerSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header: title + "View More" link + single toggle Switch ──────
        _buildHeader(context),

        // ── Expandable content when smart box is enabled ──────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: enableSmartBox
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Hardware connectivity status pill
                    const ConnectivityStatusWidget(),
                    const SizedBox(height: 12),
                    Text(
                      LocaleKeys.medicationsAssignToDrawer.tr(),
                      style: AppStyles.labelStyle.copyWith(
                        fontSize: context.sp(13),
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                    ),
                    SizedBox(height: context.h(2)),
                    _buildDrawerGrid(context),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  /// Single header row containing the section title, "View More" link,
  /// and the ONE authoritative toggle switch for the smart box feature.
  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          LocaleKeys.medicationsSmartBoxSection.tr(),
          style: AppStyles.headingStyle.copyWith(
            fontSize: context.sp(20),
            color: isDark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // "View more" navigates to the full medication box page
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MedicationBoxPage()),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
            // THE authoritative on/off switch (only one in the whole form)
            Switch(
              value: enableSmartBox,
              onChanged: onToggleEnabled,
              activeThumbColor: AppColors.expertTeal,
              thumbColor: WidgetStateProperty.all(Colors.white),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.expertTeal;
                }
                return isDark ? AppColors.borderDark : AppColors.border;
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDrawerGrid(BuildContext context) {
    return AnimatedOpacity(
      opacity: enableSmartBox ? 1.0 : 0.35,
      duration: const Duration(milliseconds: 250),
      child: IgnorePointer(
        ignoring: !enableSmartBox,
        child: Container(
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
              crossAxisCount: 3,
              mainAxisSpacing: context.w(3),
              crossAxisSpacing: context.w(3),
              childAspectRatio: 1.6,
            ),
            itemCount:
                drawers.isNotEmpty ? drawers.length : IoTConstants.totalDrawers,
            itemBuilder: (context, index) {
              final drawerNum = index + 1;
              final isSelected = selectedDrawer == drawerNum;
              final isAssigned = assignedDrawerNumbers.contains(drawerNum);

              return _DrawerSelectionTile(
                drawerNum: drawerNum,
                isSelected: isSelected,
                isAssigned: isAssigned,
                onTap: () => onDrawerSelected(drawerNum),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DrawerSelectionTile extends StatelessWidget {
  final int drawerNum;
  final bool isSelected;
  final bool isAssigned;
  final VoidCallback onTap;

  const _DrawerSelectionTile({
    required this.drawerNum,
    required this.isSelected,
    required this.isAssigned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isAssigned ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.expertTeal
              : (isAssigned
                  ? AppColors.border.withValues(alpha: 0.2)
                  : Colors.transparent),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.expertTeal
                : (isAssigned
                    ? Colors.transparent
                    : AppColors.border.withValues(alpha: 0.5)),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.expertTeal.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Center(
          child: Text(
            '$drawerNum',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? Colors.white
                  : (isAssigned
                      ? AppColors.textSecondary.withValues(alpha: 0.4)
                      : AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
