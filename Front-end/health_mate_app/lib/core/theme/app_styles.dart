import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppStyles {
  AppStyles._();

  // Text Styles
  static TextStyle get pageTitleStyle => GoogleFonts.tajawal(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.white,
      );

  static TextStyle get pageSubtitleStyle => GoogleFonts.tajawal(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.white.withOpacity(0.9),
      );

  static TextStyle get headingStyle => GoogleFonts.tajawal(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get cardTitleStyle => GoogleFonts.tajawal(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelStyle => GoogleFonts.tajawal(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      );

  static TextStyle get bodyStyle => GoogleFonts.tajawal(
        fontSize: 16,
        color: AppColors.textPrimary,
      );

  static TextStyle get secondaryTextStyle => GoogleFonts.tajawal(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.expertTeal,
      );

  // Button Styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: AppColors.expertTeal,
        foregroundColor: Colors.white,
        elevation: 4,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.tajawal(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        minimumSize: const Size(double.infinity, 56),
      );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 2,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
        textStyle: GoogleFonts.tajawal(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        minimumSize: const Size(double.infinity, 56),
      );

  // Input Decoration
  static InputDecoration inputDecoration({
    required String hint,
    IconData? icon,
    Widget? customIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: customIcon != null
          ? Padding(
              padding: const EdgeInsets.all(12.0),
              child: customIcon,
            )
          : (icon != null ? Icon(icon, color: AppColors.textSecondary) : null),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.black, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.expertTeal, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
    );
  }
}
