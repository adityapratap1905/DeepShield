import 'package:flutter/material.dart';

/// DeepShield Design System — Color Tokens
///
/// Light Mode: Frosted Glass Pro + Horizon Wave
/// Dark Mode: Orbital Minimal
abstract class AppColors {
  // ── Background ─────────────────────────────────────────────────
  // Dark: Near-black / deep navy
  static const Color backgroundDark = Color(0xFF030509);
  // Light: Soft premium frosted base (slight blue/grey tint for depth)
  static const Color backgroundLight = Color(0xFFF9FAFB);

  static const Color surfaceDark = Color(0xFF080B14);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  static const Color cardDark = Color(0xFF0A0F1E);
  static const Color cardLight = Color(0xFFFFFFFF);

  static const Color cardBorderDark = Color(0xFF162038);
  static const Color cardBorderLight = Color(0xFFE2E6F0);

  // ── Primary — Sophisticated Security Green ─────────────
  // Emerald Green for dark mode, Deep Emerald for light mode
  static const Color primary = Color(0xFF10B981);
  static const Color primaryDim = Color(0xFF059669);
  static const Color primaryGlow = Color(0x3310B981);
  static const Color primaryContainer = Color(0xFF064E3B);

  // Light Mode Primary (slightly deeper for contrast)
  static const Color primaryLight = Color(0xFF059669);
  static const Color primaryContainerLight = Color(0xFFD1FAE5);

  // ── Secondary — Deep Blue / Wave Blue ──────────────────────────────────
  static const Color secondary = Color(0xFF2962FF);
  static const Color secondaryDim = Color(0xFF1565C0);
  static const Color secondaryGlow = Color(0x332962FF);
  static const Color secondaryContainer = Color(0xFF001440);

  // ── Danger ─────────────────────────────────────────────────────
  static const Color danger = Color(0xFFFF1744);
  static const Color dangerLight = Color(0xFFD50000); // Renamed from dangerDim
  static const Color dangerGlow = Color(0x33FF1744);
  static const Color dangerContainer = Color(0xFF33040E);
  static const Color dangerContainerLight = Color(0xFFFFEBEE);

  // ── Warning ────────────────────────────────────────────────────
  static const Color warning = Color(0xFFFF9100);
  static const Color warningLight = Color(0xFFFF6D00); // Renamed from warningDim
  static const Color warningGlow = Color(0x33FF9100);
  static const Color warningContainer = Color(0xFF331D00);
  static const Color warningContainerLight = Color(0xFFFFF3E0);

  // ── Success ────────────────────────────────────────────────────
  static const Color success = Color(0xFF00E676);
  static const Color successLight = Color(0xFF00C853); // Renamed from successDim
  static const Color successGlow = Color(0x3300E676);
  static const Color successContainer = Color(0xFF00331A);
  static const Color successContainerLight = Color(0xFFE8F5E9);

  // ── Text ───────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
  static const Color textTertiaryDark = Color(0xFF475569);

  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textTertiaryLight = Color(0xFF94A3B8);

  // ── Glassmorphism Tokens ───────────────────────────────────────
  static const Color glassWhite = Color(0xB3FFFFFF);    // Frosted Light
  static const Color glassBorderLight = Color(0x33FFFFFF); 
  
  static const Color glassDark = Color(0x330A0F1E);     // Frosted Dark
  static const Color glassBorderDark = Color(0x1AFFFFFF); 

  static const double glassBlurSigma = 24.0;

  // ── Misc ───────────────────────────────────────────────────────
  static const Color dividerDark = Color(0xFF1E293B);
  static const Color dividerLight = Color(0xFFE2E8F0);

  static const Color shimmerBaseDark = Color(0xFF0F172A);
  static const Color shimmerHighlightDark = Color(0xFF1E293B);

  static const Color shimmerBaseLight = Color(0xFFE2E8F0);
  static const Color shimmerHighlightLight = Color(0xFFF1F5F9);

  // ── Gradients ──────────────────────────────────────────────────

  /// Primary gradient (Orbital Minimal Dark)
  static const LinearGradient primaryGradientDark = LinearGradient(
    colors: [Color(0xFF34D399), Color(0xFF10B981)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Primary gradient (Horizon Wave Light)
  static const LinearGradient primaryGradientLight = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient primaryGradient = primaryGradientDark; // Alias

  static const LinearGradient dangerGradient = LinearGradient(
    colors: [Color(0xFFFF1744), Color(0xFFB71C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradient = LinearGradient(
    colors: [Color(0xFF00E676), Color(0xFF007A40)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient safeGradientLight = LinearGradient(
    colors: [Color(0xFF00C853), Color(0xFF00A040)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Threat Level Colors ─────────────────────────────────────────
  static Color threatColor(String level, {bool isDark = true}) {
    switch (level.toLowerCase()) {
      case 'safe':
        return isDark ? success : successLight;
      case 'low':
        return isDark ? warning : warningLight;
      case 'medium':
        return isDark ? const Color(0xFFFF6D00) : const Color(0xFFE65100);
      case 'high':
      case 'critical':
      case 'dangerous':
      case 'fake':
        return isDark ? danger : dangerLight;
      default:
        return isDark ? textSecondaryDark : textSecondaryLight;
    }
  }

  static Color threatGlow(String level) {
    switch (level.toLowerCase()) {
      case 'safe':
        return successGlow;
      case 'low':
        return warningGlow;
      case 'medium':
        return const Color(0x33FF6D00);
      case 'high':
      case 'critical':
      case 'dangerous':
      case 'fake':
        return dangerGlow;
      default:
        return Colors.transparent;
    }
  }
}
