class DirectMessageItem {
  DirectMessageItem({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.timeText,
    required this.fromMe,
    required this.senderAlias,
    this.isRead = false,
    this.readAt = '',
    this.deliveryStatus = 'sent',
    this.serverCanRecall,
    this.replyToId,
    this.replyToSender,
    this.replyToContent,
  });

  final String id;
  final String content;
  final String createdAt;
  final String timeText;
  final bool fromMe;
  final String senderAlias;
  final bool isRead;
  final String readAt;
  final String deliveryStatus;
  final bool? serverCanRecall;

  /// 回复引用字段（可选）
  final String? replyToId;
  final String? replyToSender;
  final String? replyToContent;

  bool get hasReply =>
      replyToId != null && replyToContent != null && replyToContent!.isNotEmpty;

  bool get canRecall {
    if (!fromMe || deliveryStatus == 'failed') return false;
    if (serverCanRecall != null) return serverCanRecall!;
    final created = DateTime.tryParse(createdAt)?.toUtc();
    if (created == null) return false;
    return DateTime.now().toUtc().difference(created).inSeconds <= 120;
  }

  DirectMessageItem copyWith({
    String? id,
    String? content,
    String? createdAt,
    String? timeText,
    bool? fromMe,
    String? senderAlias,
    bool? isRead,
    String? readAt,
    String? deliveryStatus,
    bool? serverCanRecall,
    String? replyToId,
    String? replyToSender,
    String? replyToContent,
  }) {
    return DirectMessageItem(
      id: id ?? this.id,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      timeText: timeText ?? this.timeText,
      fromMe: fromMe ?? this.fromMe,
      senderAlias: senderAlias ?? this.senderAlias,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      serverCanRecall: serverCanRecall ?? this.serverCanRecall,
      replyToId: replyToId ?? this.replyToId,
      replyToSender: replyToSender ?? this.replyToSender,
      replyToContent: replyToContent ?? this.replyToContent,
    );
  }

  factory DirectMessageItem.fromJson(Map<String, dynamic> json) {
    final String readAt = (json['readAt'] ?? '').toString();
    final bool isRead = _toBool(json['isRead']) ?? readAt.trim().isNotEmpty;
    return DirectMessageItem(
      id: (json['id'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      timeText: (json['timeText'] ?? json['createdAt'] ?? '-').toString(),
      fromMe: _toBool(json['fromMe']) ?? false,
      senderAlias: (json['senderAlias'] ?? '匿名同学').toString(),
      isRead: isRead,
      readAt: readAt,
      deliveryStatus: (json['deliveryStatus'] ?? (isRead ? 'read' : 'sent'))
          .toString(),
      serverCanRecall: _toBool(json['canRecall']),
      replyToId: json['replyToId'] as String?,
      replyToSender: json['replyToSender'] as String?,
      replyToContent: json['replyToContent'] as String?,
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
