import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/notification_model.dart';

class NotificationsRepository {
  Dio get _dio => DioClient.instance.dio;

  Future<List<NotificationModel>> getNotifications() async {
    final response = await _dio.get(ApiConstants.notifications);
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid notifications response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(NotificationModel.fromJson)
        .toList();
  }

  Future<void> markRead(String id) async {
    await _dio.post('${ApiConstants.notifications}/$id/read');
  }
}
