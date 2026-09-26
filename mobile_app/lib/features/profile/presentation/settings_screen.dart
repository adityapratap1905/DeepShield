import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';
import '../providers/profile_provider.dart';

/// Settings screen — theme, notifications, privacy, about
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final success = isDark ? AppColors.success : AppColors.successLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    final danger = isDark ? AppColors.danger : AppColors.dangerLight;

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Settings',
            style: TextStyle(
                color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        centerTitle: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textSecondary),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: DSAuroraBackground(
        subtle: true,
        child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ── Appearance ──────────────────────────────────────────
          _SettingsSection(
            title: 'Appearance',
            isDark: isDark,
            children: [
              _SettingsTile(
                icon: Icons.dark_mode_rounded,
                label: 'Theme',
                isDark: isDark,
                trailing: _ThemeSegmentedControl(
                  current: themeMode,
                  onChanged: (m) => ref.read(themeProvider.notifier).setTheme(m),
                  isDark: isDark,
                ),
              ),
            ],
          ).animate().fadeIn(delay: 50.ms),

          const SizedBox(height: 16),

          // ── Notifications ────────────────────────────────────────
          _SettingsSection(
            title: 'Notifications',
            isDark: isDark,
            children: [
              _SwitchTile(
                icon: Icons.notifications_rounded,
                label: 'Push Notifications',
                value: true,
                color: primary,
                isDark: isDark,
                onChanged: (_) {},
              ),
              _SwitchTile(
                icon: Icons.warning_rounded,
                label: 'Deepfake Alerts',
                value: true,
                color: danger,
                isDark: isDark,
                onChanged: (_) {},
              ),
              _SwitchTile(
                icon: Icons.check_circle_rounded,
                label: 'Scan Completed',
                value: true,
                color: success,
                isDark: isDark,
                onChanged: (_) {},
              ),
            ],
          ).animate().fadeIn(delay: 100.ms),

          const SizedBox(height: 16),

          // ── Privacy & Security ───────────────────────────────────
          _SettingsSection(
            title: 'Privacy & Security',
            isDark: isDark,
            children: [
              _SwitchTile(
                icon: Icons.fingerprint_rounded,
                label: 'Biometric Login',
                value: false,
                color: warning,
                isDark: isDark,
                onChanged: (_) {},
              ),
              _SwitchTile(
                icon: Icons.analytics_rounded,
                label: 'Share Analytics',
                value: true,
                color: primary,
                isDark: isDark,
                onChanged: (_) {},
              ),
              _SettingsTile(
                icon: Icons.history_rounded,
                label: 'Clear Scan History',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right_rounded, color: textTertiary),
                onTap: () {},
                iconColor: warning,
              ),
            ],
          ).animate().fadeIn(delay: 150.ms),

          const SizedBox(height: 16),

          // ── About ────────────────────────────────────────────────
          _SettingsSection(
            title: 'About',
            isDark: isDark,
            children: [
              _SettingsTile(
                icon: Icons.info_outline_rounded,
                label: 'App Version',
                isDark: isDark,
                trailing: Text('1.0.0',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ),
              _SettingsTile(
                icon: Icons.description_rounded,
                label: 'Privacy Policy',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: textTertiary),
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.gavel_rounded,
                label: 'Terms & Conditions',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: textTertiary),
                onTap: () {},
              ),
              _SettingsTile(
                icon: Icons.star_rounded,
                label: 'Rate the App',
                isDark: isDark,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: textTertiary),
                onTap: () {},
                iconColor: warning,
              ),
            ],
          ).animate().fadeIn(delay: 200.ms),
          ],
        ),
      ),
    );
  }
}

// ── Helper Widgets ────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isDark;
  const _SettingsSection({required this.title, required this.children, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title,
              style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        DSCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: children.asMap().entries.map((e) {
              final isLast = e.key == children.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast)
                    Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight, height: 1, indent: 56),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool isDark;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.isDark,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight), size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final Color color;
  final void Function(bool) onChanged;
  final bool isDark;

  const _SwitchTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _SettingsTile(
      icon: icon,
      label: label,
      iconColor: color,
      isDark: isDark,
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        activeTrackColor: color.withValues(alpha: 0.2),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _ThemeSegmentedControl extends StatelessWidget {
  final AppThemeMode current;
  final void Function(AppThemeMode) onChanged;
  final bool isDark;
  const _ThemeSegmentedControl({required this.current, required this.onChanged, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: AppThemeMode.values.map((m) {
        final (icon, label) = switch (m) {
          AppThemeMode.dark   => (Icons.dark_mode_rounded, 'Dark'),
          AppThemeMode.light  => (Icons.light_mode_rounded, 'Light'),
          AppThemeMode.system => (Icons.brightness_auto_rounded, 'Auto'),
        };
        final isActive = m == current;
        final primary = isDark ? AppColors.primary : AppColors.primaryLight;
        final primaryContainer = isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
        final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
        
        return GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isActive ? primaryContainer : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? primary.withValues(alpha: 0.4) : Colors.transparent,
              ),
            ),
            child: Icon(icon,
                size: 18,
                color: isActive ? primary : textTertiary),
          ),
        );
      }).toList(),
    );
  }
}
