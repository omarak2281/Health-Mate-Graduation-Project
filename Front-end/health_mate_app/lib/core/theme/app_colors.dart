import 'package:flutter/material.dart';

// /**
//  * Medical Color Palette
//  * Professional colors suitable for healthcare applications
//  */

class AppColors {
  AppColors._();

  // Primary Colors (Medical Blue-Green)
  static const Color primary = Color(0xFF0D7377);
  static const Color primaryLight = Color(0xFF14FFEC);
  static const Color primaryDark = Color(0xFF053B3F);

  // Secondary Colors (Calming Teal)
  static const Color secondary = Color(0xFF32E0C4);
  static const Color secondaryLight = Color(0xFF7FF9EB);
  static const Color secondaryDark = Color(0xFF1A8B7D);

  // Accent Colors
  static const Color accent = Color(0xFFEEEEEE);
  static const Color accentDark = Color(0xFF212121);

  // Risk Level Colors
  static const Color riskNormal = Color(0xFF4CAF50); // Green
  static const Color riskLow = Color(0xFF2196F3); // Blue
  static const Color riskModerate = Color(0xFFFF9800); // Orange
  static const Color riskHigh = Color(0xFFFF5722); // Deep Orange
  static const Color riskCritical = Color(0xFFF44336); // Red

  // Background Colors
  static const Color backgroundLight = Color(0xFFF5F5F5);
  static const Color backgroundDark = Color(0xFF121212);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);

  // Text Colors
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textDisabled = Color(0xFFBDBDBD);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFE0E0E0);

  // Functional Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);

  // Overlay Colors
  static const Color overlay = Color(0x66000000);
  static const Color overlayLight = Color(0x33000000);

  // Border Colors
  static const Color border = Color(0xFFE0E0E0);
  static const Color borderDark = Color(0xFF424242);

  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowDark = Color(0x33000000);

  // Gradient Colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryLight],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Status Colors
  static const Color online = Color(0xFF4CAF50);
  static const Color offline = Color(0xFF9E9E9E);
  static const Color busy = Color(0xFFFF9800);

  // Pure Colors & Variations (for use in specific high-contrast UIs)
  static const Color white = Color(0xFFFFFFFF);
  static const Color white70 = Color(0xB3FFFFFF);
  static const Color white54 = Color(0x8AFFFFFF);
  static const Color white38 = Color(0x61FFFFFF);
  static const Color white24 = Color(0x3DFFFFFF);
  static const Color white12 = Color(0x1FFFFFFF);

  static const Color black = Color(0xFF000000);
  static const Color black87 = Color(0xDD000000);
  static const Color black54 = Color(0x89000000);
  static const Color black45 = Color(0x73000000);
  static const Color black38 = Color(0x61000000);
  static const Color black26 = Color(0x42000000);
  static const Color black12 = Color(0x1F000000);

  // Feature Specific Colors
  static const Color drawerIcon = Color(0xFFFFEB3B); // Yellow

  // UI Specific Colors (Aliases for consistency with Login/Register pages)
  static const Color expertTeal = primary;
  static const Color mediumGray = textSecondary;
  static const Color darkGrayText = textPrimary;
  static const Color borderGray = border;

  // New Colors
  static const Color transparent = Colors.transparent;
  static const Color googleBlue = Color(0xFF4285F4);
  static const Color pageBackground = Color(0xFFF8FBFC);
  static const Color accentRed = Color(0xFFE57373);
  static const Color grey = Colors.grey;

  // Theme-aware colors
  static const Color cardDark = Color(0xFF2C2C2C);
}
