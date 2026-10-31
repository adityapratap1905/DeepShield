import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../routes/app_router.dart';
import '../../social/data/social_repository.dart';

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  final _repository = SocialRepository();
  late Future<List<SocialPost>> _posts;
  late Future<List<SocialPost>> _saved;
  late Future<List<SocialCommunity>> _communities;
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _posts = _repository.getMyPosts();
    _saved = _repository.getBookmarkedPosts();
    _communities = _repository.getMyCommunities();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final foreground =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final secondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _ProfileTab(
                label: 'Posts',
                selected: _tab == 0,
                onTap: () => setState(() => _tab = 0)),
            _ProfileTab(
                label: 'Scan Reports',
                selected: _tab == 1,
                onTap: () => setState(() => _tab = 1)),
            _ProfileTab(
                label: 'Saved',
                selected: _tab == 2,
                onTap: () => setState(() => _tab = 2)),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<List<SocialPost>>(
          future: _tab == 2 ? _saved : _posts,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(26),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Column(children: [
                  Text('Could not load this section.',
                      style: TextStyle(color: secondary)),
                  TextButton.icon(
                    onPressed: () => setState(_reload),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry'),
                  ),
                ]),
              );
            }
            final all = snapshot.data ?? const <SocialPost>[];
            final items = _tab == 1
                ? all.where((post) => post.scanReport != null).toList()
                : all;
            if (items.isEmpty) {
              final message = switch (_tab) {
                1 => 'No scan reports have been shared yet.',
                2 => 'Saved posts will appear here.',
                _ => 'Your posts will appear here.',
              };
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(children: [
                  Icon(Icons.photo_library_outlined,
                      color: secondary, size: 30),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: secondary, fontSize: 13)),
                ]),
              );
            }
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) => _PostTile(
                post: items[index],
                accent: accent,
                secondary: secondary,
                foreground: foreground,
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(
            child: Text('Joined communities',
                style: TextStyle(
                    color: foreground,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          Icon(Icons.groups_2_outlined, color: accent, size: 20),
        ]),
        const SizedBox(height: 8),
        FutureBuilder<List<SocialCommunity>>(
          future: _communities,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(14),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return Text('Communities could not be loaded.',
                  style: TextStyle(color: secondary, fontSize: 13));
            }
            final communities = snapshot.data ?? const <SocialCommunity>[];
            if (communities.isEmpty) {
              return Text('Communities you join will appear here.',
                  style: TextStyle(color: secondary, fontSize: 13));
            }
            return Column(
              children: communities
                  .map((community) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.1),
                          child: Icon(Icons.groups_2_outlined, color: accent),
                        ),
                        title: Text(community.name,
                            style: TextStyle(
                                color: foreground,
                                fontWeight: FontWeight.w600)),
                        subtitle: Text('${community.membersCount} members',
                            style: TextStyle(color: secondary, fontSize: 12)),
                        trailing:
                            Icon(Icons.chevron_right_rounded, color: secondary),
                        onTap: () =>
                            context.push(AppRoutes.community(community.id)),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ProfileTab(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primary
        : AppColors.primaryLight;
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: selected ? accent : Colors.transparent, width: 2),
            ),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: selected ? accent : secondary,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
        ),
      ),
    );
  }
}

class _PostTile extends StatelessWidget {
  final SocialPost post;
  final Color accent;
  final Color secondary;
  final Color foreground;

  const _PostTile({
    required this.post,
    required this.accent,
    required this.secondary,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final attachment = post.media.isEmpty ? null : post.media.first;
    Widget content;
    if (attachment?.mediaType == 'image') {
      content =
          _PostImage(attachment: attachment!, repository: SocialRepository());
    } else if (attachment?.mediaType == 'video') {
      content = const Center(
        child: Icon(Icons.play_circle_outline_rounded,
            color: Colors.white, size: 34),
      );
    } else {
      content = Padding(
        padding: const EdgeInsets.all(9),
        child: Text(post.body,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600)),
      );
    }
    return Material(
      color: accent,
      borderRadius: BorderRadius.circular(9),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.author.name,
                      style: TextStyle(
                          color: foreground, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(post.body,
                      style: TextStyle(color: secondary, height: 1.45)),
                  if (post.scanReport != null) ...[
                    const SizedBox(height: 12),
                    Text('Includes a scan estimate',
                        style: TextStyle(
                            color: accent, fontWeight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [accent, const Color(0xFF1352A6)],
                ),
              ),
              child: content,
            ),
            if (attachment?.mediaType == 'video')
              Positioned(
                right: 5,
                top: 5,
                child: Icon(Icons.videocam_rounded,
                    color: Colors.white.withValues(alpha: 0.9), size: 17),
              ),
          ],
        ),
      ),
    );
  }
}

class _PostImage extends StatelessWidget {
  final SocialAttachment attachment;
  final SocialRepository repository;

  const _PostImage({required this.attachment, required this.repository});

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
        future: repository.getPostMedia(attachment),
        builder: (context, snapshot) => snapshot.hasData
            ? Image.memory(snapshot.data!, fit: BoxFit.cover)
            : const Center(
                child:
                    Icon(Icons.image_outlined, color: Colors.white70, size: 30),
              ),
      );
}
