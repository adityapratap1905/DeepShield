import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';
import 'text_styles.dart';

/// DeepShield Material 3 Theme Configuration
class AppTheme {
  AppTheme._();

  // ── Color Scheme — Dark ─────────────────────────────────────────
  static ColorScheme get _darkColorScheme => const ColorScheme.dark(
        brightness: Brightness.dark,
        primary: AppColors.primary,
        onPrimary: Color(0xFF030509),
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primary,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        secondaryContainer: AppColors.secondaryContainer,
        onSecondaryContainer: AppColors.secondary,
        error: AppColors.danger,
        onError: Colors.white,
        errorContainer: AppColors.dangerContainer,
        onErrorContainer: AppColors.danger,
        surface: AppColors.surfaceDark,
        onSurface: AppColors.textPrimaryDark,
        onSurfaceVariant: AppColors.textSecondaryDark,
        outline: AppColors.cardBorderDark,
        outlineVariant: AppColors.dividerDark,
        inverseSurface: AppColors.textPrimaryDark,
        onInverseSurface: AppColors.surfaceDark,
        surfaceContainerHighest: AppColors.cardDark,
        surfaceContainerHigh: AppColors.cardDark,
        surfaceContainer: AppColors.surfaceDark,
        surfaceContainerLow: AppColors.backgroundDark,
        surfaceContainerLowest: AppColors.backgroundDark,
      );

  // ── Color Scheme — Light ────────────────────────────────────────
  static ColorScheme get _lightColorScheme => const ColorScheme.light(
        brightness: Brightness.light,
        primary: AppColors.primaryLight,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainerLight,
        onPrimaryContainer: AppColors.primaryLight,
        secondary: AppColors.secondary,
        onSecondary: Colors.white,
        error: AppColors.danger,
        onError: Colors.white,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        onSurfaceVariant: AppColors.textSecondaryLight,
        outline: AppColors.cardBorderLight,
        outlineVariant: AppColors.dividerLight,
        surfaceContainerHighest: AppColors.cardLight,
        surfaceContainer: AppColors.cardLight,
        surfaceContainerLow: AppColors.backgroundLight,
        surfaceContainerLowest: AppColors.backgroundLight,
      );

  // ── Dark Theme ──────────────────────────────────────────────────
  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: _darkColorScheme,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        textTheme: AppTextStyles.textTheme(Brightness.dark),
        iconTheme: const IconThemeData(color: AppColors.textSecondaryDark),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          thickness: 1,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.textTheme(Brightness.dark).titleLarge?.copyWith(
                color: AppColors.textPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
          iconTheme: const IconThemeData(color: AppColors.textPrimaryDark),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardDark,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardBorderDark, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardDark,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
          hintStyle: const TextStyle(color: AppColors.textTertiaryDark),
          prefixIconColor: AppColors.textSecondaryDark,
          suffixIconColor: AppColors.textSecondaryDark,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: const Color(0xFF030509),
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.cardDark,
          selectedColor: AppColors.primaryContainer,
          side: const BorderSide(color: AppColors.cardBorderDark),
          labelStyle: const TextStyle(color: AppColors.textSecondaryDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primary;
            return AppColors.textTertiaryDark;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryContainer;
            return AppColors.cardDark;
          }),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primary,
          linearTrackColor: AppColors.cardDark,
          circularTrackColor: AppColors.cardDark,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardDark,
          contentTextStyle: const TextStyle(color: AppColors.textPrimaryDark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.cardBorderDark),
          ),
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceDark,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.textSecondaryDark,
          textColor: AppColors.textPrimaryDark,
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(),
        ),
      );

  // ── Light Theme ─────────────────────────────────────────────────
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: _lightColorScheme,
        scaffoldBackgroundColor: AppColors.backgroundLight,
        textTheme: AppTextStyles.textTheme(Brightness.light),
        iconTheme: const IconThemeData(color: AppColors.textSecondaryLight),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerLight,
          thickness: 1,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: AppTextStyles.textTheme(Brightness.light).titleLarge?.copyWith(
                color: AppColors.textPrimaryLight,
                fontWeight: FontWeight.w600,
              ),
          iconTheme: const IconThemeData(color: AppColors.textPrimaryLight),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primaryLight,
          unselectedItemColor: AppColors.textTertiaryLight,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.cardLight,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.cardBorderLight, width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.cardLight,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.cardBorderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primaryLight, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
          hintStyle: const TextStyle(color: AppColors.textTertiaryLight),
          prefixIconColor: AppColors.textSecondaryLight,
          suffixIconColor: AppColors.textSecondaryLight,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            textStyle: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            side: const BorderSide(color: AppColors.primaryLight),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryLight,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.cardLight,
          selectedColor: AppColors.primaryContainerLight,
          side: const BorderSide(color: AppColors.cardBorderLight),
          labelStyle: const TextStyle(color: AppColors.textSecondaryLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryLight;
            return AppColors.textTertiaryLight;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryContainerLight;
            return AppColors.cardLight;
          }),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.primaryLight,
          linearTrackColor: AppColors.cardLight,
          circularTrackColor: AppColors.cardLight,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.cardLight,
          contentTextStyle: const TextStyle(color: AppColors.textPrimaryLight),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          behavior: SnackBarBehavior.floating,
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AppColors.cardBorderLight),
          ),
          elevation: 0,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: AppColors.surfaceLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: AppColors.textSecondaryLight,
          textColor: AppColors.textPrimaryLight,
          tileColor: Colors.transparent,
          shape: RoundedRectangleBorder(),
        ),
      );
}
