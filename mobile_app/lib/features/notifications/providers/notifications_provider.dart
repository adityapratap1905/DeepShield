import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/notification_model.dart';
import '../data/notifications_repository.dart';

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((_) => NotificationsRepository());

/// Notifications list — auto-refreshes when invalidated
final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  await Future.delayed(const Duration(milliseconds: 500));

  // TODO: Replace with real API call
  // return ref.read(notificationsRepositoryProvider).getNotifications();

  final now = DateTime.now();
  return [
    NotificationModel(
      id: '1',
      type: NotificationType.alert,
      title: 'Phishing URL Detected',
      body: 'A URL you scanned (http://phishing-bank.com) was identified as a high-risk phishing site.',
      isRead: false,
      createdAt: now.subtract(const Duration(minutes: 5)),
    ),
    NotificationModel(
      id: '2',
      type: NotificationType.scanComplete,
      title: 'Scan Complete',
      body: 'Your video "interview.mp4" has been scanned successfully. No AI manipulation found.',
      isRead: false,
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    NotificationModel(
      id: '3',
      type: NotificationType.suspicious,
      title: 'Suspicious Activity',
      body: 'Multiple high-risk URLs were scanned from your account in the last hour.',
      isRead: true,
      createdAt: now.subtract(const Duration(hours: 5)),
    ),
    NotificationModel(
      id: '4',
      type: NotificationType.system,
      title: 'Model Updated',
      body: 'DeepShield AI model has been updated to v2.1 with improved phishing detection.',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    NotificationModel(
      id: '5',
      type: NotificationType.info,
      title: 'Weekly Authenticity Report',
      body: 'You scanned 42 media files this week. 3 deepfakes were detected.',
      isRead: true,
      createdAt: now.subtract(const Duration(days: 2)),
    ),
  ];
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
