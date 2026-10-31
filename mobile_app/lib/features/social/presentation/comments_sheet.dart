import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../data/social_repository.dart';
import 'post_card.dart';

Future<void> showPostComments(
  BuildContext context,
  SocialRepository repository,
  SocialPost post, {
  VoidCallback? onChanged,
}) async {
  final controller = TextEditingController();
  var comments = repository.getComments(post.id);
  String? replyCommentId;
  String? replyAuthor;
  var sending = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 18,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(sheetContext).height * 0.62,
            child: Column(children: [
              Text('Discussion',
                  style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: comments,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton.icon(
                          onPressed: () => setSheetState(
                              () => comments = repository.getComments(post.id)),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Could not load comments. Retry'),
                        ),
                      );
                    }
                    final items = snapshot.data ?? const [];
                    if (items.isEmpty) {
                      return const Center(child: Text('Start the discussion.'));
                    }
                    return ListView(children: [
                      for (final comment in items)
                        _CommentTile(
                          comment: comment,
                          onReply: () {
                            final author = (comment['author']
                                        as Map<String, dynamic>?)?['name']
                                    as String? ??
                                'this creator';
                            setSheetState(() {
                              replyCommentId = comment['id'] as String?;
                              replyAuthor = author;
                            });
                          },
                          onReport: () async {
                            final reason = await showPostReportDialog(
                              sheetContext,
                              contentType: 'comment',
                            );
                            final id = comment['id'] as String?;
                            if (!sheetContext.mounted ||
                                reason == null ||
                                id == null) {
                              return;
                            }
                            try {
                              await repository.reportComment(id, reason);
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  const SnackBar(
                                    content:
                                        Text('Comment reported for review.'),
                                  ),
                                );
                              }
                            } on DioException catch (error) {
                              if (sheetContext.mounted) {
                                ScaffoldMessenger.of(sheetContext).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(DioClient.parseError(error))),
                                );
                              }
                            }
                          },
                        ),
                    ]);
                  },
                ),
              ),
              if (replyAuthor != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text('Replying to $replyAuthor',
                          style: Theme.of(sheetContext).textTheme.bodySmall),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      onPressed: () => setSheetState(() {
                        replyCommentId = null;
                        replyAuthor = null;
                      }),
                      icon: const Icon(Icons.close_rounded, size: 18),
                    ),
                  ]),
                ),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      hintText: replyAuthor == null
                          ? 'Write a comment'
                          : 'Write a reply',
                      counterText: '',
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: replyAuthor == null ? 'Send comment' : 'Send reply',
                  onPressed: sending
                      ? null
                      : () async {
                          final body = controller.text.trim();
                          if (body.isEmpty) return;
                          setSheetState(() => sending = true);
                          try {
                            await repository.addComment(
                              post.id,
                              body,
                              parentCommentId: replyCommentId,
                            );
                            controller.clear();
                            if (sheetContext.mounted) {
                              Navigator.pop(sheetContext);
                            }
                            onChanged?.call();
                          } on DioException catch (error) {
                            if (sheetContext.mounted) {
                              setSheetState(() => sending = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                    content: Text(DioClient.parseError(error))),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.send_rounded),
                ),
              ]),
            ]),
          ),
        ),
      ),
    ),
  );
  controller.dispose();
}

class _CommentTile extends StatelessWidget {
  final Map<String, dynamic> comment;
  final VoidCallback onReply;
  final VoidCallback onReport;

  const _CommentTile({
    required this.comment,
    required this.onReply,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    final author = comment['author'] as Map<String, dynamic>?;
    final name = author?['name'] as String? ?? 'User';
    final replyTo = comment['reply_to'] as String?;
    final isReply = comment['parent_comment_id'] != null;
    return Padding(
      padding: EdgeInsets.only(left: isReply ? 22 : 0),
      child: ListTile(
        contentPadding: const EdgeInsets.only(left: 4, right: 0),
        title: Text(
            isReply && replyTo != null ? '$name · replying to $replyTo' : name),
        subtitle: Text(comment['body'] as String? ?? ''),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (!isReply)
            IconButton(
              tooltip: 'Reply',
              onPressed: onReply,
              icon: const Icon(Icons.reply_rounded, size: 19),
            ),
          IconButton(
            tooltip: 'Report comment',
            onPressed: onReport,
            icon: const Icon(Icons.flag_outlined, size: 18),
          ),
        ]),
      ),
    );
  }
}
