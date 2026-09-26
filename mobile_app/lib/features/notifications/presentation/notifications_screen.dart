import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ds_aurora_background.dart';
import '../../../core/widgets/ds_empty_state.dart';
import '../../../core/widgets/ds_loading.dart';
import '../../../models/notification_model.dart';
import '../providers/notifications_provider.dart';

/// Notifications feed screen
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final background = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final primary = isDark ? AppColors.primary : AppColors.primaryLight;

    return Scaffold(
      backgroundColor: background,
      body: DSAuroraBackground(
        subtle: true,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              backgroundColor: Colors.transparent,
              pinned: true,
              title: Text('Notifications',
                  style: TextStyle(
                      color: textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              centerTitle: false,
              actions: [
                TextButton(
                  onPressed: () {},
                  child: Text('Mark all read',
                      style: TextStyle(color: primary, fontSize: 13)),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: notificationsAsync.when(
                loading: () => const SliverToBoxAdapter(
                    child: DSShimmerList(count: 5, cardHeight: 90)),
                error: (_, __) => SliverToBoxAdapter(
                  child: Center(
                    child: Text('Failed to load notifications.',
                        style: TextStyle(color: textSecondary)),
                  ),
                ),
                data: (notifications) {
                  if (notifications.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: DSEmptyState(
                        icon: Icons.notifications_off_rounded,
                        title: 'No Notifications',
                        subtitle: 'Security alerts and scan updates will appear here.',
                      ),
                    );
                  }

                  return SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => _NotificationCard(notification: notifications[i], isDark: isDark)
                          .animate()
                          .fadeIn(delay: Duration(milliseconds: i * 60))
                          .slideX(begin: 0.05, end: 0),
                      childCount: notifications.length,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final bool isDark;
  const _NotificationCard({required this.notification, required this.isDark});

  (Color, IconData) get _typeStyle {
    switch (notification.type) {
      case NotificationType.alert:
        return (isDark ? AppColors.danger : AppColors.dangerLight, Icons.warning_rounded);
      case NotificationType.scanComplete:
        return (isDark ? AppColors.success : AppColors.successLight, Icons.check_circle_rounded);
      case NotificationType.suspicious:
        return (isDark ? AppColors.warning : AppColors.warningLight, Icons.security_rounded);
      case NotificationType.system:
        return (isDark ? AppColors.primary : AppColors.primaryLight, Icons.update_rounded);
      case NotificationType.info:
        return (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight, Icons.info_rounded);
    }
  }

  String _formatTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final (color, icon) = _typeStyle;
    final isUnread = !notification.isRead;
    
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final textTertiary = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final cardBg = isDark ? AppColors.cardDark : AppColors.cardLight;
    final cardBorder = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUnread
              ? color.withValues(alpha: 0.05)
              : cardBg.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isUnread ? color.withValues(alpha: 0.25) : cardBorder,
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: 14,
                            fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                      if (isUnread)
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.body,
                    style: TextStyle(
                        color: textSecondary, fontSize: 13, height: 1.4, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatTime(notification.createdAt),
                    style: TextStyle(color: textTertiary, fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
