import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'app_constants.dart';

class AppIcons {
  AppIcons._();

  static Widget svgIcon(String assetPath,
      {double? size, Color? color, Key? key, bool matchTextDirection = true}) {
    final double iconSize = size ?? 24;
    return SizedBox(
      key: key,
      width: iconSize,
      height: iconSize,
      child: Center(
        child: SvgPicture.asset(
          assetPath,
          width: iconSize,
          height: iconSize,
          matchTextDirection: matchTextDirection,
          colorFilter:
              color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
        ),
      ),
    );
  }

  static Widget home({double? size, Color? color}) =>
      svgIcon(AssetsConstants.home, size: size, color: color);
  static Widget bloodPressure({double? size, Color? color}) =>
      svgIcon(AssetsConstants.bloodPressure, size: size, color: color);
  static Widget heartRate({double? size, Color? color}) =>
      svgIcon(AssetsConstants.heartRate, size: size, color: color);
  static Widget pill({double? size, Color? color}) =>
      svgIcon(AssetsConstants.pill, size: size, color: color);
  static Widget settings({double? size, Color? color}) =>
      svgIcon(AssetsConstants.settings, size: size, color: color);
  static Widget logout({double? size, Color? color}) =>
      svgIcon(AssetsConstants.logout, size: size, color: color);
  static Widget language({double? size, Color? color}) =>
      svgIcon(AssetsConstants.language, size: size, color: color);
  static Widget phone({double? size, Color? color}) =>
      svgIcon(AssetsConstants.phone,
          size: size, color: color, matchTextDirection: false);
  static Widget doctor({double? size, Color? color}) =>
      svgIcon(AssetsConstants.doctor,
          size: size, color: color, matchTextDirection: false);
  static Widget check({double? size, Color? color}) =>
      svgIcon(AssetsConstants.check, size: size, color: color);
  static Widget splashLogo({double? size, Color? color, Key? key}) =>
      svgIcon(AssetsConstants.splashLogo,
          size: size ?? 120, color: color, key: key, matchTextDirection: false);

  static Widget email({double? size, Color? color}) =>
      svgIcon(AssetsConstants.email,
          size: size, color: color, matchTextDirection: false);
  static Widget password({double? size, Color? color}) =>
      svgIcon(AssetsConstants.password,
          size: size, color: color, matchTextDirection: false);

  static Widget ukFlag({double size = 40}) => _buildPremiumFlag(
        AssetsConstants.ukFlagUrl,
        size: size,
      );

  static Widget egyptFlag({double size = 40}) => _buildPremiumFlag(
        AssetsConstants.egyptFlagUrl,
        size: size,
      );

  static Widget _buildPremiumFlag(String url, {double size = 40}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          // The Flag Image
          ClipOval(
            child: Image.network(
              url,
              width: size,
              height: size,
              fit: BoxFit.cover,
            ),
          ),
          // Glossy Shine Effect
          ClipOval(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(alpha: 0.45),
                    Colors.white.withValues(alpha: 0.1),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.05),
                  ],
                  stops: const [0.0, 0.3, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Subtle Inner Highlight for glass effect
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.25),
                width: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Fallback Material Icons (can be replaced with SVGs if added later)
  static IconData get notifications => Icons.notifications_none_outlined;
  static IconData get person => Icons.person_outline;
  static IconData get chat => Icons.chat_bubble_outline;
  static IconData get contacts => Icons.contacts_outlined;
  static IconData get sensors => Icons.sensors;
  static IconData get qrCode => Icons.qr_code;
  static IconData get add => Icons.add;
  static IconData get back => Icons.arrow_back_ios_new;
  static IconData get chevronRight => Icons.chevron_right;
  static IconData get camera => Icons.camera_alt_outlined;
  static IconData get lock => Icons.lock_outline;
  static IconData get visibility => Icons.visibility_outlined;
  static IconData get visibilityOff => Icons.visibility_off_outlined;
  static IconData get error => Icons.error_outline;
  static IconData get forward => Icons.arrow_forward_ios;
  static IconData get medication => Icons.medication_outlined;
  static IconData get repeat => Icons.repeat;
  static IconData get description => Icons.description_outlined;
  static IconData get smartBox => Icons.inventory_2_outlined;
  static IconData get time => Icons.access_time;
  static IconData get dosage => Icons.shutter_speed;
  static IconData get people => Icons.people_outline;
  static IconData get scanner => Icons.qr_code_scanner;
  static IconData get videoCall => Icons.videocam_outlined;
}
