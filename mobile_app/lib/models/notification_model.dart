import 'package:equatable/equatable.dart';

/// Notification type
enum NotificationType { alert, scanComplete, suspicious, system, info }

extension NotificationTypeExt on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.alert:
        return 'Security Alert';
      case NotificationType.scanComplete:
        return 'Scan Complete';
      case NotificationType.suspicious:
        return 'Suspicious Activity';
      case NotificationType.system:
        return 'System';
      case NotificationType.info:
        return 'Info';
    }
  }

  static NotificationType fromString(String s) {
    switch (s.toLowerCase()) {
      case 'alert':
        return NotificationType.alert;
      case 'scan_complete':
        return NotificationType.scanComplete;
      case 'suspicious':
        return NotificationType.suspicious;
      case 'system':
        return NotificationType.system;
      default:
        return NotificationType.info;
    }
  }
}

/// Notification model
class NotificationModel extends Equatable {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final bool isRead;
  final DateTime createdAt;
  final Map<String, dynamic>? payload;

  const NotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.isRead = false,
    required this.createdAt,
    this.payload,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final actorName = actor?['name'] as String? ?? 'Someone';
    final kind = json['kind'] as String? ?? 'info';
    final message = switch (kind) {
      'like' => '$actorName liked your post.',
      'comment' => '$actorName commented on your post.',
      'follow' => '$actorName started following you.',
      _ => 'There is a new community update.',
    };
    return NotificationModel(
      id: json['id'] as String,
      type: NotificationTypeExt.fromString(kind),
      title: 'Community update',
      body: message,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      payload: {
        if (actor != null) 'actor': actor,
        if (json['post_id'] != null) 'post_id': json['post_id'],
      },
    );
  }

  NotificationModel copyWith({bool? isRead}) => NotificationModel(
        id: id,
        type: type,
        title: title,
        body: body,
        isRead: isRead ?? this.isRead,
        createdAt: createdAt,
        payload: payload,
      );

  @override
  List<Object?> get props => [id, type, title, body, isRead, createdAt];
}
