class PublicUserProfile {
  PublicUserProfile({
    required this.id,
    required this.nickname,
    required this.avatarUrl,
    required this.userLevelLabel,
    required this.postCount,
    required this.followingCount,
    required this.followerCount,
    required this.isFollowing,
    required this.canFollow,
    required this.canDirectMessage,
    this.bio = '',
    this.gender = '',
    this.backgroundImageUrl = '',
  });

  final String id;
  final String nickname;
  final String avatarUrl;
  final String userLevelLabel;
  final int postCount;
  final int followingCount;
  final int followerCount;
  final bool isFollowing;
  final bool canFollow;
  final bool canDirectMessage;
  final String bio;
  final String gender;
  final String backgroundImageUrl;

  /// 兼容旧代码，userId 映射到 id
  String get userId => id;

  factory PublicUserProfile.fromJson(Map<String, dynamic> json) {
    return PublicUserProfile(
      id: (json['id'] ?? json['userId'] ?? '').toString(),
      nickname: (json['nickname'] ?? json['alias'] ?? '匿名同学').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      userLevelLabel: (json['userLevelLabel'] ?? 'Lv.1').toString(),
      postCount: _toInt(json['postCount']) ?? 0,
      followingCount: _toInt(json['followingCount']) ?? 0,
      followerCount: _toInt(json['followerCount']) ?? 0,
      isFollowing: _toBool(json['isFollowing']) ?? false,
      canFollow: _toBool(json['canFollow']) ?? false,
      canDirectMessage: _toBool(json['canDirectMessage']) ?? false,
      bio: (json['bio'] ?? json['signature'] ?? '').toString(),
      gender: (json['gender'] ?? '').toString(),
      backgroundImageUrl:
          (json['backgroundImageUrl'] ?? json['backgroundImage'] ?? '')
              .toString(),
    );
  }

  PublicUserProfile copyWith({
    String? id,
    String? nickname,
    String? avatarUrl,
    String? userLevelLabel,
    int? postCount,
    int? followingCount,
    int? followerCount,
    bool? isFollowing,
    bool? canFollow,
    bool? canDirectMessage,
    String? bio,
    String? gender,
    String? backgroundImageUrl,
  }) {
    return PublicUserProfile(
      id: id ?? this.id,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      userLevelLabel: userLevelLabel ?? this.userLevelLabel,
      postCount: postCount ?? this.postCount,
      followingCount: followingCount ?? this.followingCount,
      followerCount: followerCount ?? this.followerCount,
      isFollowing: isFollowing ?? this.isFollowing,
      canFollow: canFollow ?? this.canFollow,
      canDirectMessage: canDirectMessage ?? this.canDirectMessage,
      bio: bio ?? this.bio,
      gender: gender ?? this.gender,
      backgroundImageUrl: backgroundImageUrl ?? this.backgroundImageUrl,
    );
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final String lowered = value.toLowerCase();
      if (lowered == 'true' || lowered == '1') return true;
      if (lowered == 'false' || lowered == '0') return false;
    }
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
