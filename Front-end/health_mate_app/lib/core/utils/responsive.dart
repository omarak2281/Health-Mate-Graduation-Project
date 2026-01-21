import 'package:flutter/material.dart';

/// Responsive utility to handle different screen sizes reactively
class Responsive {
  Responsive._();

  static MediaQueryData mediaQuery(BuildContext context) =>
      MediaQuery.of(context);
  static double screenWidth(BuildContext context) =>
      mediaQuery(context).size.width;
  static double screenHeight(BuildContext context) =>
      mediaQuery(context).size.height;

  /// Get responsive width (percentage of screen width)
  static double w(BuildContext context, double percentage) =>
      screenWidth(context) * (percentage / 100);

  /// Get responsive height (percentage of screen height)
  static double h(BuildContext context, double percentage) =>
      screenHeight(context) * (percentage / 100);

  /// Get responsive font size based on screen width
  /// baseRadius is the design-time font size on 375px width (Standard iPhone)
  static double sp(BuildContext context, double baseSize) {
    return baseSize * (screenWidth(context) / 375);
  }

  /// Check if screen is small (phone)
  static bool isSmallScreen(BuildContext context) => screenWidth(context) < 600;

  /// Check if screen is medium (tablet)
  static bool isMediumScreen(BuildContext context) =>
      screenWidth(context) >= 600 && screenWidth(context) < 1200;

  /// Check if screen is large (desktop/large tablet)
  static bool isLargeScreen(BuildContext context) =>
      screenWidth(context) >= 1200;
}

/// Extension for easy access to responsive dimensions from BuildContext
extension BuildContextResponsive on BuildContext {
  double get rw => Responsive.screenWidth(this);
  double get rh => Responsive.screenHeight(this);

  double w(double percentage) => Responsive.w(this, percentage);
  double h(double percentage) => Responsive.h(this, percentage);
  double sp(double baseSize) => Responsive.sp(this, baseSize);

  bool get isSmallScreen => Responsive.isSmallScreen(this);
  bool get isMediumScreen => Responsive.isMediumScreen(this);
  bool get isLargeScreen => Responsive.isLargeScreen(this);
}
