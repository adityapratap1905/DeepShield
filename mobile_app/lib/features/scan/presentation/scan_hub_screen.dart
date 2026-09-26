import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../routes/app_router.dart';

/// Scan hub — entry point for the photo analysis MVP.
class ScanHubScreen extends StatelessWidget {
  const ScanHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: DSAuroraBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              pinned: true,
              title: Text(
                'Scan',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              centerTitle: false,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _ScanBanner(isDark: isDark)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 28),
                  Text(
                    'Analyze a photo',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 16),
                  _ScanTypeCard(
                    icon: Icons.image_rounded,
                    color: AppColors.warning,
                    title: 'Photo Scanner',
                    subtitle:
                        'Upload a JPG or PNG photo for separate AI-generation and face-manipulation estimates.',
                    tag: 'JPG · PNG',
                    tagColor: AppColors.warning,
                    isDark: isDark,
                    onTap: () => context.push(AppRoutes.scanFile),
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideX(begin: 0.1, end: 0, delay: 200.ms),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanBanner extends StatelessWidget {
  final bool isDark;

  const _ScanBanner({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final gradient =
        isDark ? AppColors.primaryGradientDark : AppColors.primaryGradientLight;

    final cardGradient = isDark
        ? const LinearGradient(
            colors: [Color(0xFF1E0A3A), Color(0xFF0A0520)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : LinearGradient(
            colors: [
              const Color(0xFFE0F7FA),
              const Color(0xFFB2EBF2).withValues(alpha: 0.5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          );

    return DSCard(
      gradient: cardGradient,
      customBorder: Border.all(color: primary.withValues(alpha: 0.3)),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Check a photo',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'See estimates for AI-generated imagery and possible face manipulation. Results are not proof of authenticity.',
                  style: TextStyle(
                    color: textSecondary.withValues(alpha: 0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                    color: primary.withValues(alpha: 0.3), blurRadius: 20),
              ],
            ),
            child:
                const Icon(Icons.shield_rounded, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _ScanTypeCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;
  final bool isDark;

  const _ScanTypeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.tagColor,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;

    return Semantics(
      button: true,
      label: 'Open photo scanner. $subtitle',
      onTap: onTap,
      child: ExcludeSemantics(
        child: DSCard(
          onTap: onTap,
          padding: const EdgeInsets.all(18),
          customBorder: Border.all(color: color.withValues(alpha: 0.2)),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tagColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tag,
                            style: TextStyle(
                              color: tagColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
