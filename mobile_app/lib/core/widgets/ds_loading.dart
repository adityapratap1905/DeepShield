import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';

/// Full-screen or inline loading indicator
class DSLoading extends StatelessWidget {
  final String? message;
  const DSLoading({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2.5,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                style: const TextStyle(
                  color: AppColors.textSecondaryDark,
                  fontSize: 14,
                ),
              ),
            ],
          ],
        ),
      );
}

/// Shimmer card placeholder (for list loading states)
class DSShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double borderRadius;

  const DSShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight,
      highlightColor: isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlightLight,
      child: Container(
        height: height,
        width: width ?? double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBaseLight,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// Shimmer list — renders n placeholders
class DSShimmerList extends StatelessWidget {
  final int count;
  final double cardHeight;

  const DSShimmerList({super.key, this.count = 5, this.cardHeight = 80});

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => DSShimmerCard(height: cardHeight),
      );
}
