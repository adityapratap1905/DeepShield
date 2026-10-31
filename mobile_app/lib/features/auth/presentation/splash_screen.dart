import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';
import '../data/auth_repository.dart';

/// Lightweight launch screen while the saved session is checked.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_navigate);
  }

  Future<void> _navigate() async {
    final storage = StorageService.instance;
    if (!storage.isOnboardingDone) {
      if (mounted) context.go(AppRoutes.onboarding);
      return;
    }
    final hasSession = await AuthRepository().restoreSession();
    if (!mounted) return;
    context.go(hasSession ? AppRoutes.home : AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainerLight,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.primaryLight.withValues(alpha: 0.18)),
                ),
                child: const Icon(Icons.shield_rounded,
                    color: AppColors.primaryLight, size: 58),
              ),
              const SizedBox(height: 18),
              const Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Deep',
                      style: TextStyle(
                          color: AppColors.textPrimaryLight,
                          fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: 'Shield',
                      style: TextStyle(
                          color: AppColors.primaryLight,
                          fontWeight: FontWeight.w800)),
                ]),
                style: TextStyle(fontSize: 30, letterSpacing: -0.7),
              ),
              const SizedBox(height: 6),
              const Text(
                'Detect. Discuss. Protect.',
                style: TextStyle(
                  color: AppColors.textSecondaryLight,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primaryLight,
                ),
              ),
            ],
          ),
        ),
      );
}
