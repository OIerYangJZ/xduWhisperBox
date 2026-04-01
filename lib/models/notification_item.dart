class NotificationItem {
  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.content,
    required this.relatedType,
    required this.relatedId,
    required this.postId,
    required this.actorId,
    required this.actorAlias,
    required this.actorAvatarUrl,
    required this.createdAt,
    required this.timeText,
    required this.isRead,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String content;
  final String relatedType;
  final String relatedId;
  final String postId;
  final String actorId;
  final String actorAlias;
  final String actorAvatarUrl;
  final String createdAt;
  final String timeText;
  final bool isRead;
  final String readAt;

  String get displayTitle {
    final String normalizedType = type.trim().toLowerCase();
    final String normalizedRelatedType = relatedType.trim().toLowerCase();
    switch (normalizedType) {
      case 'like':
        if (normalizedRelatedType == 'comment') {
          return '喜欢了你的评论';
        }
        if (normalizedRelatedType == 'post') {
          return '喜欢了你的帖子';
        }
        return '喜欢了你的内容';
      case 'favorite':
        if (normalizedRelatedType == 'post' || normalizedRelatedType.isEmpty) {
          return '收藏了你的帖子';
        }
        return '收藏了你的内容';
      case 'reply':
        if (normalizedRelatedType == 'comment' || normalizedRelatedType.isEmpty) {
          return '回复了你的评论';
        }
        return '回复了你的内容';
      case 'comment':
        if (normalizedRelatedType == 'comment') {
          return '评论了你的评论';
        }
        if (normalizedRelatedType == 'post' || normalizedRelatedType.isEmpty) {
          return '评论了你的帖子';
        }
        return '评论了你的内容';
      case 'report_result':
        return title.trim().isNotEmpty ? title : '举报结果';
      case 'system':
      case 'system_announcement':
        return title.trim().isNotEmpty ? title : '系统公告';
      default:
        return title.trim().isNotEmpty ? title : '通知';
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    String _readString(List<String> keys, {String fallback = ''}) {
      for (final key in keys) {
        final value = json[key];
        if (value == null) continue;
        final text = value.toString();
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    final String readAt =
        _readString(<String>['readAt', 'read_at', 'readTime']);
    final String createdAt = _readString(
      <String>['createdAt', 'created_at', 'time', 'timestamp'],
    );

    return NotificationItem(
      id: _readString(<String>['id', 'notificationId', 'notification_id']),
      type: _readString(<String>['type', 'notificationType', 'notification_type'], fallback: 'system'),
      title: _readString(<String>['title']),
      content: _readString(<String>['content', 'message']),
      relatedType: _readString(<String>['relatedType', 'related_type']),
      relatedId: _readString(<String>['relatedId', 'related_id']),
      postId: _readString(<String>['postId', 'post_id']),
      actorId: _readString(<String>['actorId', 'actor_id']),
      actorAlias: _readString(<String>['actorAlias', 'actor_alias', 'nickname', 'fromAlias']),
      actorAvatarUrl: _readString(<String>[
        'actorAvatarUrl',
        'actor_avatar_url',
        'actorAvatar',
        'actor_avatar',
        'fromAvatarUrl',
        'from_avatar_url',
        'avatarUrl',
        'avatar_url',
        'avatar',
      ]),
      createdAt: createdAt,
      timeText: _readString(
        <String>['timeText', 'time_text', 'createdAt', 'created_at'],
      ),
      isRead: _toBool(json['isRead']) ?? readAt.trim().isNotEmpty,
      readAt: readAt,
    );
  }

  NotificationItem copyWith({
    bool? isRead,
    String? readAt,
  }) {
    return NotificationItem(
      id: id,
      type: type,
      title: title,
      content: content,
      relatedType: relatedType,
      relatedId: relatedId,
      postId: postId,
      actorId: actorId,
      actorAlias: actorAlias,
      actorAvatarUrl: actorAvatarUrl,
      createdAt: createdAt,
      timeText: timeText,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
    );
  }

  static bool? _toBool(dynamic value) {
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final String normalized = value.trim().toLowerCase();
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
