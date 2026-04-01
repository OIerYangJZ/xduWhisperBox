class FollowUserItem {
  FollowUserItem({
    required this.userId,
    required this.nickname,
    required this.avatarUrl,
    this.isFollowing = false,
    this.isFollower = false,
  });

  final String userId;
  final String nickname;
  final String avatarUrl;
  final bool isFollowing;
  final bool isFollower;

  bool get isMutual => isFollowing && isFollower;

  factory FollowUserItem.fromJson(Map<String, dynamic> json) {
    return FollowUserItem(
      userId: (json['userId'] ?? json['id'] ?? '').toString(),
      nickname: (json['nickname'] ?? json['name'] ?? '匿名用户').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['avatar'] ?? '').toString(),
      isFollowing: (json['isFollowing'] ?? json['following'] ?? false) == true,
      isFollower: (json['isFollower'] ?? json['follower'] ?? false) == true,
    );
  }
}
