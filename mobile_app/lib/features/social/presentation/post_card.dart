import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/authenticated_avatar.dart';
import '../../../core/widgets/ds_card.dart';
import '../data/social_repository.dart';

class SocialPostCard extends StatelessWidget {
  final SocialPost post;
  final ValueChanged<bool> onLike;
  final ValueChanged<bool> onBookmark;
  final VoidCallback onComments;
  final VoidCallback onReport;
  final VoidCallback onBlock;

  const SocialPostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onBookmark,
    required this.onComments,
    required this.onReport,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final accent = isDark ? AppColors.primary : AppColors.primaryLight;
    final date = post.createdAt.toLocal();
    final age = DateTime.now().difference(date);
    final timestamp = age.inMinutes < 1
        ? 'now'
        : age.inHours < 1
            ? '${age.inMinutes}m'
            : age.inDays < 1
                ? '${age.inHours}h'
                : '${date.day}/${date.month}/${date.year}';

    return DSCard(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AuthenticatedAvatar(
                name: post.author.name,
                imageUrl: post.author.avatarUrl,
                radius: 19,
                backgroundColor: accent.withValues(alpha: 0.12),
                foregroundColor: accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.author.name,
                        style: TextStyle(
                            color: textPrimary, fontWeight: FontWeight.w700)),
                    Text(
                        '$timestamp${post.community == null ? '' : ' · ${post.community}'}',
                        style: TextStyle(color: textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                tooltip: 'Post actions',
                onSelected: (action) {
                  if (action == 'block') {
                    onBlock();
                  } else {
                    onReport();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'report', child: Text('Report post')),
                  PopupMenuItem(value: 'block', child: Text('Block creator')),
                ],
                icon: Icon(Icons.more_horiz_rounded, color: textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(post.body,
              style: TextStyle(color: textPrimary, fontSize: 15, height: 1.5)),
          if (post.media.isNotEmpty) ...[
            const SizedBox(height: 12),
            _PostMediaPreview(attachment: post.media.first),
          ],
          if (post.scanReport != null) ...[
            const SizedBox(height: 12),
            _ScanReportPreview(
              report: post.scanReport!,
              accent: accent,
              textPrimary: textPrimary,
              textSecondary: textSecondary,
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _PostAction(
                icon: post.liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '${post.likesCount}',
                color: post.liked ? AppColors.dangerLight : textSecondary,
                onTap: () => onLike(!post.liked),
              ),
              const SizedBox(width: 20),
              _PostAction(
                icon: Icons.mode_comment_outlined,
                label: '${post.commentsCount}',
                color: textSecondary,
                onTap: onComments,
              ),
              const SizedBox(width: 20),
              _PostAction(
                icon: Icons.ios_share_rounded,
                label: 'Share',
                color: textSecondary,
                onTap: () => _sharePost(context, post),
              ),
              const Spacer(),
              IconButton(
                tooltip: post.bookmarked ? 'Remove bookmark' : 'Bookmark post',
                onPressed: () => onBookmark(!post.bookmarked),
                icon: Icon(
                  post.bookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: post.bookmarked ? accent : textSecondary,
                  size: 21,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _sharePost(BuildContext context, SocialPost post) async {
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final shareOrigin =
      box == null ? null : box.localToGlobal(Offset.zero) & box.size;
  final reportNote = post.scanReport == null
      ? ''
      : '\n\nThis post includes an automated scan estimate. It is not proof of authenticity.';
  final text = '${post.author.name} on DeepShield:\n\n${post.body}$reportNote';
  final files = <XFile>[];
  final filenames = <String>[];

  if (post.media.isNotEmpty) {
    try {
      final attachment = post.media.first;
      final file = await SocialRepository().downloadPostMediaToTemp(attachment);
      final extension =
          file.uri.pathSegments.last.split('.').last.toLowerCase();
      final mimeType = attachment.mediaType == 'video'
          ? switch (extension) {
              'mov' => 'video/quicktime',
              'avi' => 'video/x-msvideo',
              'mkv' => 'video/x-matroska',
              'webm' => 'video/webm',
              _ => 'video/mp4',
            }
          : extension == 'png'
              ? 'image/png'
              : 'image/jpeg';
      final filename = file.uri.pathSegments.last;
      files.add(XFile(file.path, mimeType: mimeType, name: filename));
      filenames.add(filename);
    } catch (_) {
      if (context.mounted) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Media could not be attached; sharing the post text.'),
        ));
      }
    }
  }

  try {
    await SharePlus.instance.share(
      ShareParams(
        title: 'DeepShield post',
        text: text,
        files: files.isEmpty ? null : files,
        fileNameOverrides: files.isEmpty ? null : filenames,
        sharePositionOrigin: shareOrigin,
      ),
    );
  } catch (_) {
    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not open the system share sheet.'),
      ));
    }
  }
}

class _PostMediaPreview extends StatefulWidget {
  final SocialAttachment attachment;

  const _PostMediaPreview({required this.attachment});

  @override
  State<_PostMediaPreview> createState() => _PostMediaPreviewState();
}

class _PostMediaPreviewState extends State<_PostMediaPreview> {
  late final Future<Uint8List> _imageBytes;

  @override
  void initState() {
    super.initState();
    if (widget.attachment.mediaType == 'image') {
      _imageBytes = SocialRepository().getPostMedia(widget.attachment);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.attachment.mediaType == 'video') {
      return _PostVideoPreview(attachment: widget.attachment);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: FutureBuilder<Uint8List>(
          future: _imageBytes,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _mediaUnavailable(),
              );
            }
            if (snapshot.hasError) return _mediaUnavailable();
            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _mediaUnavailable() => Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined),
            const SizedBox(height: 6),
            Text(widget.attachment.filename,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      );
}

class _PostVideoPreview extends StatefulWidget {
  final SocialAttachment attachment;

  const _PostVideoPreview({required this.attachment});

  @override
  State<_PostVideoPreview> createState() => _PostVideoPreviewState();
}

class _PostVideoPreviewState extends State<_PostVideoPreview> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    VideoPlayerController? controller;
    try {
      final token = await StorageService.instance.getToken();
      final uri = Uri.parse('${ApiConstants.baseUrl}${widget.attachment.url}');
      controller = VideoPlayerController.networkUrl(
        uri,
        httpHeaders: token == null || token.isEmpty
            ? const {}
            : {'Authorization': 'Bearer $token'},
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (_loading) {
      return _videoFrame(const Center(child: CircularProgressIndicator()));
    }
    if (_failed || controller == null || !controller.value.isInitialized) {
      return _videoFrame(
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.videocam_off_outlined, size: 30),
            const SizedBox(height: 7),
            Text('Video preview unavailable',
                style: Theme.of(context).textTheme.bodySmall),
            Text(widget.attachment.filename,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      );
    }

    final ratio = controller.value.aspectRatio > 0
        ? controller.value.aspectRatio.clamp(0.6, 2.2).toDouble()
        : 16 / 10;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: ratio,
        child: Stack(
          alignment: Alignment.center,
          children: [
            VideoPlayer(controller),
            Material(
              color: Colors.black26,
              child: InkWell(
                onTap: () => setState(() {
                  controller.value.isPlaying
                      ? controller.pause()
                      : controller.play();
                }),
                child: Center(
                  child: Icon(
                    controller.value.isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded,
                    color: Colors.white,
                    size: 54,
                  ),
                ),
              ),
            ),
            Positioned(
              left: 10,
              right: 10,
              bottom: 7,
              child: VideoProgressIndicator(
                controller,
                allowScrubbing: true,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white54,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _videoFrame(Widget child) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: Container(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            alignment: Alignment.center,
            child: child,
          ),
        ),
      );
}

class _ScanReportPreview extends StatelessWidget {
  final Map<String, dynamic> report;
  final Color accent;
  final Color textPrimary;
  final Color textSecondary;

  const _ScanReportPreview({
    required this.report,
    required this.accent,
    required this.textPrimary,
    required this.textSecondary,
  });

  String _score(String key) {
    final value = report[key];
    return value is num ? '${(value * 100).toStringAsFixed(1)}%' : '—';
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = report['scan_type'] == 'video';
    final scoreLabel = isVideo
        ? 'Sampled video signal: ${_score('video_fake_score')}'
        : 'AI-generation: ${_score('ai_generation_score')}  ·  Face: ${_score('face_manipulation_score')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.fact_check_outlined, color: accent, size: 18),
            const SizedBox(width: 7),
            Text('User-shared scan summary',
                style: TextStyle(
                    color: textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 5),
          Text(report['target'] as String? ?? 'Media scan',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: textSecondary, fontSize: 12)),
          const SizedBox(height: 5),
          Text(
              '${report['prediction'] ?? 'Signal summary unavailable'}  ·  $scoreLabel',
              style:
                  TextStyle(color: textSecondary, fontSize: 11, height: 1.35)),
          const SizedBox(height: 6),
          Text('Automated model estimate, not proof of authenticity.',
              style: TextStyle(
                  color: textSecondary,
                  fontSize: 10,
                  fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }
}

class _PostAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PostAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ]),
        ),
      );
}

Future<String?> showPostReportDialog(
  BuildContext context, {
  String contentType = 'post',
}) =>
    showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Report $contentType'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final reason in const {
              'spam': 'Spam or misleading content',
              'harassment': 'Harassment or abuse',
              'misinformation': 'Potentially harmful misinformation',
              'other': 'Something else',
            }.entries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(reason.value),
                onTap: () => Navigator.pop(dialogContext, reason.key),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
