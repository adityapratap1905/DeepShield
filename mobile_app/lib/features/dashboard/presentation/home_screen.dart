import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/authenticated_avatar.dart';
import '../../../core/widgets/ds_card.dart';
import '../../learn/data/learning_content.dart';
import '../../social/data/social_repository.dart';
import '../../social/presentation/comments_sheet.dart';
import '../../social/presentation/post_card.dart';
import '../../social/presentation/post_composer.dart';
import '../../../routes/app_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _feedTabs = ['For You', 'Following', 'Trending'];
  final _repository = SocialRepository();
  String _selectedFeed = _feedTabs.first;
  late Future<List<SocialPost>> _feed;
  late Future<List<SocialCommunity>> _communities;

  @override
  void initState() {
    super.initState();
    _feed = _loadFeed();
    _communities = _loadCommunities();
  }

  Future<List<SocialPost>> _loadFeed() => _repository.getFeed(_selectedFeed);
  Future<List<SocialCommunity>> _loadCommunities() =>
      _repository.getCommunities();

  Future<void> _refresh() async {
    final nextFeed = _loadFeed();
    final nextCommunities = _loadCommunities();
    setState(() {
      _feed = nextFeed;
      _communities = nextCommunities;
    });
    try {
      await Future.wait([nextFeed, nextCommunities]);
    } catch (_) {
      // Each section renders its own retry state.
    }
  }

  Future<void> _createPost() async {
    final draft = await showSocialPostComposer(
      context,
      title: 'Create a post',
    );
    if (!mounted || draft == null) return;
    try {
      final postId = await _repository.createPost(draft.body);
      if (draft.media != null) {
        try {
          await _repository.uploadPostMedia(postId, draft.media!);
        } on DioException catch (error) {
          _refresh();
          _showMessage(
              'Post published, but its attachment failed: ${DioClient.parseError(error)}');
          return;
        }
      }
      _refresh();
    } on DioException catch (error) {
      _showMessage(DioClient.parseError(error));
    } catch (error) {
      _showMessage(error.toString());
    }
  }

  Future<void> _showComments(SocialPost post) =>
      showPostComments(context, _repository, post, onChanged: _refresh);

  void _openArticle(LearningArticle article) =>
      context.go(AppRoutes.learn, extra: article.category);

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

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
        titleSpacing: 20,
        title: RichText(
          text: TextSpan(children: [
            TextSpan(
                text: 'Deep',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6)),
            TextSpan(
                text: 'Shield',
                style: TextStyle(
                    color: accent,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6)),
          ]),
        ),
        actions: [
          IconButton(
              tooltip: 'Notifications',
              onPressed: () => context.push(AppRoutes.notifications),
              icon: Icon(Icons.notifications_none_rounded, color: textPrimary)),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              _WelcomeCard(
                accent: accent,
                onScan: () => context.push(AppRoutes.scan),
                onExplore: () => context.go(AppRoutes.explore),
              ),
              const SizedBox(height: 18),
              DSCard(
                onTap: _createPost,
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                child: Row(children: [
                  CircleAvatar(
                      radius: 18,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      child: Icon(Icons.add_rounded, color: accent, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Create a post',
                          style:
                              TextStyle(color: textSecondary, fontSize: 13))),
                  Icon(Icons.image_outlined, color: accent, size: 19),
                ]),
              ),
              const SizedBox(height: 22),
              _SectionHeading(
                title: 'Communities',
                action: 'Explore all',
                onAction: () => context.go(AppRoutes.explore),
              ),
              const SizedBox(height: 12),
              _CommunityStrip(
                communities: _communities,
                accent: accent,
                onRetry: _refresh,
                onSelected: (community) =>
                    context.push(AppRoutes.community(community.id)),
              ),
              const SizedBox(height: 22),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: Text('Community feed',
                        style: TextStyle(
                            color: textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5))),
                Icon(Icons.tune_rounded, color: textSecondary, size: 20),
              ]),
              const SizedBox(height: 14),
              _FeedSelector(
                tabs: _feedTabs,
                selected: _selectedFeed,
                isDark: isDark,
                accent: accent,
                onSelected: (tab) => setState(() {
                  _selectedFeed = tab;
                  _feed = _loadFeed();
                }),
              ),
              const SizedBox(height: 14),
              FutureBuilder<List<SocialPost>>(
                future: _feed,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(children: [
                      const _FeedStatusCard(
                        icon: Icons.forum_outlined,
                        title: 'Loading community posts',
                        subtitle: 'Your community feed is on the way.',
                        loading: true,
                      ),
                      const SizedBox(height: 18),
                      _EditorialFeedSection(
                        accent: accent,
                        onArticleTap: _openArticle,
                      ),
                    ]);
                  }
                  if (snapshot.hasError) {
                    return Column(children: [
                      _FeedStatusCard(
                        icon: Icons.cloud_off_outlined,
                        title: 'Community feed unavailable',
                        subtitle: snapshot.error is DioException
                            ? DioClient.parseError(
                                snapshot.error as DioException)
                            : snapshot.error.toString(),
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      ),
                      const SizedBox(height: 18),
                      _EditorialFeedSection(
                        accent: accent,
                        onArticleTap: _openArticle,
                      ),
                    ]);
                  }
                  final posts = snapshot.data ?? const [];
                  if (posts.isEmpty) {
                    return Column(children: [
                      _FeedStatusCard(
                        icon: Icons.forum_outlined,
                        title: _selectedFeed == 'Following'
                            ? 'Your following feed is empty'
                            : _selectedFeed == 'Trending'
                                ? 'No trending discussions yet'
                                : 'Start the first discussion',
                        subtitle:
                            'Share a question or safety insight with the community.',
                        actionLabel: 'Create a post',
                        onAction: _createPost,
                      ),
                      const SizedBox(height: 18),
                      _EditorialFeedSection(
                        accent: accent,
                        onArticleTap: _openArticle,
                      ),
                    ]);
                  }
                  return Column(children: [
                    _CreatorStrip(posts: posts, accent: accent),
                    const SizedBox(height: 12),
                    for (final post in posts) ...[
                      SocialPostCard(
                        post: post,
                        onBlock: () async {
                          try {
                            await _repository.setUserBlocked(
                                post.author.id, true);
                            if (!mounted) return;
                            _showMessage('${post.author.name} was blocked.');
                            _refresh();
                          } on DioException catch (error) {
                            if (mounted) {
                              _showMessage(DioClient.parseError(error));
                            }
                          }
                        },
                        onReport: () async {
                          final reason = await showPostReportDialog(context);
                          if (!mounted || reason == null) return;
                          try {
                            await _repository.reportPost(post, reason);
                            _showMessage('Report submitted for review.');
                          } on DioException catch (error) {
                            _showMessage(DioClient.parseError(error));
                          }
                        },
                        onLike: (liked) async {
                          try {
                            await _repository.setLiked(post, liked);
                            _refresh();
                          } on DioException catch (error) {
                            _showMessage(DioClient.parseError(error));
                          }
                        },
                        onBookmark: (saved) async {
                          try {
                            await _repository.setBookmarked(post, saved);
                            _refresh();
                          } on DioException catch (error) {
                            _showMessage(DioClient.parseError(error));
                          }
                        },
                        onComments: () => _showComments(post),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 10),
                    _EditorialFeedSection(
                      accent: accent,
                      onArticleTap: _openArticle,
                    ),
                  ]);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WelcomeCard extends StatelessWidget {
  final Color accent;
  final VoidCallback onScan;
  final VoidCallback onExplore;

  const _WelcomeCard({
    required this.accent,
    required this.onScan,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    return DSCard(
      padding: const EdgeInsets.all(18),
      borderRadius: 22,
      gradient: LinearGradient(
        colors: [accent, const Color(0xFF1747B8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      customBorder: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.shield_moon_outlined,
                size: 17, color: Colors.white70),
            const SizedBox(width: 7),
            Text(
              'YOUR SPACE FOR SMARTER SHARING',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ]),
          const SizedBox(height: 11),
          const Text(
            'Pause. Check. Share.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              height: 1.15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Explore media safety, learn together, and add your voice.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          Row(children: [
            FilledButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.document_scanner_outlined, size: 17),
              label: const Text('Scan media'),
              style: FilledButton.styleFrom(
                foregroundColor: const Color(0xFF1747B8),
                backgroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 9),
            TextButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.groups_2_outlined, size: 17),
              label: const Text('Explore'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String action;
  final VoidCallback onAction;

  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
          child: Text(title,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.25,
              )),
        ),
        TextButton(
          onPressed: onAction,
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 5),
          ),
          child: Text(action),
        ),
      ]);
}

