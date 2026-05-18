// Admin system configuration models

part of '../admin_models.dart';

class AdminChannelTagData {
  AdminChannelTagData({
    required this.channels,
    required this.tags,
  });

  final List<String> channels;
  final List<String> tags;

  factory AdminChannelTagData.fromJson(Map<String, dynamic> json) {
    return AdminChannelTagData(
      channels: _toStringList(json['channels']),
      tags: _toStringList(json['tags']),
    );
  }
}

class AdminSystemConfig {
  AdminSystemConfig({
    required this.sensitiveWords,
    required this.postRateLimit,
    required this.commentRateLimit,
    required this.messageRateLimit,
    required this.imageMaxMb,
  });

  final List<String> sensitiveWords;
  final int postRateLimit;
  final int commentRateLimit;
  final int messageRateLimit;
  final int imageMaxMb;

  factory AdminSystemConfig.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> settings =
        (json['settings'] is Map<String, dynamic>)
            ? json['settings'] as Map<String, dynamic>
            : ((json['settings'] is Map)
                ? (json['settings'] as Map<dynamic, dynamic>).map(
                    (dynamic key, dynamic value) =>
                        MapEntry(key.toString(), value),
                  )
                : <String, dynamic>{});

    return AdminSystemConfig(
      sensitiveWords: _toStringList(json['sensitiveWords']),
      postRateLimit: _toInt(settings['postRateLimit']) ??
          _toInt(json['postRateLimit']) ??
          10,
      commentRateLimit: _toInt(settings['commentRateLimit']) ??
          _toInt(json['commentRateLimit']) ??
          30,
      messageRateLimit: _toInt(settings['messageRateLimit']) ??
          _toInt(json['messageRateLimit']) ??
          40,
      imageMaxMb:
          _toInt(settings['imageMaxMB']) ?? _toInt(json['imageMaxMB']) ?? 5,
    );
  }

  Map<String, dynamic> toRequestJson() {
    return <String, dynamic>{
      'sensitiveWords': sensitiveWords,
      'settings': <String, dynamic>{
        'postRateLimit': postRateLimit,
        'commentRateLimit': commentRateLimit,
        'messageRateLimit': messageRateLimit,
        'imageMaxMB': imageMaxMb,
      },
    };
  }
}

class AdminSystemAnnouncement {
  AdminSystemAnnouncement({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.timeText,
    required this.createdBy,
  });

  final String id;
  final String title;
  final String content;
  final String createdAt;
  final String timeText;
  final String createdBy;

  factory AdminSystemAnnouncement.fromJson(Map<String, dynamic> json) {
    return AdminSystemAnnouncement(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      timeText: (json['timeText'] ?? json['createdAt'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
    );
  }
}
