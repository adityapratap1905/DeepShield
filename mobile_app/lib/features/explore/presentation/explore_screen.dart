import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../core/widgets/authenticated_avatar.dart';
import '../../../features/learn/data/learning_content.dart';
import '../../../core/network/dio_client.dart';
import '../../../routes/app_router.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/comments_sheet.dart';
import '../../social/presentation/post_card.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  final _socialRepository = SocialRepository();
  late Future<List<SocialCommunity>> _communities;
  Future<List<SocialUser>>? _users;
  Future<List<SocialPost>>? _posts;
  Timer? _searchDebounce;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _communities = _socialRepository.getCommunities();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    setState(() {
      _query = value;
      _users = null;
      _posts = null;
    });
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _users = _socialRepository.searchUsers(query);
        _posts = _socialRepository.searchPosts(query);
      });
    });
  }

  void _refreshPostResults() {
    final query = _query.trim();
    if (query.length >= 2 && mounted) {
      setState(() => _posts = _socialRepository.searchPosts(query));
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _toggleLike(SocialPost post, bool liked) async {
    try {
      await _socialRepository.setLiked(post, liked);
      _refreshPostResults();
    } on DioException catch (error) {
      _message(DioClient.parseError(error));
    }
  }

  Future<void> _toggleBookmark(SocialPost post, bool bookmarked) async {
    try {
      await _socialRepository.setBookmarked(post, bookmarked);
      _refreshPostResults();
    } on DioException catch (error) {
      _message(DioClient.parseError(error));
    }
  }

  Future<void> _reportPost(SocialPost post) async {
    final reason = await showPostReportDialog(context);
    if (!mounted || reason == null) return;
    try {
      await _socialRepository.reportPost(post, reason);
      _message('Report submitted for review.');
    } on DioException catch (error) {
      _message(DioClient.parseError(error));
    }
  }

  Future<void> _blockCreator(SocialPost post) async {
    try {
      await _socialRepository.setUserBlocked(post.author.id, true);
      _message('${post.author.name} was blocked.');
      _refreshPostResults();
    } on DioException catch (error) {
      _message(DioClient.parseError(error));
    }
  }

  Future<void> _showComments(SocialPost post) =>
      showPostComments(context, _socialRepository, post,
          onChanged: _refreshPostResults);

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
    final query = _query.trim().toLowerCase();
    final articles = learningArticles.where((article) {
      return query.isEmpty ||
          article.title.toLowerCase().contains(query) ||
          article.category.toLowerCase().contains(query) ||
          article.summary.toLowerCase().contains(query);
    }).toList();

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('Explore',
            style: TextStyle(
                color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
          children: [
            Text(
                'Discover practical guides for checking media and staying safer online.',
                style: TextStyle(color: textSecondary, height: 1.45)),
            const SizedBox(height: 18),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search creators, posts, communities or guides',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            if (_query.trim().length >= 2) ...[
              Row(children: [
                Expanded(
                  child: Text('Posts',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
              ]),
              const SizedBox(height: 10),
              if (_posts == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                FutureBuilder<List<SocialPost>>(
                  future: _posts,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Post search is unavailable.',
                          style: TextStyle(color: textSecondary));
                    }
                    final posts = snapshot.data ?? const <SocialPost>[];
                    if (posts.isEmpty) {
                      return Text('No posts match this search.',
                          style: TextStyle(color: textSecondary));
                    }
                    return Column(children: [
                      for (final post in posts) ...[
                        SocialPostCard(
                          post: post,
                          onLike: (liked) => _toggleLike(post, liked),
                          onBookmark: (bookmarked) =>
                              _toggleBookmark(post, bookmarked),
                          onComments: () => _showComments(post),
                          onReport: () => _reportPost(post),
                          onBlock: () => _blockCreator(post),
                        ),
                        const SizedBox(height: 10),
                      ],
                    ]);
                  },
                ),
              const SizedBox(height: 12),
            ],
            if (_query.trim().length >= 2) ...[
              Text('Creators',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (_users == null)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                FutureBuilder<List<SocialUser>>(
                  future: _users,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator()));
                    }
                    if (snapshot.hasError) {
                      return Text('Creator search is unavailable.',
                          style: TextStyle(color: textSecondary));
                    }
                    final users = snapshot.data ?? const <SocialUser>[];
                    if (users.isEmpty) {
                      return Text('No creators match that search.',
                          style: TextStyle(color: textSecondary));
                    }
                    return Column(children: [
                      for (final creator in users) ...[
                        _CreatorCard(
                          creator: creator,
                          accent: accent,
                          textPrimary: textPrimary,
                          textSecondary: textSecondary,
                          onFollow: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await _socialRepository.setFollowing(
                                  creator.id, !creator.isFollowing);
                              if (mounted) {
                                setState(() => _users = _socialRepository
                                    .searchUsers(_query.trim()));
                              }
                            } catch (_) {
                              if (mounted) {
                                messenger.showSnackBar(const SnackBar(
                                    content: Text(
                                        'Could not update follow status.')));
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    ]);
                  },
                ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                    child: Text('Communities',
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700))),
                TextButton(
                    onPressed: () => setState(() =>
                        _communities = _socialRepository.getCommunities()),
                    child: const Text('Refresh')),
              ],
            ),
            FutureBuilder<List<SocialCommunity>>(
              future: _communities,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                      padding: EdgeInsets.all(18),
                      child: Center(child: CircularProgressIndicator()));
                }
                if (snapshot.hasError) {
                  return Text(
                      'Communities could not be loaded. Check the backend connection.',
                      style: TextStyle(color: textSecondary));
                }
                final communities = (snapshot.data ?? const <SocialCommunity>[])
                    .where((community) {
                  final query = _query.trim().toLowerCase();
                  return query.isEmpty ||
                      community.name.toLowerCase().contains(query) ||
                      community.description.toLowerCase().contains(query);
                });
                return Column(children: [
                  for (final community in communities) ...[
                    _CommunityCard(
                      community: community,
                      accent: accent,
                      textPrimary: textPrimary,
                      textSecondary: textSecondary,
                      onOpen: () =>
                          context.push(AppRoutes.community(community.id)),
                      onJoin: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _socialRepository.setCommunityJoined(
                              community, !community.joined);
                          if (mounted) {
                            setState(() => _communities =
                                _socialRepository.getCommunities());
                          }
                        } catch (_) {
                          if (mounted) {
                            messenger.showSnackBar(const SnackBar(
                                content: Text(
                                    'Could not update community membership.')));
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 9),
                  ],
                ]);
              },
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text('Topics and guides',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Text('${articles.length}',
                    style: TextStyle(color: textSecondary, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            if (articles.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 48),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded,
                        color: textSecondary, size: 34),
                    const SizedBox(height: 12),
                    Text('No guides match that search',
                        style: TextStyle(
                            color: textPrimary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text('Try another topic or keyword.',
                        style: TextStyle(color: textSecondary)),
                  ],
                ),
              )
            else
              for (final article in articles) ...[
                _GuideCard(
                  article: article,
                  accent: accent,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  onTap: () => context.go(
                    AppRoutes.learn,
                    extra: article.category,
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _CreatorCard extends StatelessWidget {
  final SocialUser creator;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onFollow;

  const _CreatorCard(
      {required this.creator,
      required this.accent,
      required this.textPrimary,
      required this.textSecondary,
      required this.onFollow});

  @override
  Widget build(BuildContext context) => DSCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          AuthenticatedAvatar(
            name: creator.name,
            imageUrl: creator.avatarUrl,
            radius: 20,
            backgroundColor: accent.withValues(alpha: 0.12),
            foregroundColor: accent,
          ),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(creator.name,
                    style: TextStyle(
                        color: textPrimary, fontWeight: FontWeight.w700)),
                Text(
                    '${creator.followersCount} followers${creator.bio?.isNotEmpty == true ? ' · ${creator.bio}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: textSecondary, fontSize: 11)),
              ])),
          TextButton(
              onPressed: onFollow,
              child: Text(creator.isFollowing ? 'Following' : 'Follow')),
        ]),
      );
}

class _CommunityCard extends StatelessWidget {
  final SocialCommunity community;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onOpen;
  final VoidCallback onJoin;

  const _CommunityCard(
      {required this.community,
      required this.accent,
      required this.textPrimary,
      required this.textSecondary,
      required this.onOpen,
      required this.onJoin});

  @override
  Widget build(BuildContext context) => DSCard(
        padding: const EdgeInsets.all(14),
        onTap: onOpen,
        child: Row(children: [
          Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(Icons.groups_2_outlined, color: accent)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(community.name,
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                    '${community.membersCount} members · ${community.description}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: textSecondary, fontSize: 11, height: 1.35)),
              ])),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onJoin,
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: Text(community.joined ? 'Joined' : 'Join'),
          ),
        ]),
      );
}

class _GuideCard extends StatelessWidget {
  final LearningArticle article;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;
  final VoidCallback onTap;

  const _GuideCard({
    required this.article,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => DSCard(
        onTap: onTap,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(article.icon, color: accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(article.category.toUpperCase(),
                      style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 4),
                  Text(article.title,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: textSecondary, fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: textSecondary),
          ],
        ),
      );
}
