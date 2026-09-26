import 'package:equatable/equatable.dart';

/// Notification type
enum NotificationType { alert, scanComplete, suspicious, system, info }

extension NotificationTypeExt on NotificationType {
  String get label {
    switch (this) {
      case NotificationType.alert:        return 'Security Alert';
      case NotificationType.scanComplete: return 'Scan Complete';
      case NotificationType.suspicious:   return 'Suspicious Activity';
      case NotificationType.system:       return 'System';
      case NotificationType.info:         return 'Info';
    }
  }

  static NotificationType fromString(String s) {
    switch (s.toLowerCase()) {
      case 'alert':         return NotificationType.alert;
      case 'scan_complete': return NotificationType.scanComplete;
      case 'suspicious':    return NotificationType.suspicious;
      case 'system':        return NotificationType.system;
      default:              return NotificationType.info;
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

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'] as String,
        type: NotificationTypeExt.fromString(json['type'] as String? ?? 'info'),
        title: json['title'] as String,
        body: json['body'] as String,
        isRead: json['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(json['created_at'] as String),
        payload: json['payload'] as Map<String, dynamic>?,
      );

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
