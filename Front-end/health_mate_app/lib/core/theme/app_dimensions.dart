import 'package:flutter/material.dart';

/// App Dimensions
/// Centralized source for all spatial constants (padding, radius, margins).
class AppDimensions {
  AppDimensions._();

  // ─── Border Radii ──────────────────────────────────────────────────────────
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusExtraLarge = 32.0;

  static BorderRadius get borderSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get borderMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get borderLarge => BorderRadius.circular(radiusLarge);
  static BorderRadius get borderExtraLarge =>
      BorderRadius.circular(radiusExtraLarge);

  // ─── Spacing (Paddings/Margins) ───────────────────────────────────────────
  static const double spaceSmall = 8.0;
  static const double spaceMedium = 16.0;
  static const double spaceLarge = 24.0;
  static const double spaceExtraLarge = 32.0;

  // ─── Widget Specific ──────────────────────────────────────────────────────
  static const double iconSizeSmall = 18.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;

  static const double cardElevation = 4.0;
  static const double drawerTileAspectRatio = 1.1; // GridView tile aspect ratio
}
