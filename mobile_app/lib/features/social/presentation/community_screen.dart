import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../core/widgets/ds_empty_state.dart';
import '../data/social_repository.dart';
import 'comments_sheet.dart';
import 'post_card.dart';
import 'post_composer.dart';

class CommunityScreen extends StatefulWidget {
  final String communityId;

  const CommunityScreen({super.key, required this.communityId});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final _repository = SocialRepository();
  late Future<SocialCommunity> _community;
  late Future<List<SocialPost>> _posts;
  String _sort = 'latest';

  @override
  void initState() {
    super.initState();
    _community = _loadCommunity();
    _posts = _repository.getCommunityFeed(widget.communityId, sort: _sort);
  }

  Future<SocialCommunity> _loadCommunity() async =>
      (await _repository.getCommunities())
          .firstWhere((item) => item.id == widget.communityId);

  void _refresh() {
    setState(() {
      _community = _loadCommunity();
      _posts = _repository.getCommunityFeed(widget.communityId, sort: _sort);
    });
  }

  Future<void> _createPost() async {
    final draft = await showSocialPostComposer(
      context,
      title: 'Start a discussion',
    );
    if (!mounted || draft == null) return;
    try {
      final postId = await _repository.createPost(
        draft.body,
        communityId: widget.communityId,
      );
      if (draft.media != null) {
        try {
          await _repository.uploadPostMedia(postId, draft.media!);
        } on DioException catch (error) {
          _refresh();
          _message(
              'Post published, but its attachment failed: ${DioClient.parseError(error)}');
          return;
        }
      }
      _refresh();
    } on DioException catch (error) {
      _message(DioClient.parseError(error));
    }
  }

  Future<void> _showComments(SocialPost post) =>
      showPostComments(context, _repository, post, onChanged: _refresh);

  void _message(String value) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(value)));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: FutureBuilder<SocialCommunity>(
          future: _community,
          builder: (_, snapshot) => Text(snapshot.data?.name ?? 'Community',
              style:
                  TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
        ),
        actions: [
          FutureBuilder<SocialCommunity>(
            future: _community,
            builder: (context, snapshot) {
              final community = snapshot.data;
              if (community == null) return const SizedBox.shrink();
              return TextButton(
                onPressed: () async {
                  try {
                    await _repository.setCommunityJoined(
                        community, !community.joined);
                    _refresh();
                  } on DioException catch (error) {
                    _message(DioClient.parseError(error));
                  }
                },
                child: Text(community.joined ? 'Joined' : 'Join',
                    style: TextStyle(color: accent)),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FutureBuilder<SocialCommunity>(
        future: _community,
        builder: (context, snapshot) => snapshot.data?.joined == true
            ? FloatingActionButton.extended(
                onPressed: _createPost,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Discuss'))
            : const SizedBox.shrink(),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 100),
          children: [
            FutureBuilder<SocialCommunity>(
              future: _community,
              builder: (context, snapshot) {
                final community = snapshot.data;
                if (community == null) return const SizedBox(height: 4);
                return Container(
                  height: 122,
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF063F9C), Color(0xFF087BFF)],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.18),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 2),
                        ),
                        child: const Icon(Icons.groups_rounded,
                            color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(community.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 5),
                            Text('${community.membersCount} members',
                                style: const TextStyle(
                                    color: Color(0xFFE6F1FF), fontSize: 12)),
                          ],
                        ),
                      ),
                      if (community.joined)
                        const Icon(Icons.verified_rounded,
                            color: Colors.white, size: 20),
                    ],
                  ),
                );
              },
            ),
            FutureBuilder<SocialCommunity>(
              future: _community,
              builder: (context, snapshot) {
                final community = snapshot.data;
                if (community == null) return const SizedBox(height: 8);
                return DSCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(community.description,
                            style:
                                TextStyle(color: textSecondary, height: 1.45)),
                        const SizedBox(height: 8),
                        Text('${community.membersCount} members',
                            style: TextStyle(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ]),
                );
              },
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(
                    value: 'latest',
                    label: Text('Latest'),
                    icon: Icon(Icons.schedule_rounded),
                  ),
                  ButtonSegment(
                    value: 'popular',
                    label: Text('Popular'),
                    icon: Icon(Icons.trending_up_rounded),
                  ),
                ],
                selected: {_sort},
                onSelectionChanged: (selection) {
                  setState(() {
                    _sort = selection.first;
                    _posts = _repository.getCommunityFeed(
                      widget.communityId,
                      sort: _sort,
                    );
                  });
                },
              ),
            ),
            const SizedBox(height: 16),
            Text('Discussions',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            FutureBuilder<List<SocialPost>>(
              future: _posts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return DSEmptyState(
                      icon: Icons.cloud_off_outlined,
                      title: 'Discussions unavailable',
                      subtitle: 'Check the backend connection and try again.',
                      actionLabel: 'Retry',
                      onAction: _refresh);
                }
                final posts = snapshot.data ?? const [];
                if (posts.isEmpty) {
                  return DSEmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No discussions yet',
                      subtitle:
                          'Join this community and start the first discussion.',
                      actionLabel: 'Explore communities',
                      onAction: _refresh);
                }
                return Column(children: [
                  for (final post in posts) ...[
                    SocialPostCard(
                      post: post,
                      onBlock: () async {
                        try {
                          await _repository.setUserBlocked(
                              post.author.id, true);
                          if (!mounted) return;
                          _message('${post.author.name} was blocked.');
                          _refresh();
                        } on DioException catch (error) {
                          if (mounted) {
                            _message(DioClient.parseError(error));
                          }
                        }
                      },
                      onReport: () async {
                        final reason = await showPostReportDialog(context);
                        if (!mounted || reason == null) return;
                        try {
                          await _repository.reportPost(post, reason);
                          _message('Report submitted for review.');
                        } on DioException catch (error) {
                          _message(DioClient.parseError(error));
                        }
                      },
                      onLike: (liked) async {
                        try {
                          await _repository.setLiked(post, liked);
                          _refresh();
                        } on DioException catch (error) {
                          _message(DioClient.parseError(error));
                        }
                      },
                      onBookmark: (saved) async {
                        try {
                          await _repository.setBookmarked(post, saved);
                          _refresh();
                        } on DioException catch (error) {
                          _message(DioClient.parseError(error));
                        }
                      },
                      onComments: () => _showComments(post),
                    ),
                    const SizedBox(height: 10),
                  ],
                ]);
              },
            ),
          ],
        ),
      ),
    );
  }
}
