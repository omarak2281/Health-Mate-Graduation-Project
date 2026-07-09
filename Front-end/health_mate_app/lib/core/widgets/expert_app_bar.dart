import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../utils/responsive.dart';

class ExpertAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final double height;
  final bool automaticallyImplyLeading;
  final VoidCallback? onBackTap;

  const ExpertAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
    this.height = 60,
    this.automaticallyImplyLeading = false,
    this.onBackTap,
  });

  @override
  Widget build(BuildContext context) {
    // `onBackTap` used to be accepted but never actually rendered anywhere,
    // so pages passing it (expecting a tappable back arrow) silently got
    // none. Render it explicitly here, unless an explicit `leading` widget
    // was already supplied.
    final effectiveLeading = leading ??
        (onBackTap != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: onBackTap,
              )
            : null);

    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: context.sp(18),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: Colors.white,
          shadows: [
            Shadow(
              color: Colors.black.withValues(alpha: 0.1),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
      ),
      centerTitle: centerTitle,
      elevation: 0,
      backgroundColor: Colors.transparent,
      automaticallyImplyLeading: automaticallyImplyLeading,
      leading: effectiveLeading,
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
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -15,
                right: -15,
                child: CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.white.withValues(alpha: 0.05),
                ),
              ),
              Positioned(
                bottom: -20,
                left: -10,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.white.withValues(alpha: 0.03),
                ),
              ),
              // Glassmorphism accent line at the bottom
              Positioned(
                bottom: 0,
                left: context.w(15),
                right: context.w(15),
                child: Container(
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.0),
                        Colors.white.withValues(alpha: 0.25),
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
    return 60;
  }

  static double getAppBarPadding(BuildContext context) {
    return MediaQuery.of(context).padding.top + getAppBarHeight(context) + 12;
  }

  @override
  Size get preferredSize => Size.fromHeight(height);
}
