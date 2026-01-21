import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class ExpertAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double height;

  const ExpertAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.height = 50,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: context.sp(18),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Colors.white,
        ),
      ),
      centerTitle: centerTitle,
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: leading,
      actions: actions,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryDark,
              AppColors.primary,
              AppColors.primary.withValues(alpha: 0.9),
            ],
            stops: const [0.0, 0.6, 1.0],
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -20,
                right: -20,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withValues(alpha: 0.04),
                ),
              ),
              Positioned(
                bottom: -context.h(8),
                left: -context.w(5),
                child: CircleAvatar(
                  radius: context.w(20),
                  backgroundColor: Colors.white.withValues(alpha: 0.03),
                ),
              ),
              // Glassmorphism accent line at the bottom
              Positioned(
                bottom: 0,
                left: context.w(20),
                right: context.w(20),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.2),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static double getAppBarHeight(BuildContext context) {
    return 60; // Sleek, minimalist height
  }

  static double getAppBarPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top + getAppBarHeight(context) + 8;
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