class _CommunityStrip extends StatelessWidget {
  final Future<List<SocialCommunity>> communities;
  final Color accent;
  final VoidCallback onRetry;
  final ValueChanged<SocialCommunity> onSelected;

  const _CommunityStrip({
    required this.communities,
    required this.accent,
    required this.onRetry,
    required this.onSelected,
  });

  IconData _iconFor(String name) {
    final value = name.toLowerCase();
    if (value.contains('cyber')) return Icons.security_outlined;
    if (value.contains('safety')) return Icons.verified_user_outlined;
    if (value.contains('awareness')) return Icons.lightbulb_outline_rounded;
    if (value.contains('machine') || value.contains('ai')) {
      return Icons.auto_awesome_outlined;
    }
    if (value.contains('technology')) return Icons.devices_outlined;
    return Icons.movie_filter_outlined;
  }

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return FutureBuilder<List<SocialCommunity>>(
      future: communities,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(
            height: 96,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: accent),
              ),
            ),
          );
        }
        if (snapshot.hasError) {
          return DSCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.cloud_off_outlined, color: secondary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Community topics could not load.',
                    style: TextStyle(color: secondary, fontSize: 12)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ]),
          );
        }
        final items = snapshot.data ?? const <SocialCommunity>[];
        if (items.isEmpty) {
          return DSCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(children: [
              Icon(Icons.groups_outlined, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Community spaces are ready to explore.',
                    style: TextStyle(color: secondary, fontSize: 12)),
              ),
            ]),
          );
        }
        return SizedBox(
          height: 105,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final community = items[index];
              return SizedBox(
                width: 76,
                child: Semantics(
                  button: true,
                  label: 'Open ${community.name} community',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => onSelected(community),
                    child: Column(children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              accent.withValues(alpha: 0.16),
                              accent.withValues(alpha: 0.06),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                              color: accent.withValues(alpha: 0.25),
                              width: 1.2),
                        ),
                        child: Icon(_iconFor(community.name),
                            color: accent, size: 25),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        community.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 10,
                          height: 1.1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _FeedStatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool loading;

  const _FeedStatusCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return DSCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(children: [
        if (loading)
          const SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: secondary, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const SizedBox(height: 3),
            Text(subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: secondary, fontSize: 11, height: 1.3)),
          ]),
        ),
        if (actionLabel != null) ...[
          const SizedBox(width: 5),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 7)),
            child: Text(actionLabel!),
          ),
        ],
      ]),
    );
  }
}

