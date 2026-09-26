import 'package:equatable/equatable.dart';

/// User domain model
class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final int totalScans;
  final int safeScans;
  final int fakeScans;
  final int authenticityScore; // 0–100
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.totalScans = 0,
    this.safeScans = 0,
    this.fakeScans = 0,
    this.authenticityScore = 100,
    required this.createdAt,
  });

  /// Construct from API JSON response
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String,
        avatarUrl: json['avatar_url'] as String?,
        totalScans: (json['total_scans'] as int?) ?? 0,
        safeScans: (json['safe_scans'] as int?) ?? 0,
        fakeScans: (json['fake_scans'] as int?) ?? 0,
        authenticityScore: (json['authenticity_score'] as int?) ?? 100,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'total_scans': totalScans,
        'safe_scans': safeScans,
        'fake_scans': fakeScans,
        'authenticity_score': authenticityScore,
        'created_at': createdAt.toIso8601String(),
      };

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    int? totalScans,
    int? safeScans,
    int? fakeScans,
    int? authenticityScore,
    DateTime? createdAt,
  }) =>
      UserModel(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        totalScans: totalScans ?? this.totalScans,
        safeScans: safeScans ?? this.safeScans,
        fakeScans: fakeScans ?? this.fakeScans,
        authenticityScore: authenticityScore ?? this.authenticityScore,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Convenience getter
  int get warningScans => totalScans - safeScans - fakeScans;

  @override
  List<Object?> get props =>
      [id, name, email, avatarUrl, totalScans, safeScans, fakeScans, authenticityScore, createdAt];
}
