import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/dio_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_card.dart';
import '../../social/data/social_repository.dart';

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  final _repository = SocialRepository();
  late Future<List<Map<String, dynamic>>> _reports;

  @override
  void initState() {
    super.initState();
    _reports = _repository.getModerationReports();
  }

  void _reload() =>
      setState(() => _reports = _repository.getModerationReports());

  Future<void> _review(Map<String, dynamic> report, String action) async {
    if (action == 'remove_content') {
      final kind = report['content_type'] == 'post' ? 'post' : 'comment';
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Remove this $kind?'),
          content: Text(
            'This permanently removes the $kind${kind == 'post' ? ' and its attached media' : ''} from the community.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text('Remove $kind'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    try {
      await _repository.reviewModerationReport(report['id'] as String, action);
      if (!mounted) return;
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(action == 'dismiss'
              ? 'Report dismissed.'
              : 'Reported content removed.'),
        ),
      );
    } on DioException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioClient.parseError(error))),
      );
    }
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

    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        title: Text('Moderation queue',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.w700)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _reports,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final message = snapshot.error is DioException
                  ? DioClient.parseError(snapshot.error as DioException)
                  : 'The moderation queue could not be loaded.';
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 180),
                  Center(child: Text(message, textAlign: TextAlign.center)),
                  Center(
                    child: TextButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              );
            }
            final reports = snapshot.data ?? const [];
            if (reports.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(28),
                children: [
                  const SizedBox(height: 120),
                  Icon(Icons.verified_user_outlined,
                      size: 42, color: textSecondary),
                  const SizedBox(height: 12),
                  Text('No reports need review',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('New community reports will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: textSecondary)),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final report = reports[index];
                final type =
                    report['content_type'] == 'post' ? 'Post' : 'Comment';
                return DSCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('$type · ${report['reason']}',
                                style: TextStyle(
                                    color: textPrimary,
                                    fontWeight: FontWeight.w700)),
                          ),
                          Text(report['author_name'] as String? ?? 'Unknown',
                              style: TextStyle(
                                  color: textSecondary, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(report['content'] as String? ?? '',
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: textPrimary, height: 1.4, fontSize: 14)),
                      if ((report['details'] as String?)?.isNotEmpty ==
                          true) ...[
                        const SizedBox(height: 8),
                        Text('Reporter note: ${report['details']}',
                            style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                                height: 1.35)),
                      ],
                      const SizedBox(height: 14),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _review(report, 'dismiss'),
                            child: const Text('Dismiss report'),
                          ),
                          FilledButton.tonal(
                            onPressed: () => _review(report, 'remove_content'),
                            child: Text('Remove $type'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
