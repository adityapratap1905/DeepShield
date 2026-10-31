import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../routes/app_router.dart';

// Onboarding page data
class _OnboardingPage {
  final IconData icon;
  final Color Function(bool) iconColor;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.subtitle,
  });
}

final _pages = [
  _OnboardingPage(
    icon: Icons.shield_rounded,
    iconColor: (isDark) => isDark ? AppColors.primary : AppColors.primaryLight,
    subtitle: 'Detect. Discuss. Protect.',
  ),
];

/// Brand introduction inspired by the DeepShield launch screen.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await StorageService.instance.setOnboardingDone();
    if (mounted) context.go(AppRoutes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final cardBorder =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: true,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemCount: _pages.length,
                  itemBuilder: (_, index) => _OnboardingPageWidget(
                      page: _pages[index], isDark: isDark),
                ),
              ),

              // Indicators + CTA
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                child: Column(
                  children: [
                    if (_pages.length > 1)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_pages.length, (i) {
                          final isActive = i == _currentPage;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: isActive ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? primary : cardBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 58,
                      height: 58,
                      child: FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        child:
                            const Icon(Icons.arrow_forward_rounded, size: 25),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _finish,
                      child: Text('Already have an account? Sign in',
                          style: TextStyle(color: textSecondary, fontSize: 13)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingPageWidget extends StatelessWidget {
  final _OnboardingPage page;
  final bool isDark;
  const _OnboardingPageWidget({required this.page, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final iconColor = page.iconColor(isDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Large animated icon in glowing circle
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.08),
              border: Border.all(
                  color: iconColor.withValues(alpha: 0.25), width: 1.5),
              boxShadow: [
                BoxShadow(
                    color: iconColor.withValues(alpha: 0.18),
                    blurRadius: 50,
                    spreadRadius: 5),
              ],
            ),
            child: Icon(page.icon, size: 82, color: iconColor),
          )
              .animate()
              .scale(duration: 600.ms, curve: Curves.elasticOut)
              .fadeIn(duration: 400.ms),

          const SizedBox(height: 48),

          RichText(
            text: TextSpan(children: [
              TextSpan(
                text: 'Deep',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              TextSpan(
                text: 'Shield',
                style: TextStyle(
                  color: iconColor,
                  fontSize: 31,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
            ]),
            textAlign: TextAlign.center,
          )
              .animate()
              .fadeIn(delay: 200.ms)
              .slideY(begin: 0.3, end: 0, delay: 200.ms),

          const SizedBox(height: 10),

          Text(
            page.subtitle,
            style: TextStyle(
              color: textSecondary,
              fontSize: 15,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 72),
          Text(
            'A safer community for a more authentic digital world.',
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
