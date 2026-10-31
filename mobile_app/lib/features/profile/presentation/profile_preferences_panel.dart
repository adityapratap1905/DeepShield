import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../data/profile_repository.dart';

class ProfilePreferencesPanel extends StatefulWidget {
  final ProfileRepository repository;

  const ProfilePreferencesPanel({
    super.key,
    required this.repository,
  });

  @override
  State<ProfilePreferencesPanel> createState() =>
      _ProfilePreferencesPanelState();
}

class _ProfilePreferencesPanelState extends State<ProfilePreferencesPanel> {
  AccountPreferences? _preferences;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await widget.repository.getAccountPreferences();
      if (!mounted) return;
      setState(() {
        _preferences = preferences;
        _loading = false;
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = DioClient.parseError(error);
        _loading = false;
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _save(String key, bool value) async {
    final previous = _preferences;
    if (previous == null || _saving) return;
    setState(() {
      _preferences = previous.withValue(key, value);
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updateAccountPreferences(
        {key: value},
      );
      if (mounted) setState(() => _preferences = updated);
    } on DioException catch (error) {
      if (mounted) {
        setState(() {
          _preferences = previous;
          _error = DioClient.parseError(error);
        });
      }
    } on FormatException catch (error) {
      if (mounted) {
        setState(() {
          _preferences = previous;
          _error = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    final preferences = _preferences;

    return DSCard(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _loading
          ? const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          : _error != null && preferences == null
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    Text(_error!, style: TextStyle(color: secondary)),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ]),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Text(_error!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12)),
                      ),
                    _PreferenceSwitch(
                      title: 'Show me in creator search',
                      subtitle:
                          'Your name and bio can appear in Explore search.',
                      value: preferences!.showInCreatorSearch,
                      accent: accent,
                      foreground: foreground,
                      secondary: secondary,
                      enabled: !_saving,
                      onChanged: (value) =>
                          _save('show_in_creator_search', value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    _PreferenceSwitch(
                      title: 'Likes',
                      subtitle: 'In-app alerts when someone likes your post.',
                      value: preferences.notifyLikes,
                      accent: accent,
                      foreground: foreground,
                      secondary: secondary,
                      enabled: !_saving,
                      onChanged: (value) => _save('notify_likes', value),
                    ),
                    _PreferenceSwitch(
                      title: 'Comments',
                      subtitle: 'In-app alerts when someone comments.',
                      value: preferences.notifyComments,
                      accent: accent,
                      foreground: foreground,
                      secondary: secondary,
                      enabled: !_saving,
                      onChanged: (value) => _save('notify_comments', value),
                    ),
                    _PreferenceSwitch(
                      title: 'Follows',
                      subtitle: 'In-app alerts when someone follows you.',
                      value: preferences.notifyFollows,
                      accent: accent,
                      foreground: foreground,
                      secondary: secondary,
                      enabled: !_saving,
                      onChanged: (value) => _save('notify_follows', value),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'These preferences affect in-app activity only. Email and push alerts are not configured.',
                          style: TextStyle(color: secondary, fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PreferenceSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final Color accent;
  final Color foreground;
  final Color secondary;
  final ValueChanged<bool> onChanged;

  const _PreferenceSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.accent,
    required this.foreground,
    required this.secondary,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: accent,
        title: Text(title,
            style: TextStyle(color: foreground, fontWeight: FontWeight.w600)),
        subtitle:
            Text(subtitle, style: TextStyle(color: secondary, fontSize: 12)),
      );
}
