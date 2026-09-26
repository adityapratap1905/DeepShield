import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

enum DSSnackbarType { success, error, warning, info }

/// Show a styled floating snackbar
void showDSSnackbar(
  BuildContext context, {
  required String message,
  DSSnackbarType type = DSSnackbarType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final (Color color, IconData icon) = switch (type) {
    DSSnackbarType.success => (AppColors.success, Icons.check_circle_rounded),
    DSSnackbarType.error   => (AppColors.danger, Icons.error_rounded),
    DSSnackbarType.warning => (AppColors.warning, Icons.warning_rounded),
    DSSnackbarType.info    => (AppColors.primary, Icons.info_rounded),
  };

  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: duration,
        backgroundColor: AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.4), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.textPrimaryDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: color,
                onPressed: onAction ?? () {},
              )
            : null,
      ),
    );
}
