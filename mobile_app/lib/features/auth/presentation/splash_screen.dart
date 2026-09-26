import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_animated_gradient.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../routes/app_router.dart';

/// Splash screen — shows animated logo with aurora background, then routes based on auth state
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    // Let the animation play
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;

    final storage = StorageService.instance;

    if (!storage.isOnboardingDone) {
      context.go(AppRoutes.onboarding);
    } else if (storage.isLoggedIn) {
      context.go(AppRoutes.home);
    } else {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: DSAuroraBackground(
        child: Stack(
          children: [
            // Background radar pulse — violet
            Center(
              child: DSRadarPulse(
                size: 340,
                color: AppColors.primary.withValues(alpha: 0.15),
              ),
            ),

            // Secondary outer pulse ring
            Center(
              child: DSRadarPulse(
                size: 240,
                color: AppColors.secondary.withValues(alpha: 0.1),
              ),
            ),

            // Logo + branding
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 110,
                      height: 110,
                      fit: BoxFit.cover,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.4, 0.4),
                        end: const Offset(1.0, 1.0),
                        duration: 750.ms,
                        curve: Curves.elasticOut,
                      )
                      .fadeIn(duration: 500.ms),

                  const SizedBox(height: 32),

                  // App name — DEEP in white, SHIELD in violet
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'DEEP',
                          style: TextStyle(
                            color: AppColors.textPrimaryDark,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        TextSpan(
                          text: 'SHIELD',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 38,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 400.ms, duration: 600.ms)
                      .slideY(begin: 0.3, end: 0, delay: 400.ms, duration: 500.ms),

                  const SizedBox(height: 10),

                  // Tagline
                  Text(
                    'DETECT  •  PROTECT  •  DEFEND',
                    style: TextStyle(
                      color: AppColors.primary.withValues(alpha: 0.85),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.5,
                    ),
                  ).animate().fadeIn(delay: 700.ms, duration: 600.ms),

                  const SizedBox(height: 8),

                  // Sub-tagline
                  Text(
                    'AI-Powered Deepfake Detection Platform',
                    style: TextStyle(
                      color: AppColors.textSecondaryDark.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ).animate().fadeIn(delay: 900.ms, duration: 600.ms),
                ],
              ),
            ),

            // Version label at the bottom
            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: Text(
                'v1.0.0',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textTertiaryDark.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ).animate().fadeIn(delay: 1200.ms),
            ),
          ],
        ),
      ),
    );
  }
}
