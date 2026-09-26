import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_snackbar.dart';
import '../../../core/widgets/ds_text_field.dart';
import '../../../routes/app_router.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).register(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated) context.go(AppRoutes.home);
      if (next is AuthError) {
        showDSSnackbar(context, message: next.message, type: DSSnackbarType.error);
        ref.read(authProvider.notifier).clearError();
      }
    });

    final isLoading = ref.watch(authProvider) is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: DSAuroraBackground(
        subtle: true,
        child: SafeArea(
          child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          color: AppColors.textSecondaryDark),
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    const SizedBox(height: 20),

                    // App icon + header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icons/app_icon.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 14),
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Deep',
                                style: TextStyle(
                                  color: AppColors.textPrimaryDark,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              TextSpan(
                                text: 'Shield',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ).animate().fadeIn(delay: 50.ms),

                    const SizedBox(height: 28),

                    // Header
                    const Text(
                      'Create account',
                      style: TextStyle(
                        color: AppColors.textPrimaryDark,
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.3, end: 0),

                    const SizedBox(height: 8),
                    Text(
                      'Join DeepShield — Detect. Protect. Defend.',
                      style: TextStyle(color: AppColors.textSecondaryDark.withValues(alpha: 0.8), fontSize: 14),
                    ).animate().fadeIn(delay: 200.ms),

                    const SizedBox(height: 36),

                    DSTextField(
                      label: 'Full Name',
                      hint: 'John Doe',
                      controller: _nameCtrl,
                      prefixIcon: Icons.person_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Name is required';
                        if (v.trim().length < 2) return 'Name must be at least 2 characters';
                        return null;
                      },
                    ).animate().fadeIn(delay: 250.ms),

                    const SizedBox(height: 18),

                    DSTextField(
                      label: 'Email Address',
                      hint: 'you@example.com',
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      prefixIcon: Icons.email_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Email is required';
                        if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$').hasMatch(v)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ).animate().fadeIn(delay: 300.ms),

                    const SizedBox(height: 18),

                    DSTextField(
                      label: 'Password',
                      hint: 'Min 8 characters',
                      controller: _passwordCtrl,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Password is required';
                        if (v.length < 8) return 'Password must be at least 8 characters';
                        return null;
                      },
                    ).animate().fadeIn(delay: 350.ms),

                    const SizedBox(height: 18),

                    DSTextField(
                      label: 'Confirm Password',
                      hint: '••••••••',
                      controller: _confirmCtrl,
                      obscureText: true,
                      prefixIcon: Icons.lock_outline_rounded,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _register(),
                      validator: (v) {
                        if (v != _passwordCtrl.text) return 'Passwords do not match';
                        return null;
                      },
                    ).animate().fadeIn(delay: 400.ms),

                    const SizedBox(height: 32),

                    DSButton(
                      label: 'Create Account',
                      onPressed: isLoading ? null : _register,
                      isLoading: isLoading,
                      isFullWidth: true,
                      leadingIcon: Icons.person_add_rounded,
                    ).animate().fadeIn(delay: 450.ms),

                    const SizedBox(height: 24),

                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Already have an account? ',
                              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14)),
                          GestureDetector(
                            onTap: () => context.go(AppRoutes.login),
                            child: const Text('Sign In',
                                style: TextStyle(
                                    color: AppColors.primary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: 500.ms),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
    );
  }
}
