import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';

/// Full-screen error display with retry option
class DSErrorScreen extends StatelessWidget {
  final String? title;
  final String message;
  final VoidCallback? onRetry;
  final bool isNetworkError;

  const DSErrorScreen({
    super.key,
    this.title,
    required this.message,
    this.onRetry,
    this.isNetworkError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Error icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.dangerContainer,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Icon(
                isNetworkError ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 38,
                color: AppColors.danger,
              ),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut)
                .fadeIn(duration: 400.ms),

            const SizedBox(height: 24),

            Text(
              title ?? (isNetworkError ? 'No Internet Connection' : 'Something Went Wrong'),
              style: const TextStyle(
                color: AppColors.textPrimaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms),

            const SizedBox(height: 8),

            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondaryDark,
                fontSize: 14,
                height: 1.6,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 300.ms),

            if (onRetry != null) ...[
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try Again'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ).animate().fadeIn(delay: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}