class _EditorialFeedSection extends StatelessWidget {
  final Color accent;
  final ValueChanged<LearningArticle> onArticleTap;

  const _EditorialFeedSection({
    required this.accent,
    required this.onArticleTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('From DeepShield Learn',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 17,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text('Practical guides from the DeepShield team',
              style: TextStyle(color: secondary, fontSize: 12)),
        ]),
      ),
      for (final article in learningArticles) ...[
        _EditorialFeedPostCard(
          article: article,
          accent: accent,
          onTap: () => onArticleTap(article),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }
}

class _EditorialFeedPostCard extends StatelessWidget {
  final LearningArticle article;
  final Color accent;
  final VoidCallback onTap;

  const _EditorialFeedPostCard({
    required this.article,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return DSCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 39,
            height: 39,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [accent, const Color(0xFF1747B8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(Icons.shield_outlined,
                size: 21, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('DeepShield Learn',
                    style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.verified_rounded, color: accent, size: 15),
              ]),
              Text('Official guide  ·  ${article.readMinutes} min read',
                  style: TextStyle(color: textSecondary, fontSize: 11)),
            ]),
          ),
          Icon(Icons.more_horiz_rounded, color: textSecondary),
        ]),
        const SizedBox(height: 14),
        Text(article.title,
            style: TextStyle(
                color: textPrimary,
                fontSize: 17,
                height: 1.25,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2)),
        const SizedBox(height: 5),
        Text(article.summary,
            style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4)),
        const SizedBox(height: 12),
        Container(
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF102653), const Color(0xFF10182B)]
                  : [const Color(0xFFE5F0FF), const Color(0xFFF3F7FF)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(article.category.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: accent,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8)),
                  const SizedBox(height: 6),
                  Text('A little context goes a long way.',
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: isDark ? 0.19 : 0.1)),
              child: Icon(article.icon, color: accent, size: 32),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        Text(article.keyPoints.first,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textSecondary, fontSize: 12, height: 1.4)),
        const Divider(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.menu_book_outlined, size: 17),
            label: const Text('Read guide'),
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4)),
          ),
        ),
      ]),
    );
  }
}

class _CreatorStrip extends StatelessWidget {
  final List<SocialPost> posts;
  final Color accent;

  const _CreatorStrip({required this.posts, required this.accent});

  @override
  Widget build(BuildContext context) {
    final authors = <String, SocialPost>{};
    for (final post in posts) {
      authors.putIfAbsent(post.author.id, () => post);
    }
    final people = authors.values.take(8).toList();
    if (people.isEmpty) return const SizedBox.shrink();
    final secondary = Theme.of(context).colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Community voices',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: people.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final author = people[index].author;
              return SizedBox(
                width: 58,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: accent, width: 1.7),
                      ),
                      child: AuthenticatedAvatar(
                        name: author.name,
                        imageUrl: author.avatarUrl,
                        radius: 22,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        foregroundColor: accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(author.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: secondary, fontSize: 10)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FeedSelector extends StatelessWidget {
  final List<String> tabs;
  final String selected;
  final bool isDark;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _FeedSelector(
      {required this.tabs,
      required this.selected,
      required this.isDark,
      required this.accent,
      required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final border =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : Colors.white,
          border: Border.all(color: border),
          borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final tab in tabs)
          Expanded(
              child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => onSelected(tab),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                  color: tab == selected
                      ? accent.withValues(alpha: 0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10)),
              child: Text(tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: tab == selected ? accent : textSecondary,
                      fontSize: 13,
                      fontWeight:
                          tab == selected ? FontWeight.w700 : FontWeight.w500)),
            ),
          )),
      ]),
    );
  }
}
