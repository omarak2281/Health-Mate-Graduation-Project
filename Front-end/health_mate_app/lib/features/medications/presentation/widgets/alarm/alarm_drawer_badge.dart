import 'package:flutter/material.dart';

class AlarmDrawerBadge extends StatelessWidget {
  final int drawerNumber;
  final Color glowColor;

  const AlarmDrawerBadge({
    super.key,
    required this.drawerNumber,
    required this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: glowColor.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(30),
        color: glowColor.withValues(alpha: 0.06),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lightbulb_rounded, size: 14, color: glowColor),
          const SizedBox(width: 6),
          Text(
            '#$drawerNumber',
            style: TextStyle(
                color: glowColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
