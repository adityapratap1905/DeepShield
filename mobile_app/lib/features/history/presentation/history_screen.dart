import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_badge.dart';
import '../../../core/widgets/ds_card.dart';
import '../../../core/widgets/ds_empty_state.dart';
import '../../../core/widgets/ds_loading.dart';
import '../../../models/history_item_model.dart';
import '../../../models/scan_result_model.dart';
import '../../../routes/app_router.dart';
import '../providers/history_provider.dart';

/// Scan history screen with search, filter tabs, and swipe-to-delete
class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(historyFilterProvider);
    final historyAsync = ref.watch(historyProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardBorder =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: true,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) => [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              pinned: true,
              actions: [
                IconButton(
                  tooltip: 'Clear scan history',
                  icon: Icon(Icons.delete_sweep_outlined, color: textPrimary),
                  onPressed: _confirmClearHistory,
                ),
              ],
              title: Text('History',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              centerTitle: false,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(116),
                child: Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: TextField(
                        controller: _searchCtrl,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search photos...',
                          hintStyle:
                              TextStyle(color: textTertiary, fontSize: 14),
                          prefixIcon: Icon(Icons.search_rounded,
                              color: textTertiary, size: 20),
                          suffixIcon: _searchCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      color: textTertiary, size: 18),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    ref
                                        .read(historySearchProvider.notifier)
                                        .state = '';
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: cardBg.withValues(alpha: 0.6),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: cardBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: primary),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                        ),
                        onChanged: (v) =>
                            ref.read(historySearchProvider.notifier).state = v,
                      ),
                    ),

                    // Filter chips
                    SizedBox(
                      height: 40,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        children: HistoryFilter.values.map((f) {
                          final isActive = f == filter;
                          final (label, color) = switch (f) {
                            HistoryFilter.all => ('All', primary),
                            HistoryFilter.safe => (
                                'No strong signal',
                                isDark
                                    ? AppColors.success
                                    : AppColors.successLight
                              ),
                            HistoryFilter.dangerous => (
                                'Needs review',
                                isDark
                                    ? AppColors.danger
                                    : AppColors.dangerLight
                              ),
                          };
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => ref
                                  .read(historyFilterProvider.notifier)
                                  .state = f,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? color.withValues(alpha: 0.15)
                                      : cardBg.withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isActive
                                        ? color.withValues(alpha: 0.5)
                                        : cardBorder,
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: isActive
                                        ? color
                                        : (isDark
                                            ? AppColors.textSecondaryDark
                                            : AppColors.textSecondaryLight),
                                    fontSize: 13,
                                    fontWeight: isActive
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
          body: historyAsync.when(
            loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: DSShimmerList(count: 6, cardHeight: 80)),
            error: (_, __) => Center(
                child: Text('Failed to load history.',
                    style: TextStyle(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight))),
            data: (items) {
              if (items.isEmpty) {
                return DSEmptyState(
                  icon: Icons.history_rounded,
                  title: 'No History Yet',
                  subtitle:
                      'Your scan history will appear here after you run your first scan.',
                  actionLabel: 'Start Scanning',
                  onAction: () => context.push(AppRoutes.scanFile),
                );
              }

              return RefreshIndicator(
                color: primary,
                backgroundColor: cardBg,
                onRefresh: () => ref.refresh(historyProvider.future),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics()),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final item = items[i];
                    return Dismissible(
                      key: ValueKey(
                        '${item.id}_${item.scannedAt.microsecondsSinceEpoch}',
                      ),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.delete_outline_rounded,
                            color: isDark
                                ? AppColors.danger
                                : AppColors.dangerLight),
                      ),
                      onDismissed: (_) async {
                        await ref
                            .read(historyRepositoryProvider)
                            .deleteHistoryItem(item.id);
                        ref.invalidate(historyProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Scan removed from history.')),
                          );
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: item.resultData == null
                            ? null
                            : () => context.push(
                                  AppRoutes.scanResult,
                                  extra: ScanResultModel.fromJson(
                                    item.resultData!,
                                  ),
                                ),
                        child: _HistoryCard(item: item, isDark: isDark)
                            .animate()
                            .fadeIn(delay: Duration(milliseconds: i * 50))
                            .slideX(begin: 0.05, end: 0),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear scan history?'),
        content: const Text(
          'This removes scan results and small previews saved on this device. The original photos are not copied into history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear history'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(historyRepositoryProvider).clearAllHistory();
    ref.invalidate(historyProvider);
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryItemModel item;
  final bool isDark;
  const _HistoryCard({required this.item, required this.isDark});

  IconData get _typeIcon {
    switch (item.scanType) {
      case ScanType.url:
        return Icons.link_rounded;
      case ScanType.file:
        return Icons.insert_drive_file_rounded;
      case ScanType.video:
        return Icons.movie_rounded;
      case ScanType.qr:
        return Icons.qr_code_rounded;
    }
  }

  String get _typeLabel {
    switch (item.scanType) {
      case ScanType.url:
        return 'URL';
      case ScanType.file:
        return 'FILE';
      case ScanType.video:
        return 'VIDEO';
      case ScanType.qr:
        return 'QR';
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(dt);
  }

  (String, Color) get _photoStatus {
    final rawExtraData = item.resultData?['extra_data'];
    final extraData = rawExtraData is Map ? rawExtraData : const {};
    final aiPrediction = extraData['prediction'];
    final facePrediction = extraData['face_manipulation_prediction'];
    final hasSignal = aiPrediction == 'ai_generated' ||
        facePrediction == 'face_manipulation_signal';
    final hasNoFace = facePrediction == 'no_face_detected';
    final hasNoSignals = aiPrediction == 'no_ai_generation_signal' &&
        facePrediction == 'no_face_manipulation_signal';

    final label = item.resultData?['is_demo'] == true
        ? 'Demo'
        : hasSignal
            ? 'Signal found'
            : hasNoFace
                ? 'Inconclusive'
                : hasNoSignals
                    ? 'No strong signal'
                    : 'Review result';
    final color = item.resultData?['is_demo'] == true
        ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
        : hasSignal
            ? (isDark ? AppColors.danger : AppColors.dangerLight)
            : hasNoFace
                ? (isDark ? AppColors.warning : AppColors.warningLight)
                : hasNoSignals
                    ? (isDark ? AppColors.success : AppColors.successLight)
                    : (isDark ? AppColors.warning : AppColors.warningLight);

    return (label, color);
  }

  (String, Color) get _videoStatus {
    final rawExtraData = item.resultData?['extra_data'];
    final extraData = rawExtraData is Map ? rawExtraData : const {};
    final prediction = extraData['prediction'];
    if (prediction == 'FAKE') {
      return (
        'Signal found',
        isDark ? AppColors.danger : AppColors.dangerLight
      );
    }
    if (prediction == 'REAL') {
      return (
        'No strong signal',
        isDark ? AppColors.warning : AppColors.warningLight
      );
    }
    return (
      'Review result',
      isDark ? AppColors.warning : AppColors.warningLight
    );
  }

  Widget _statusBadge() {
    if (item.scanType == ScanType.video) {
      final (label, color) = _videoStatus;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 10, fontWeight: FontWeight.w700)),
      );
    }
    if (item.scanType != ScanType.file) {
      return DSBadge(threatLevel: item.threatLevel.name);
    }

    final (label, color) = _photoStatus;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threatColor = item.scanType == ScanType.file
        ? _photoStatus.$2
        : item.scanType == ScanType.video
            ? _videoStatus.$2
            : AppColors.threatColor(item.threatLevel.name);
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textTertiary =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;
    final primaryContainer =
        isDark ? AppColors.primaryContainer : AppColors.primaryContainerLight;

    return DSCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: threatColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: threatColor.withValues(alpha: 0.2)),
            ),
            child: item.thumbnailPath == null
                ? Icon(_typeIcon, color: threatColor, size: 22)
                : ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Image.file(
                      File(item.thumbnailPath!),
                      width: 44,
                      height: 44,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(_typeIcon, color: threatColor, size: 22),
                    ),
                  ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.target,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: primaryContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_typeLabel,
                          style: TextStyle(
                              color: primary,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text(_formatDate(item.scannedAt),
                        style: TextStyle(
                            color: textTertiary,
                            fontSize: 11,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _statusBadge(),
          const SizedBox(width: 2),
          Icon(Icons.chevron_right_rounded, color: textTertiary, size: 18),
        ],
      ),
    );
  }
}
