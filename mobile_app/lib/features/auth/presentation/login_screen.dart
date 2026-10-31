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
import 'auth_mode_tabs.dart';

/// Login screen — email/password with aurora background and glassmorphism
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authProvider, (_, next) {
      if (next is AuthAuthenticated) context.go(AppRoutes.home);
      if (next is AuthError) {
        showDSSnackbar(context,
            message: next.message, type: DSSnackbarType.error);
        ref.read(authProvider.notifier).clearError();
      }
    });

    final authState = ref.watch(authProvider);
    final isLoading = authState is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
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
                  const SizedBox(height: 30),

                  // App icon image
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icons/app_icon.png',
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

                  const SizedBox(height: 32),

                  const Text('Welcome to',
                      style: TextStyle(
                          color: AppColors.textPrimaryLight, fontSize: 17)),
                  const SizedBox(height: 4),

                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Deep',
                          style: TextStyle(
                            color: AppColors.textPrimaryLight,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: 'Shield',
                          style: TextStyle(
                            color: AppColors.primaryLight,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.15, end: 0, delay: 100.ms),

                  const SizedBox(height: 8),

                  const Text(
                    'Detect. Discuss. Protect.',
                    style: TextStyle(
                      color: AppColors.textSecondaryLight,
                      fontSize: 14,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 24),
                  const AuthModeTabs(isLogin: true),
                  const SizedBox(height: 24),

                  DSTextField(
                    label: 'Email Address',
                    hint: 'you@example.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    prefixIcon: Icons.email_outlined,
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Email is required';
                      if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$')
                          .hasMatch(v)) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 300.ms),

                  const SizedBox(height: 14),

                  DSTextField(
                    label: 'Password',
                    hint: '••••••••',
                    controller: _passwordCtrl,
                    obscureText: true,
                    prefixIcon: Icons.lock_outline_rounded,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _login(),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Password is required';
                      return null;
                    },
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.push(AppRoutes.forgotPw),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                            color: AppColors.primaryLight, fontSize: 13),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 20),

                  DSButton(
                    label: 'Sign In',
                    onPressed: isLoading ? null : _login,
                    isLoading: isLoading,
                    isFullWidth: true,
                    leadingIcon: Icons.login_rounded,
                  ).animate().fadeIn(delay: 500.ms),

                  const SizedBox(height: 28),

                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text("Don't have an account? ",
                            style: TextStyle(
                                color: AppColors.textSecondaryLight,
                                fontSize: 14)),
                        GestureDetector(
                          onTap: () => context.go(AppRoutes.register),
                          child: const Text('Sign Up',
                              style: TextStyle(
                                  color: AppColors.primaryLight,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 700.ms),

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
