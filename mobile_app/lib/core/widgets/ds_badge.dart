import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Threat level / status badge pill
class DSBadge extends StatelessWidget {
  final String? label;
  final String? threatLevel;
  final Color? color;
  final bool filled;
  final double fontSize;

  const DSBadge({
    super.key,
    this.label,
    this.threatLevel,
    this.color,
    this.filled = false,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final effectiveColor = color ?? (threatLevel != null ? AppColors.threatColor(threatLevel!, isDark: isDark) : AppColors.primary);
    final effectiveLabel = label ?? (threatLevel != null ? threatLevel!.toUpperCase() : '');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: filled ? effectiveColor : effectiveColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: effectiveColor.withValues(alpha: 0.4), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: effectiveColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            effectiveLabel,
            style: TextStyle(
              color: effectiveColor,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

/// Scan type badge
class DSScanTypeBadge extends StatelessWidget {
  final String label;
  final IconData icon;

  const DSScanTypeBadge({super.key, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final container = isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    final border = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: container.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: primary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
