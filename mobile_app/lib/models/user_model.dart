import 'package:equatable/equatable.dart';

/// User domain model
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final String? bio;
  final int postsCount;
  final int followersCount;
  final int followingCount;
  final bool isFollowing;
  final bool isModerator;
  final int totalScans;
  final int photoScans;
  final int videoScans;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.bio,
    this.postsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.isFollowing = false,
    this.isModerator = false,
    this.totalScans = 0,
    this.photoScans = 0,
    this.videoScans = 0,
    required this.createdAt,
  });

  /// Construct from API JSON response
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        postsCount: json['posts_count'] as int? ?? 0,
        followersCount: json['followers_count'] as int? ?? 0,
        followingCount: json['following_count'] as int? ?? 0,
        isFollowing: json['is_following'] as bool? ?? false,
        isModerator: json['is_moderator'] as bool? ?? false,
        totalScans: (json['total_scans'] as int?) ?? 0,
        photoScans: (json['photo_scans'] as int?) ?? 0,
        videoScans: (json['video_scans'] as int?) ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'bio': bio,
        'posts_count': postsCount,
        'followers_count': followersCount,
        'following_count': followingCount,
        'is_following': isFollowing,
        'is_moderator': isModerator,
        'total_scans': totalScans,
        'photo_scans': photoScans,
        'video_scans': videoScans,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    String? bio,
    int? postsCount,
    int? followersCount,
    int? followingCount,
    bool? isFollowing,
    bool? isModerator,
    int? totalScans,
    int? photoScans,
    int? videoScans,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        bio: bio ?? this.bio,
        postsCount: postsCount ?? this.postsCount,
        followersCount: followersCount ?? this.followersCount,
        followingCount: followingCount ?? this.followingCount,
        isFollowing: isFollowing ?? this.isFollowing,
        isModerator: isModerator ?? this.isModerator,
        totalScans: totalScans ?? this.totalScans,
        photoScans: photoScans ?? this.photoScans,
        videoScans: videoScans ?? this.videoScans,
        createdAt: createdAt ?? this.createdAt,
      );

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        avatarUrl,
        bio,
        postsCount,
        followersCount,
        followingCount,
        isFollowing,
        isModerator,
        totalScans,
        photoScans,
        videoScans,
        createdAt
      ];
}
