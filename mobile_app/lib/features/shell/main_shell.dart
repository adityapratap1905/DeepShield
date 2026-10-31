import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../routes/app_router.dart';

/// Five-tab shell for the DeepShield Social application.
class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  static const _tabs = [
    AppRoutes.home,
    AppRoutes.explore,
    AppRoutes.scan,
    AppRoutes.learn,
    AppRoutes.profile,
  ];

  static const _items = [
    _NavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home'),
    _NavItem(
        icon: Icons.explore_outlined,
        activeIcon: Icons.explore_rounded,
        label: 'Explore'),
    _NavItem(
        icon: Icons.document_scanner_outlined,
        activeIcon: Icons.document_scanner_rounded,
        label: 'Scan'),
    _NavItem(
        icon: Icons.menu_book_outlined,
        activeIcon: Icons.menu_book_rounded,
        label: 'Learn'),
    _NavItem(
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'Profile'),
  ];

  void _onTap(BuildContext context, int index) {
    HapticFeedback.selectionClick();
    context.go(_tabs[index]);
  }

  @override
  Widget build(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    var currentIndex = _tabs.indexWhere((tab) => path == tab);
    if (currentIndex < 0 && path.startsWith(AppRoutes.scan)) currentIndex = 2;
    if (currentIndex < 0 &&
        (path == AppRoutes.history || path == AppRoutes.notifications)) {
      currentIndex = 4;
    }
    if (currentIndex < 0) currentIndex = 0;

    return Scaffold(
      body: child,
      extendBody: true,
      bottomNavigationBar: _SocialBottomNav(
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

class _SocialBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _SocialBottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : Colors.white;
    final border =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final selected = index == currentIndex;
              return Expanded(
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: item.label,
                  child: InkWell(
                    onTap: () => onTap(index),
                    child: _NavItemView(
                      item: item,
                      selected: selected,
                      isDark: isDark,
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

class _NavItemView extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final bool isDark;

  const _NavItemView({
    required this.item,
    required this.selected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    final inactive =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final isScan = item.label == 'Scan';
    final activeIcon = selected ? item.activeIcon : item.icon;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isScan)
          Transform.translate(
            offset: const Offset(0, -8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Icon(activeIcon, size: 25, color: Colors.white),
            ),
          )
        else ...[
          Icon(activeIcon, size: 23, color: selected ? accent : inactive),
          const SizedBox(height: 3),
        ],
        Text(
          item.label,
          style: TextStyle(
            color: selected ? accent : inactive,
            fontSize: 10,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
