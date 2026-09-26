import '../../../models/notification_model.dart';

/// Notifications repository — pure local/mock implementation.
/// No backend required.
class NotificationsRepository {
  /// Returns an empty list. The provider already supplies mock notifications directly.
  Future<List<NotificationModel>> getNotifications() async {
    return [];
  }

  /// No-op: read state is managed locally in the provider.
  Future<void> markRead(String id) async {}

  /// No-op: read state is managed locally in the provider.
  Future<void> markAllRead() async {}
}
