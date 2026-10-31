import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';

class AuthModeTabs extends StatelessWidget {
  final bool isLogin;

  const AuthModeTabs({super.key, required this.isLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          _ModeButton(
            label: 'Login',
            selected: isLogin,
            onTap: () => context.go(AppRoutes.login),
          ),
          _ModeButton(
            label: 'Sign Up',
            selected: !isLogin,
            onTap: () => context.go(AppRoutes.register),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor:
              selected ? AppColors.primaryLight : Colors.transparent,
          foregroundColor: selected ? Colors.white : AppColors.textPrimaryLight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        child: Text(label),
      ),
    );
  }
}
