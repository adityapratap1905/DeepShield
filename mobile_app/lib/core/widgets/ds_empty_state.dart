import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

/// Empty state illustration with title, subtitle, and optional action button
class DSEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const DSEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconBackground =
        isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    final border =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final titleColor =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final bodyColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final iconColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: iconBackground.withValues(alpha: 0.4),
                shape: BoxShape.circle,
                border: Border.all(color: border),
              ),
              child: Icon(icon, size: 36, color: iconColor),
            )
                .animate()
                .scale(duration: 400.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                color: titleColor,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms)
                .slideY(begin: 0.2, end: 0, delay: 200.ms),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: bodyColor,
                fontSize: 14,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),
            if (actionLabel != null) ...[
              const SizedBox(height: 24),
              TextButton(
                onPressed: onAction,
                child: Text(actionLabel!,
                    style: TextStyle(
                        color: isDark
                            ? AppColors.primary
                            : AppColors.primaryLight)),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
