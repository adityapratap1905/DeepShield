import 'dart:io';

import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/services/storage_service.dart';
import '../../../models/scan_result_model.dart';
import '../../../models/user_model.dart';
import '../../history/data/history_repository.dart';

class AccountPreferences {
  final bool showInCreatorSearch;
  final bool notifyLikes;
  final bool notifyComments;
  final bool notifyFollows;

  const AccountPreferences({
    required this.showInCreatorSearch,
    required this.notifyLikes,
    required this.notifyComments,
    required this.notifyFollows,
  });

  factory AccountPreferences.fromJson(Map<String, dynamic> json) =>
      AccountPreferences(
        showInCreatorSearch: json['show_in_creator_search'] as bool? ?? true,
        notifyLikes: json['notify_likes'] as bool? ?? true,
        notifyComments: json['notify_comments'] as bool? ?? true,
        notifyFollows: json['notify_follows'] as bool? ?? true,
      );

  AccountPreferences withValue(String key, bool value) => switch (key) {
        'show_in_creator_search' => AccountPreferences(
            showInCreatorSearch: value,
            notifyLikes: notifyLikes,
            notifyComments: notifyComments,
            notifyFollows: notifyFollows),
        'notify_likes' => AccountPreferences(
            showInCreatorSearch: showInCreatorSearch,
            notifyLikes: value,
            notifyComments: notifyComments,
            notifyFollows: notifyFollows),
        'notify_comments' => AccountPreferences(
            showInCreatorSearch: showInCreatorSearch,
            notifyLikes: notifyLikes,
            notifyComments: value,
            notifyFollows: notifyFollows),
        'notify_follows' => AccountPreferences(
            showInCreatorSearch: showInCreatorSearch,
            notifyLikes: notifyLikes,
            notifyComments: notifyComments,
            notifyFollows: value),
        _ => this,
      };

  Map<String, bool> toJson() => {
        'show_in_creator_search': showInCreatorSearch,
        'notify_likes': notifyLikes,
        'notify_comments': notifyComments,
        'notify_follows': notifyFollows,
      };
}

class ProfileRepository {
  Dio get _dio => DioClient.instance.dio;

  Future<UserModel> getProfile() async {
    final response = await _dio.get(ApiConstants.myProfile);
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response.');
    }
    final profile = UserModel.fromJson(response.data as Map<String, dynamic>);
    final scans = await HistoryRepository().getHistory(page: 1, limit: 100);
    final photoScans =
        scans.where((item) => item.scanType == ScanType.file).length;
    final videoScans =
        scans.where((item) => item.scanType == ScanType.video).length;
    final user = profile.copyWith(
      totalScans: scans.length,
      photoScans: photoScans,
      videoScans: videoScans,
    );
    await StorageService.instance.saveUserInfo(
      name: user.name,
      email: user.email,
      id: user.id,
      createdAt: user.createdAt.toIso8601String(),
    );
    return user;
  }

  Future<UserModel> updateProfile(
      {required String name, String bio = ''}) async {
    final response = await _dio.patch(
      ApiConstants.myProfile,
      data: {'name': name.trim(), 'bio': bio.trim()},
    );
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid profile response.');
    }
    return getProfile();
  }

  Future<void> changePassword(
      {required String currentPassword, required String newPassword}) async {
    await _dio.post(ApiConstants.changePassword, data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  Future<void> uploadAvatar(File imageFile) async {
    final filename = imageFile.uri.pathSegments.isEmpty
        ? 'avatar.png'
        : imageFile.uri.pathSegments.last;
    await _dio.post(
      ApiConstants.uploadAvatar,
      data: FormData.fromMap({
        'file':
            await MultipartFile.fromFile(imageFile.path, filename: filename),
      }),
    );
  }

  Future<AccountPreferences> getAccountPreferences() async {
    final response = await _dio.get('/profiles/me/settings');
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid account settings response.');
    }
    return AccountPreferences.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AccountPreferences> updateAccountPreferences(
    Map<String, bool> changes,
  ) async {
    final response = await _dio.patch('/profiles/me/settings', data: changes);
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid account settings response.');
    }
    return AccountPreferences.fromJson(response.data as Map<String, dynamic>);
  }
}
