import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/network/dio_client.dart';
import '../../../models/scan_result_model.dart';

class SocialUser {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? bio;
  final int followersCount;
  final bool isFollowing;

  const SocialUser({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.bio,
    this.followersCount = 0,
    this.isFollowing = false,
  });

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
        id: json['id'] as String,
        name: json['name'] as String? ?? 'User',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        followersCount: json['followers_count'] as int? ?? 0,
        isFollowing: json['is_following'] as bool? ?? false,
      );
}

class SocialPost {
  final String id;
  final String body;
  final DateTime createdAt;
  final SocialUser author;
  final String? community;
  final int likesCount;
  final int commentsCount;
  final bool liked;
  final bool bookmarked;
  final Map<String, dynamic>? scanReport;
  final List<SocialAttachment> media;

  const SocialPost({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.author,
    required this.likesCount,
    required this.commentsCount,
    required this.liked,
    required this.bookmarked,
    this.scanReport,
    this.community,
    this.media = const [],
  });

  factory SocialPost.fromJson(Map<String, dynamic> json) => SocialPost(
        id: json['id'] as String,
        body: json['body'] as String,
        createdAt: DateTime.parse(json['created_at'] as String),
        author: SocialUser.fromJson(json['author'] as Map<String, dynamic>),
        community: json['community'] as String?,
        likesCount: json['likes_count'] as int? ?? 0,
        commentsCount: json['comments_count'] as int? ?? 0,
        liked: json['liked'] as bool? ?? false,
        bookmarked: json['bookmarked'] as bool? ?? false,
        scanReport: json['scan_report'] as Map<String, dynamic>?,
        media: (json['media'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(SocialAttachment.fromJson)
            .toList(),
      );
}

class SocialAttachment {
  final String id;
  final String mediaType;
  final String filename;
  final String url;

  const SocialAttachment({
    required this.id,
    required this.mediaType,
    required this.filename,
    required this.url,
  });

  factory SocialAttachment.fromJson(Map<String, dynamic> json) =>
      SocialAttachment(
        id: json['id'] as String,
        mediaType: json['media_type'] as String? ?? 'image',
        filename: json['filename'] as String? ?? 'Attachment',
        url: json['url'] as String,
      );
}

class SocialCommunity {
  final String id;
  final String name;
  final String description;
  final int membersCount;
  final bool joined;

  const SocialCommunity(
      {required this.id,
      required this.name,
      required this.description,
      required this.membersCount,
      required this.joined});

  factory SocialCommunity.fromJson(Map<String, dynamic> json) =>
      SocialCommunity(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        membersCount: json['members_count'] as int? ?? 0,
        joined: json['joined'] as bool? ?? false,
      );
}

class SocialRepository {
  Dio get _dio => DioClient.instance.dio;

  Future<List<SocialPost>> getFeed(String feed) async {
    final response = await _dio.get(
      ApiConstants.socialFeed,
      queryParameters: {'feed': feed.toLowerCase().replaceAll(' ', '_')},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid feed response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialPost.fromJson)
        .toList();
  }

  Future<String> createPost(String body, {String? communityId}) async {
    final response = await _dio.post(ApiConstants.socialPosts, data: {
      'body': body,
      if (communityId != null) 'community_id': communityId,
    });
    final data = response.data;
    if (data is! Map<String, dynamic> || data['id'] is! String) {
      throw const FormatException('Invalid create post response.');
    }
    return data['id'] as String;
  }

  Future<void> uploadPostMedia(String postId, File file) async {
    final filename =
        file.uri.pathSegments.isEmpty ? 'upload' : file.uri.pathSegments.last;
    await _dio.post(
      '${ApiConstants.socialPosts}/$postId/media',
      data: FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path, filename: filename),
      }),
    );
  }

  Future<Uint8List> getPostMedia(SocialAttachment attachment) async {
    final response = await _dio.get<List<int>>(
      '${ApiConstants.baseUrl}${attachment.url}',
      options: Options(responseType: ResponseType.bytes),
    );
    final bytes = response.data;
    if (bytes == null || bytes.isEmpty) {
      throw const FormatException('The media response was empty.');
    }
    return Uint8List.fromList(bytes);
  }

  Future<File> downloadPostMediaToTemp(SocialAttachment attachment) async {
    final originalName = attachment.filename.split('/').last.split('\\').last;
    final extensionIndex = originalName.lastIndexOf('.');
    final candidateExtension = extensionIndex >= 0
        ? originalName.substring(extensionIndex).toLowerCase()
        : '';
    const allowedExtensions = {
      '.jpg',
      '.jpeg',
      '.png',
      '.mp4',
      '.mov',
      '.avi',
      '.mkv',
      '.webm'
    };
    final extension = allowedExtensions.contains(candidateExtension)
        ? candidateExtension
        : attachment.mediaType == 'video'
            ? '.mp4'
            : '.jpg';
    final safeId = attachment.id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    if (safeId.isEmpty) {
      throw const FormatException('Invalid post media identifier.');
    }
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}${Platform.pathSeparator}'
        'deepshield_$safeId$extension';
    final file = File(path);
    await _dio.download(
      '${ApiConstants.baseUrl}${attachment.url}',
      file.path,
    );
    if (!await file.exists() || await file.length() == 0) {
      throw const FormatException('The post media download was empty.');
    }
    return file;
  }

  Future<void> setLiked(SocialPost post, bool liked) async {
    final path = '${ApiConstants.socialPosts}/${post.id}/like';
    if (liked) {
      await _dio.post(path);
    } else {
      await _dio.delete(path);
    }
  }

  Future<void> reportPost(SocialPost post, String reason) async {
    await _dio.post(
      '${ApiConstants.socialPosts}/${post.id}/report',
      data: {'reason': reason},
    );
  }

  Future<void> reportComment(String commentId, String reason) async {
    await _dio.post(
      '/social/comments/$commentId/report',
      data: {'reason': reason},
    );
  }

  Future<void> setUserBlocked(String userId, bool blocked) async {
    final path = '/users/$userId/block';
    if (blocked) {
      await _dio.post(path);
    } else {
      await _dio.delete(path);
    }
  }

  Future<List<SocialUser>> getBlockedUsers() async {
    final response = await _dio.get('/users/blocked');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid blocked users response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getModerationReports() async {
    final response = await _dio.get('/moderation/reports');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid moderation queue response.');
    }
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> reviewModerationReport(String reportId, String action) async {
    await _dio.post(
      '/moderation/reports/$reportId/review',
      data: {'action': action},
    );
  }

  Future<void> shareScanReport(ScanResultModel result) async {
    final sourcePath = result.sourceMediaPath;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw Exception('The original scanned file is not available to attach.');
    }
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('The original scanned file is no longer available.');
    }

    final response = await _dio.post(ApiConstants.shareScanReport, data: {
      'scan_result': result.toShareReportJson(),
    });
    final data = response.data;
    final post = data is Map<String, dynamic>
        ? data['post'] as Map<String, dynamic>?
        : null;
    final postId = post?['id'] as String?;
    if (postId == null || postId.isEmpty) {
      throw const FormatException('Invalid shared report response.');
    }
    try {
      await uploadPostMedia(postId, sourceFile);
    } on DioException {
      try {
        await _dio.delete('${ApiConstants.socialPosts}/$postId');
      } on DioException {
        // The share failure is still surfaced; cleanup can be retried separately.
      }
      rethrow;
    }
  }

  Future<void> setBookmarked(SocialPost post, bool bookmarked) async {
    final path = '${ApiConstants.socialPosts}/${post.id}/bookmark';
    if (bookmarked) {
      await _dio.post(path);
    } else {
      await _dio.delete(path);
    }
  }

  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final response =
        await _dio.get('${ApiConstants.socialPosts}/$postId/comments');
    final data = response.data;
    if (data is! List) return const [];
    return data.whereType<Map<String, dynamic>>().toList();
  }

  Future<void> addComment(
    String postId,
    String body, {
    String? parentCommentId,
  }) async {
    await _dio.post(
      '${ApiConstants.socialPosts}/$postId/comments',
      data: {
        'body': body,
        if (parentCommentId != null) 'parent_comment_id': parentCommentId,
      },
    );
  }

  Future<List<SocialCommunity>> getCommunities() async {
    final response = await _dio.get(ApiConstants.communities);
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid communities response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialCommunity.fromJson)
        .toList();
  }

  Future<List<SocialPost>> getMyPosts() async {
    final response = await _dio.get('/profiles/me/posts');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid profile posts response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialPost.fromJson)
        .toList();
  }

  Future<List<SocialPost>> getBookmarkedPosts() async {
    final response = await _dio.get('/social/bookmarks');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid saved posts response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialPost.fromJson)
        .toList();
  }

  Future<List<SocialCommunity>> getMyCommunities() async {
    final response = await _dio.get('/profiles/me/communities');
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid profile communities response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialCommunity.fromJson)
        .toList();
  }

  Future<List<SocialPost>> getCommunityFeed(
    String communityId, {
    String sort = 'latest',
  }) async {
    final response = await _dio.get(
      '/communities/$communityId/feed',
      queryParameters: {'sort': sort},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid community feed response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialPost.fromJson)
        .toList();
  }

  Future<void> setCommunityJoined(
      SocialCommunity community, bool joined) async {
    final path = '${ApiConstants.communities}/${community.id}/join';
    if (joined) {
      await _dio.post(path);
    } else {
      await _dio.delete(path);
    }
  }

  Future<List<SocialUser>> searchUsers(String query) async {
    final response =
        await _dio.get('/users/search', queryParameters: {'q': query});
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid user search response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialUser.fromJson)
        .toList();
  }

  Future<List<SocialPost>> searchPosts(String query) async {
    final response = await _dio.get(
      '/social/search',
      queryParameters: {'q': query},
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid post search response.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(SocialPost.fromJson)
        .toList();
  }

  Future<void> setFollowing(String userId, bool following) async {
    final path = '/users/$userId/follow';
    if (following) {
      await _dio.post(path);
    } else {
      await _dio.delete(path);
    }
  }
}
