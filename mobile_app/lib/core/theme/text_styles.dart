import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// DeepShield Text Style System
///
/// Clean, premium, intelligent typography using Outfit.
abstract class AppTextStyles {
  AppTextStyles._();

  /// Full Material 3 text theme applied to both dark and light
  static TextTheme textTheme(Brightness brightness) {
    final bool isDark = brightness == Brightness.dark;
    final Color primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final Color secondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return TextTheme(
      // Display — massive hero text
      displayLarge: GoogleFonts.outfit(
        fontSize: 57, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -1.5, height: 1.1,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -1.0, height: 1.1,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: -0.5, height: 1.15,
      ),

      // Headline — section titles
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: primary, letterSpacing: -0.5, height: 1.2,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: -0.3, height: 1.2,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: -0.2, height: 1.25,
      ),

      // Title — card titles, screen titles
      titleLarge: GoogleFonts.outfit(
        fontSize: 22, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: -0.2, height: 1.3,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1, height: 1.4,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1, height: 1.4,
      ),

      // Body — readable prose and form text
      bodyLarge: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w400,
        color: primary, letterSpacing: 0.15, height: 1.5,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w400,
        color: primary, letterSpacing: 0.25, height: 1.5,
      ),
      bodySmall: GoogleFonts.outfit(
        fontSize: 12, fontWeight: FontWeight.w400,
        color: secondary, letterSpacing: 0.4, height: 1.5,
      ),

      // Label — buttons, chips, tags
      labelLarge: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w600,
        color: primary, letterSpacing: 0.1, height: 1.4,
      ),
      labelMedium: GoogleFonts.outfit(
        fontSize: 12, fontWeight: FontWeight.w600,
        color: secondary, letterSpacing: 0.5, height: 1.4,
      ),
      labelSmall: GoogleFonts.outfit(
        fontSize: 11, fontWeight: FontWeight.w500,
        color: secondary, letterSpacing: 0.5, height: 1.4,
      ),
    );
  }

  // ── Convenience Getters ─────────────────────────────────────────
  /// Style for scores, percentages, and prominent values
  static TextStyle get numericLarge => GoogleFonts.outfit(
        fontSize: 48, fontWeight: FontWeight.w700,
        color: AppColors.primary, letterSpacing: -1.5,
      );

  static TextStyle get numericMedium => GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w700,
        color: AppColors.primary, letterSpacing: -1,
      );

  static TextStyle get numericSmall => GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w600,
        color: AppColors.textSecondaryDark, letterSpacing: 0.2,
      );
}
