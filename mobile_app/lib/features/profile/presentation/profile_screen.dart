import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/authenticated_avatar.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../core/widgets/ds_loading.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_router.dart';
import '../../auth/providers/auth_provider.dart';
import 'profile_content.dart';
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
        backgroundColor:
            isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isDark
                    ? AppColors.cardBorderDark
                    : AppColors.cardBorderLight)),
        title: Text('Sign Out',
            style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontWeight: FontWeight.w700)),
        content: Text('Are you sure you want to sign out of DeepShield Social?',
            style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel',
                  style: TextStyle(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text('Sign Out',
                  style: TextStyle(
                      color:
                          isDark ? AppColors.danger : AppColors.dangerLight))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(authProvider.notifier).logout();
      } catch (_) {
        // Local navigation should still complete if remote revocation fails.
      }
      if (mounted) context.go(AppRoutes.login);
    }
  }

  Future<void> _editProfile(UserModel user) async {
    final name = TextEditingController(text: user.name);
    final bio = TextEditingController(text: user.bio ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                maxLength: 80,
                decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 8),
            TextField(
                controller: bio,
                maxLength: 280,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Bio')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(
                  dialogContext, (name.text.trim(), bio.text.trim())),
              child: const Text('Save')),
        ],
      ),
    );
    name.dispose();
    bio.dispose();
    if (!mounted || result == null || result.$1.isEmpty) return;
    await ref
        .read(profileProvider.notifier)
        .updateProfile(result.$1, bio: result.$2);
  }

  Future<void> _changeAvatar() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
      );
      if (result == null || result.files.isEmpty || !mounted) return;
      final path = result.files.single.path;
      if (path == null) {
        throw Exception('This device did not provide the image file.');
      }
      final file = File(path);
      final size = await file.length();
      if (size == 0 || size > 5 * 1024 * 1024) {
        throw Exception('Choose a JPG or PNG smaller than 5 MB.');
      }
      await ref.read(profileRepositoryProvider).uploadAvatar(file);
      await ref.read(profileProvider.notifier).loadProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile photo updated.')),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioClient.parseError(error))),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

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
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
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
              const SliverToBoxAdapter(
                  child: DSLoading(message: 'Loading profile...'))
            else if (profileState is ProfileLoaded)
              _ProfileBody(
                  user: profileState.user,
                  onEditProfile: () => _editProfile(profileState.user),
                  onLogout: _logout,
                  onChangeAvatar: _changeAvatar,
                  isDark: isDark)
            else
              SliverToBoxAdapter(
                child: Center(
                  child: TextButton.icon(
                    onPressed: () =>
                        ref.read(profileProvider.notifier).loadProfile(),
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
  final VoidCallback onEditProfile;
  final VoidCallback onLogout;
  final VoidCallback onChangeAvatar;
  final bool isDark;
  const _ProfileBody(
      {required this.user,
      required this.onEditProfile,
      required this.onLogout,
      required this.onChangeAvatar,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final danger = isDark ? AppColors.danger : AppColors.dangerLight;
    final dangerContainer =
        isDark ? AppColors.dangerContainer : AppColors.dangerContainerLight;

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      sliver: SliverList(
        delegate: SliverChildListDelegate([
          // ── Avatar + Info ──────────────────────────────────────
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 2),
                    ),
                    child: AuthenticatedAvatar(
                      name: user.name,
                      imageUrl: user.avatarUrl,
                      radius: 38,
                      backgroundColor: primary.withValues(alpha: 0.1),
                      foregroundColor: primary,
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: primary,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onChangeAvatar,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(Icons.camera_alt_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ).animate().scale(duration: 400.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(user.email,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: textSecondary, fontSize: 12)),
                    if (user.bio?.isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(user.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: textSecondary,
                              fontSize: 12,
                              height: 1.35)),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // ── Stats row ──────────────────────────────────────────
          Row(
            children: [
              Expanded(
                  child: _StatCard(
                      label: 'Posts',
                      value: '${user.postsCount}',
                      isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: 'Followers',
                      value: '${user.followersCount}',
                      isDark: isDark)),
              const SizedBox(width: 12),
              Expanded(
                  child: _StatCard(
                      label: 'Following',
                      value: '${user.followingCount}',
                      isDark: isDark)),
            ],
          ).animate().fadeIn(delay: 350.ms),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onEditProfile,
            style: OutlinedButton.styleFrom(
              foregroundColor: textPrimary,
              side: BorderSide(
                  color: isDark
                      ? AppColors.cardBorderDark
                      : AppColors.cardBorderLight),
              minimumSize: const Size.fromHeight(44),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13)),
            ),
            child: const Text('Edit Profile'),
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'Scans saved on this device: ${user.totalScans} (${user.photoScans} photos, ${user.videoScans} videos)',
              style: TextStyle(color: textSecondary, fontSize: 12),
            ),
          ),

          const SizedBox(height: 24),
          const ProfileContent(),

          const SizedBox(height: 24),

          // ── Actions ────────────────────────────────────────────
          _ActionSection(title: 'App', isDark: isDark, items: [
            _ActionItem(
                icon: Icons.history_rounded,
                label: 'Scan history',
                color: textSecondary,
                onTap: () => context.push(AppRoutes.history)),
            _ActionItem(
                icon: Icons.notifications_none_rounded,
                label: 'Notifications',
                color: textSecondary,
                onTap: () => context.push(AppRoutes.notifications)),
            _ActionItem(
                icon: Icons.picture_as_pdf_rounded,
                label: 'Generated Reports',
                color: textSecondary,
                onTap: () => context.push(AppRoutes.reports)),
            _ActionItem(
                icon: Icons.settings_rounded,
                label: 'Settings',
                color: textSecondary,
                onTap: () => context.push(AppRoutes.settings)),
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
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: dangerContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.logout_rounded, color: danger, size: 20),
                ),
                const SizedBox(width: 14),
                Text('Sign Out',
                    style: TextStyle(
                        color: danger,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
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
  final bool isDark;
  const _StatCard(
      {required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                fontSize: 19,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label,
            style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                fontSize: 11)),
      ],
    );
  }
}

class _ActionSection extends StatelessWidget {
  final String title;
  final List<_ActionItem> items;
  final bool isDark;
  const _ActionSection(
      {required this.title, required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title,
              style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
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
                            width: 36,
                            height: 36,
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
                                    color: isDark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimaryLight,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500)),
                          ),
                          Icon(Icons.chevron_right_rounded,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              size: 18),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        height: 1,
                        indent: 66),
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
  const _ActionItem(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});
}
