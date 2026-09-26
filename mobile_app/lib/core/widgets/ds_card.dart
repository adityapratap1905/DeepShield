import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// DeepShield card with glassmorphism effect (Frosted Glass Pro & Orbital Minimal)
class DSCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final bool glass;
  final bool hasShadow;
  final bool hasGlow;
  final Color? glowColor;
  final Color? backgroundColor;
  final double borderRadius;
  final double? height;
  final double? width;
  final VoidCallback? onTap;
  final LinearGradient? gradient;
  final Border? customBorder;

  const DSCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.glass = true,
    this.hasShadow = false,
    this.hasGlow = false,
    this.glowColor,
    this.backgroundColor,
    this.borderRadius = 20,
    this.height,
    this.width,
    this.onTap,
    this.gradient,
    this.customBorder,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectiveBg = backgroundColor ??
        (glass
            ? (isDark ? AppColors.glassDark : AppColors.glassWhite)
            : (isDark ? AppColors.cardDark : AppColors.cardLight));

    final effectiveBorderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final glassBorderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    final effectiveBorder = customBorder ??
        Border.all(
          color: glass ? glassBorderColor : effectiveBorderColor,
          width: 1,
        );

    Widget card = Container(
      height: height,
      width: width,
      margin: margin,
      decoration: BoxDecoration(
        color: gradient != null ? null : (glass ? Colors.transparent : effectiveBg),
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius),
        border: effectiveBorder,
        boxShadow: hasShadow || hasGlow
            ? [
                if (hasShadow)
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.4) : AppColors.secondary.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                if (hasGlow)
                  BoxShadow(
                    color: glowColor ?? AppColors.primaryGlow,
                    blurRadius: 24,
                    spreadRadius: -4,
                  ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: glass
            ? BackdropFilter(
                filter: ImageFilter.blur(
                  sigmaX: AppColors.glassBlurSigma,
                  sigmaY: AppColors.glassBlurSigma,
                ),
                child: Container(
                  color: effectiveBg,
                  padding: padding ?? const EdgeInsets.all(20),
                  child: child,
                ),
              )
            : Padding(
                padding: padding ?? const EdgeInsets.all(20),
                child: child,
              ),
      ),
    );

    if (onTap != null) {
      card = GestureDetector(
        onTap: onTap,
        child: card,
      );
    }

    return card;
  }
}
