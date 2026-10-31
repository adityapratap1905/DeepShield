import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((_) => NotificationsRepository());

/// Notifications list — auto-refreshes when invalidated
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  return ref.read(notificationsRepositoryProvider).getNotifications();
});

/// Unread count badge
final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(notificationsProvider);
  return notifs.when(
    data: (list) => list.where((n) => !n.isRead).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});
