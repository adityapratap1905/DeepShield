import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

/// Bottom navigation shell that wraps all main tabs.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.scan,
    AppRoutes.history,
    AppRoutes.notifications,
    AppRoutes.profile,
  ];

  static const _items = [
    _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
    _NavItem(
        icon: Icons.document_scanner_outlined,
        activeIcon: Icons.document_scanner,
        label: 'Scan'),
    _NavItem(
        icon: Icons.timeline_outlined,
        activeIcon: Icons.timeline,
        label: 'Activity'),
    _NavItem(
        icon: Icons.notifications_outlined,
        activeIcon: Icons.notifications,
        label: 'Alerts'),
    _NavItem(
        icon: Icons.person_outline, activeIcon: Icons.person, label: 'You'),
  ];

  void _onTap(BuildContext context, int index) {
    HapticFeedback.lightImpact();
    if (index == 1) {
      _showScanBottomSheet(context);
      return;
    }
    context.go(_tabs[index]);
  }

  void _showScanBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _ScanBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final selectedIndex = _tabs.indexOf(location);
    final currentIndex = selectedIndex < 0 ? 0 : selectedIndex;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _DSBottomNav(
        currentIndex: currentIndex,
        items: _items,
        onTap: (index) => _onTap(context, index),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _DSBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _DSBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isActive = index == currentIndex;

              return Expanded(
                child: Semantics(
                  button: true,
                  selected: isActive,
                  label: item.label,
                  onTap: () => onTap(index),
                  child: ExcludeSemantics(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onTap(index),
                        child: _MinimalTabItem(
                          item: item,
                          isActive: isActive,
                          isDark: isDark,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MinimalTabItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final bool isDark;

  const _MinimalTabItem({
    required this.item,
    required this.isActive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final color = isActive ? primary : textTertiary;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isActive ? item.activeIcon : item.icon,
            key: ValueKey<bool>(isActive),
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 4),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
          ),
          child: Text(item.label),
        ),
        const SizedBox(height: 2),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: isActive ? primary : Colors.transparent,
            borderRadius: BorderRadius.circular(1.5),
          ),
        ),
      ],
    );
  }
}

class _ScanBottomSheet extends StatelessWidget {
  const _ScanBottomSheet();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Scan',
              style: TextStyle(
                  color: textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Select a method to scan for deepfakes.',
              style: TextStyle(color: textSecondary),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.link_rounded, color: AppColors.primary),
              title: Text('URL Scanner',
                  style: TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Paste a link to a video or image'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                context.push(AppRoutes.scanUrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner_rounded,
                  color: AppColors.success),
              title: Text('QR Scanner',
                  style: TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Scan a QR code to extract a link'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                context.push(AppRoutes.scanQr);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_file_rounded,
                  color: AppColors.warning),
              title: Text('Photo Scanner',
                  style: TextStyle(
                      color: textPrimary, fontWeight: FontWeight.w600)),
              subtitle: const Text('Upload a local JPG or PNG photo'),
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
                context.push(AppRoutes.scanFile);
              },
            ),
          ],
        ),
      ),
    );
  }
}
