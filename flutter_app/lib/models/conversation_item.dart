class ConversationItem {
  ConversationItem({
    required this.id,
    required this.peerUserId,
    required this.name,
    required this.avatarUrl,
    required this.lastMessage,
    required this.timeText,
    this.unreadCount = 0,
    this.hasUnread = false,
    this.blockedByMe = false,
    this.blockedByPeer = false,
  });

  final String id;
  final String peerUserId;
  final String name;
  final String avatarUrl;
  final String lastMessage;
  final String timeText;
  final int unreadCount;
  final bool hasUnread;
  final bool blockedByMe;
  final bool blockedByPeer;

  bool get isBlocked => blockedByMe || blockedByPeer;

  factory ConversationItem.fromJson(Map<String, dynamic> json) {
    final int unreadCount = _toInt(
          json['unreadCount'] ?? json['unread_count'] ?? json['badgeCount'],
        ) ??
        0;
    return ConversationItem(
      id: (json['id'] ?? json['conversationId'] ?? '').toString(),
      peerUserId: (json['peerUserId'] ?? json['peer_user_id'] ?? '').toString(),
      name: (json['name'] ?? json['peerAlias'] ?? '匿名同学').toString(),
      avatarUrl: (json['avatarUrl'] ?? json['peerAvatarUrl'] ?? '').toString(),
      lastMessage:
          (json['lastMessage'] ?? json['contentPreview'] ?? '-').toString(),
      timeText: (json['timeText'] ?? json['time'] ?? json['updatedAt'] ?? '-')
          .toString(),
      unreadCount: unreadCount,
      hasUnread: _toBool(json['hasUnread']) ?? unreadCount > 0,
      blockedByMe: _toBool(json['blockedByMe']) ?? false,
      blockedByPeer: _toBool(json['blockedByPeer']) ?? false,
    );
  }

  ConversationItem copyWith({
    String? id,
    String? peerUserId,
    String? name,
    String? avatarUrl,
    String? lastMessage,
    String? timeText,
    int? unreadCount,
    bool? hasUnread,
    bool? blockedByMe,
    bool? blockedByPeer,
  }) {
    return ConversationItem(
      id: id ?? this.id,
      peerUserId: peerUserId ?? this.peerUserId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      timeText: timeText ?? this.timeText,
      unreadCount: unreadCount ?? this.unreadCount,
      hasUnread: hasUnread ?? this.hasUnread,
      blockedByMe: blockedByMe ?? this.blockedByMe,
      blockedByPeer: blockedByPeer ?? this.blockedByPeer,
    );
  }

  static int? _toInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.toLowerCase().trim();
      if (normalized == 'true' || normalized == '1') {
        return true;
      }
      if (normalized == 'false' || normalized == '0') {
        return false;
      }
    }
    return null;
  }
}
