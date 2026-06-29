import 'package:flutter/material.dart';
import '../../../../../core/theme/app_dimensions.dart';
import '../../../../../core/utils/responsive.dart';
import '../../../../../core/models/iot_drawer.dart';
import '../../../../../core/models/medication.dart';
import 'drawer_tile.dart';

class DrawersGrid extends StatelessWidget {
  final List<IoTDrawer> drawers;
  final List<Medication> medications;
  final bool isDark;

  const DrawersGrid({
    super.key,
    required this.drawers,
    required this.medications,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: context.w(4),
        crossAxisSpacing: context.w(4),
        childAspectRatio: AppDimensions.drawerTileAspectRatio,
      ),
      itemCount: drawers.length,
      itemBuilder: (context, index) {
        final drawer = drawers[index];
        final medication = medications.cast<Medication?>().firstWhere(
              (m) => m?.drawerNumber == drawer.drawerNumber,
              orElse: () => null,
            );

        return DrawerTile(
          number: drawer.drawerNumber,
          medication: medication,
          isDark: isDark,
        );
      },
    );
  }
}
