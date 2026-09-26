import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../core/widgets/ds_loading.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

/// Profile screen — user info, stats, and actions
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(profileProvider.notifier).loadProfile());
  }

  Future<void> _logout() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight)),
        title: Text('Sign Out',
            style: TextStyle(color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight, fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out of DeepShield?',
            style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sign Out', style: TextStyle(color: isDark ? AppColors.danger : AppColors.dangerLight))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
            pinned: false,
            title: Text('Profile',
                style: TextStyle(
                    color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            centerTitle: false,
            actions: [
              IconButton(
                icon: Icon(Icons.settings_rounded, color: textSecondary),
                onPressed: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 8),
            ],
          ),
          if (profileState is ProfileLoading)
            const SliverToBoxAdapter(child: DSLoading(message: 'Loading profile...'))
          else if (profileState is ProfileLoaded)
            _ProfileBody(user: profileState.user, onLogout: _logout, isDark: isDark)
          else
            SliverToBoxAdapter(
              child: Center(
                child: TextButton.icon(
                  onPressed: () => ref.read(profileProvider.notifier).loadProfile(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileBody extends StatelessWidget {
  final UserModel user;
  final VoidCallback onLogout;
  final bool isDark;
  const _ProfileBody({required this.user, required this.onLogout, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final success = isDark ? AppColors.success : AppColors.successLight;
    final danger = isDark ? AppColors.danger : AppColors.dangerLight;
    final primaryContainer = isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;
    final dangerContainer = isDark ? AppColors.dangerContainer : AppColors.dangerContainerLight;
    final warning = isDark ? AppColors.warning : AppColors.warningLight;
    
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── Avatar + Info ──────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                    boxShadow: [
                      BoxShadow(color: AppColors.primaryGlow, blurRadius: 20)
                    ],
                  ),
                  child: Center(
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .scale(duration: 500.ms, curve: Curves.elasticOut),

                const SizedBox(height: 16),

                Text(user.name,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700))
                    .animate().fadeIn(delay: 150.ms),

                const SizedBox(height: 4),

                Text(user.email,
                    style: TextStyle(color: textSecondary, fontSize: 14))
                    .animate().fadeIn(delay: 200.ms),

                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Score: ${user.authenticityScore}/100',
                    style: TextStyle(
                        color: primary, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ).animate().fadeIn(delay: 300.ms),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Stats row ──────────────────────────────────────────
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Total Scans', value: '${user.totalScans}', color: primary, isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Safe', value: '${user.safeScans}', color: success, isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(child: _StatCard(label: 'Fakes', value: '${user.fakeScans}', color: danger, isDark: isDark)),
            ],
          ).animate().fadeIn(delay: 350.ms),

          const SizedBox(height: 24),

          // ── Actions ────────────────────────────────────────────
          _ActionSection(title: 'Account', isDark: isDark, items: [
            _ActionItem(icon: Icons.edit_rounded, label: 'Edit Profile', color: primary, onTap: () {}),
            _ActionItem(icon: Icons.lock_outline_rounded, label: 'Change Password', color: warning, onTap: () {}),
          ]).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 16),

          _ActionSection(title: 'App', isDark: isDark, items: [
            _ActionItem(icon: Icons.picture_as_pdf_rounded, label: 'Generated Reports', color: textSecondary, onTap: () => context.push(AppRoutes.reports)),
            _ActionItem(icon: Icons.settings_rounded, label: 'Settings', color: textSecondary, onTap: () => context.push(AppRoutes.settings)),
            _ActionItem(icon: Icons.help_outline_rounded, label: 'Help & Support', color: textSecondary, onTap: () {}),
            _ActionItem(icon: Icons.info_outline_rounded, label: 'About DeepShield', color: textSecondary, onTap: () {}),
          ]).animate().fadeIn(delay: 500.ms),

          const SizedBox(height: 16),

          // Logout
          DSCard(
            onTap: onLogout,
            padding: const EdgeInsets.all(16),
            customBorder: Border.all(color: danger.withValues(alpha: 0.2)),
            child: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: dangerContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded, color: danger, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Sign Out',
                    style: TextStyle(
                        color: danger, fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ).animate().fadeIn(delay: 600.ms),
        ]),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  const _StatCard({required this.label, required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return DSCard(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  final String title;
  final List<_ActionItem> items;
  final bool isDark;
  const _ActionSection({required this.title, required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title,
              style: TextStyle(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, fontSize: 12, fontWeight: FontWeight.w600,
                  letterSpacing: 0.5)),
        ),
        DSCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((e) {
              final item = e.value;
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  InkWell(
                    onTap: item.onTap,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: item.color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(item.icon, color: item.color, size: 18),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(item.label,
                                style: TextStyle(
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight, size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(color: isDark ? AppColors.dividerDark : AppColors.dividerLight, height: 1, indent: 66),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionItem({required this.icon, required this.label, required this.color, required this.onTap});
}
