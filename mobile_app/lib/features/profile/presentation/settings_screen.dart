import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../routes/app_router.dart';
import '../../history/data/history_repository.dart';
import '../../social/data/social_repository.dart';
import '../data/profile_repository.dart';
import 'profile_preferences_panel.dart';
import '../providers/profile_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final profileState = ref.watch(profileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          'Settings',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: textSecondary),
        ),
      ),
      body: DSAuroraBackground(
        subtle: true,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          children: [
            _SectionTitle('Appearance', color: textSecondary),
            DSCard(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SegmentedButton<AppThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: AppThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: AppThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.settings_suggest_outlined),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selection) => ref
                        .read(themeProvider.notifier)
                        .setTheme(selection.first),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Privacy & data', color: textSecondary),
            DSCard(
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear scan history?'),
                    content: const Text(
                      'This removes saved scan records and thumbnails from this device.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Clear history'),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await HistoryRepository().clearAllHistory();
                ref.invalidate(profileProvider);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scan history cleared.')),
                );
              },
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Clear scan history',
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Removes saved scans from this device',
                            style:
                                TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Privacy & notifications', color: textSecondary),
            ProfilePreferencesPanel(
              repository: ref.read(profileRepositoryProvider),
            ),
            const SizedBox(height: 24),
            _SectionTitle('Privacy & safety', color: textSecondary),
            DSCard(
              onTap: () => _showBlockedAccounts(context),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.block_outlined, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Blocked accounts',
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Review or unblock creators',
                            style:
                                TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (profileState is ProfileLoaded &&
                profileState.user.isModerator) ...[
              _SectionTitle('Moderation', color: textSecondary),
              DSCard(
                onTap: () => context.push(AppRoutes.moderation),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Review reports',
                              style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text('Triage community reports and remove content',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: textSecondary),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            _SectionTitle('Account', color: textSecondary),
            DSCard(
              onTap: () => _changePassword(
                context,
                ref.read(profileRepositoryProvider),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.lock_outline_rounded, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Change password',
                            style: TextStyle(
                                color: textPrimary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('Update your sign-in password',
                            style:
                                TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: textSecondary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SectionTitle('About', color: textSecondary),
            DSCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('DeepShield',
                        style: TextStyle(
                            color: textPrimary, fontWeight: FontWeight.w600)),
                  ),
                  Text(AppConstants.appVersion,
                      style: TextStyle(color: textSecondary, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _changePassword(
  BuildContext context,
  ProfileRepository repository,
) async {
  final current = TextEditingController();
  final next = TextEditingController();
  final confirm = TextEditingController();
  String? validationError;
  try {
    final values = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: current,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password'),
              ),
              TextField(
                controller: next,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'Use at least 8 characters.',
                ),
              ),
              TextField(
                controller: confirm,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirm new password'),
                onSubmitted: (_) {
                  _submitPasswordChange(
                    dialogContext,
                    setDialogState,
                    current,
                    next,
                    confirm,
                    (oldPassword, newPassword) => Navigator.pop(
                      dialogContext,
                      (oldPassword, newPassword),
                    ),
                    (message) => validationError = message,
                  );
                },
              ),
              if (validationError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    validationError!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitPasswordChange(
                dialogContext,
                setDialogState,
                current,
                next,
                confirm,
                (oldPassword, newPassword) => Navigator.pop(
                  dialogContext,
                  (oldPassword, newPassword),
                ),
                (message) => validationError = message,
              ),
              child: const Text('Save password'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || values == null) return;
    await repository.changePassword(
      currentPassword: values.$1,
      newPassword: values.$2,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed successfully.')),
    );
  } on DioException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(DioClient.parseError(error))),
    );
  } finally {
    current.dispose();
    next.dispose();
    confirm.dispose();
  }
}

Future<void> _showBlockedAccounts(BuildContext context) async {
  final repository = SocialRepository();
  var blockedUsers = repository.getBlockedUsers();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Blocked accounts'),
        content: SizedBox(
          width: 380,
          height: 360,
          child: FutureBuilder<List<SocialUser>>(
            future: blockedUsers,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: TextButton.icon(
                    onPressed: () => setDialogState(
                        () => blockedUsers = repository.getBlockedUsers()),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Could not load. Retry'),
                  ),
                );
              }
              final users = snapshot.data ?? const [];
              if (users.isEmpty) {
                return const Center(child: Text('No blocked accounts.'));
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(user.name),
                    subtitle: user.bio?.isNotEmpty == true
                        ? Text(user.bio!,
                            maxLines: 1, overflow: TextOverflow.ellipsis)
                        : null,
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await repository.setUserBlocked(user.id, false);
                          setDialogState(() {
                            blockedUsers = repository.getBlockedUsers();
                          });
                        } on DioException catch (error) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(DioClient.parseError(error))),
                          );
                        }
                      },
                      child: const Text('Unblock'),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    ),
  );
}

void _submitPasswordChange(
  BuildContext context,
  StateSetter setState,
  TextEditingController current,
  TextEditingController next,
  TextEditingController confirm,
  void Function(String current, String next) onSubmit,
  void Function(String message) saveError,
) {
  final currentValue = current.text;
  final nextValue = next.text;
  if (currentValue.isEmpty || nextValue.length < 8) {
    setState(() => saveError(
        'Enter the current password and a new one with at least 8 characters.'));
    return;
  }
  if (nextValue != confirm.text) {
    setState(() => saveError('The new passwords do not match.'));
    return;
  }
  if (nextValue == currentValue) {
    setState(
        () => saveError('Choose a password different from the current one.'));
    return;
  }
  onSubmit(currentValue, nextValue);
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionTitle(this.title, {required this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1),
        ),
      );
}
