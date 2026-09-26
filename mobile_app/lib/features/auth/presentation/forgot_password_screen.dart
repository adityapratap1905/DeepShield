import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_button.dart';
import '../../../core/widgets/ds_text_field.dart';
import '../../../routes/app_router.dart';
import '../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).forgotPassword(_emailCtrl.text.trim());
    setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authProvider) is AuthLoading;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondaryDark),
          onPressed: () => context.pop(),
        ),
      ),
      body: DSAuroraBackground(
        subtle: true,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _submitted ? _buildSuccess() : _buildForm(isLoading),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.warningContainer,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.lock_reset_rounded, color: AppColors.warning, size: 28),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),

          const SizedBox(height: 28),
          const Text(
            'Reset password',
            style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 30, fontWeight: FontWeight.w700),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 8),
          Text(
            "Enter your email and we'll send you a reset link.",
            style: TextStyle(color: AppColors.textSecondaryDark.withValues(alpha: 0.8), fontSize: 15, height: 1.5),
          ).animate().fadeIn(delay: 200.ms),

          const SizedBox(height: 36),

          DSTextField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.email_outlined,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.[a-z]{2,}$').hasMatch(v)) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 28),

          DSButton(
            label: 'Send Reset Link',
            onPressed: isLoading ? null : _submit,
            isLoading: isLoading,
            isFullWidth: true,
            leadingIcon: Icons.send_rounded,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.successContainer,
              border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
            ),
            child: const Icon(Icons.mark_email_read_rounded, color: AppColors.success, size: 48),
          ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          const Text(
            'Check your inbox',
            style: TextStyle(color: AppColors.textPrimaryDark, fontSize: 26, fontWeight: FontWeight.w700),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            "We've sent a password reset link to\n${_emailCtrl.text}",
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondaryDark, fontSize: 15, height: 1.6),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 36),
          DSButton(
            label: 'Back to Sign In',
            onPressed: () => context.go(AppRoutes.login),
            variant: DSButtonVariant.secondary,
            isFullWidth: true,
          ).animate().fadeIn(delay: 400.ms),
        ],
      ),
    );
  }
}
