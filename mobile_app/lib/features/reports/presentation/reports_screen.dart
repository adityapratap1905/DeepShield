import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_empty_state.dart';
import '../../../routes/app_router.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Reports',
          style: TextStyle(
              color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textSecondary),
          onPressed: () => context.pop(),
        ),
      ),
      body: DSAuroraBackground(
        subtle: true,
        child: DSEmptyState(
          icon: Icons.picture_as_pdf_outlined,
          title: 'Exportable reports are not available yet',
          subtitle:
              'Your completed scan details are saved in local scan history.',
          actionLabel: 'View scan history',
          onAction: () => context.go(AppRoutes.history),
        ),
      ),
    );
  }
}
