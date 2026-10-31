import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../routes/app_router.dart';

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          backgroundColor: AppColors.backgroundLight,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_rounded,
                color: AppColors.textSecondaryLight),
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: DSCard(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(Icons.lock_reset_outlined,
                          color: AppColors.primaryLight, size: 30),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Password reset unavailable',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimaryLight,
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'This build does not send password reset emails yet. Contact support to recover your account.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.go(AppRoutes.login),
                        child: const Text('Back to sign in'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}
