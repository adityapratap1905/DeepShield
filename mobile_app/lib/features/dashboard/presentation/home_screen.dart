import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../routes/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final name = StorageService.instance.userName.trim();

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _Header(userName: name, isDark: isDark)
                        .animate()
                        .fadeIn(duration: 450.ms)
                        .slideY(begin: -0.08, end: 0, duration: 450.ms),
                    const SizedBox(height: 36),
                    _PrimaryScanExperience(isDark: isDark)
                        .animate()
                        .fadeIn(delay: 100.ms, duration: 450.ms)
                        .scale(begin: const Offset(0.97, 0.97)),
                    const SizedBox(height: 30),
                    _PhotoChecksCard(isDark: isDark)
                        .animate()
                        .fadeIn(delay: 180.ms, duration: 450.ms),
                    const SizedBox(height: 16),
                    _EstimateNote(isDark: isDark)
                        .animate()
                        .fadeIn(delay: 240.ms, duration: 450.ms),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String userName;
  final bool isDark;

  const _Header({required this.userName, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 18
            ? 'Good afternoon'
            : 'Good evening';
    final firstName = userName.split(' ').first;
    final displayName = firstName.isEmpty ? 'User' : firstName;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style: TextStyle(color: textSecondary, fontSize: 14)),
              const SizedBox(height: 4),
              Text(
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Stay aware. Check before sharing.',
                style: TextStyle(color: textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          children: [
            IconButton(
              tooltip: 'Open notifications',
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push(AppRoutes.notifications);
              },
              icon: Icon(Icons.notifications_none_rounded,
                  color: textPrimary, size: 27),
            ),
            const SizedBox(width: 4),
            CircleAvatar(
              radius: 20,
              backgroundColor:
                  isDark ? AppColors.dividerDark : AppColors.dividerLight,
              child: Text(
                displayName[0].toUpperCase(),
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _PrimaryScanExperience extends StatelessWidget {
  final bool isDark;

  const _PrimaryScanExperience({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;
        final buttonSize = compact ? 150.0 : 170.0;
        final actionWidth = compact ? 66.0 : 76.0;
        final actionHeight = compact ? 76.0 : 84.0;

        return SizedBox(
          height: 280,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              _ScanRings(isDark: isDark),
              _MainScanButton(
                isDark: isDark,
                size: buttonSize,
                onTap: () {
                  HapticFeedback.mediumImpact();
                  context.push(AppRoutes.scan);
                },
              ),
              Positioned(
                left: 0,
                top: 10,
                child: _FloatingAction(
                  icon: Icons.link_rounded,
                  label: 'URL',
                  isDark: isDark,
                  width: actionWidth,
                  height: actionHeight,
                  onTap: () => context.push(AppRoutes.scanUrl),
                ),
              ),
              Positioned(
                right: 0,
                top: 10,
                child: _FloatingAction(
                  icon: Icons.image_outlined,
                  label: 'Photo',
                  isDark: isDark,
                  width: actionWidth,
                  height: actionHeight,
                  onTap: () => context.push(AppRoutes.scanFile),
                ),
              ),
              Positioned(
                left: 0,
                bottom: 10,
                child: _FloatingAction(
                  icon: Icons.qr_code_2_rounded,
                  label: 'QR Code',
                  isDark: isDark,
                  width: actionWidth,
                  height: actionHeight,
                  onTap: () => context.push(AppRoutes.scanQr),
                ),
              ),
              Positioned(
                right: 0,
                bottom: 10,
                child: _FloatingAction(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  isDark: isDark,
                  width: actionWidth,
                  height: actionHeight,
                  onTap: null,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MainScanButton extends StatelessWidget {
  final bool isDark;
  final double size;
  final VoidCallback onTap;

  const _MainScanButton({
    required this.isDark,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Semantics(
      button: true,
      label: 'Open photo scan options',
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: 10,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.document_scanner_outlined, color: primary, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Scan',
                  style: TextStyle(
                    color: textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap to start',
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanRings extends StatelessWidget {
  final bool isDark;

  const _ScanRings({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final reduceMotion = MediaQuery.of(context).disableAnimations;

    Widget ring(double size, double opacity) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: primary.withValues(alpha: opacity),
              width: 1,
            ),
          ),
        );

    if (reduceMotion) {
      return Stack(
        alignment: Alignment.center,
        children: [ring(250, 0.05), ring(210, 0.1)],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        ring(250, 0.05)
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.1, 1.1),
              duration: 3.seconds,
              curve: Curves.easeOut,
            )
            .fade(begin: 1, end: 0, duration: 3.seconds, curve: Curves.easeOut),
        ring(210, 0.1)
            .animate(onPlay: (controller) => controller.repeat())
            .scale(
              begin: const Offset(0.9, 0.9),
              end: const Offset(1.2, 1.2),
              duration: 3.seconds,
              curve: Curves.easeOut,
            )
            .fade(begin: 1, end: 0, duration: 3.seconds, curve: Curves.easeOut),
      ],
    );
  }
}

class _FloatingAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final double width;
  final double height;
  final VoidCallback? onTap;

  const _FloatingAction({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.width,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final enabled = onTap != null;

    return Tooltip(
      message: enabled ? label : 'Video checks are coming later',
      child: Semantics(
        button: enabled,
        enabled: enabled,
        label: enabled ? label : 'Video checks coming later',
        onTap: onTap,
        child: ExcludeSemantics(
          child: GestureDetector(
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onTap!();
                  }
                : null,
            child: Opacity(
              opacity: enabled ? 1 : 0.5,
              child: Container(
                width: width,
                height: height,
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: textPrimary, size: 24),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoChecksCard extends StatelessWidget {
  final bool isDark;

  const _PhotoChecksCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return DSCard(
      padding: const EdgeInsets.all(20),
      customBorder: Border.all(color: primary.withValues(alpha: 0.2)),
      hasShadow: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PHOTO CHECKS',
            style: TextStyle(
              color: textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          _CheckLine(
            icon: Icons.auto_awesome_outlined,
            title: 'AI-generated image signals',
            primary: primary,
            textPrimary: textPrimary,
          ),
          const SizedBox(height: 14),
          _CheckLine(
            icon: Icons.face_retouching_natural_outlined,
            title: 'Possible face manipulation',
            primary: primary,
            textPrimary: textPrimary,
          ),
        ],
      ),
    );
  }
}

class _CheckLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color primary;
  final Color textPrimary;

  const _CheckLine({
    required this.icon,
    required this.title,
    required this.primary,
    required this.textPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _EstimateNote extends StatelessWidget {
  final bool isDark;

  const _EstimateNote({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded,
            color: AppColors.warning, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            'Model scores are estimates, not proof. The face check runs only when a face is detected.',
            style: TextStyle(
              color: textSecondary,
              fontSize: 12,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
