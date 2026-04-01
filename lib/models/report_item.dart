class ReportItem {
  ReportItem({
    required this.id,
    required this.target,
    required this.targetType,
    required this.targetId,
    required this.targetTitle,
    required this.reason,
    required this.description,
    required this.status,
    required this.result,
    required this.createdAt,
    required this.handledAt,
  });

  final String id;
  final String target;
  final String targetType;
  final String targetId;
  final String targetTitle;
  final String reason;
  final String description;
  final String status;
  final String result;
  final String createdAt;
  final String handledAt;

  factory ReportItem.fromJson(Map<String, dynamic> json) {
    final String targetType = (json['targetType'] ?? '').toString();
    final String targetId = (json['targetId'] ?? '').toString();
    final String fallbackTarget = targetType.isNotEmpty || targetId.isNotEmpty
        ? '$targetType: $targetId'
        : '-';
    return ReportItem(
      id: (json['id'] ?? json['reportId'] ?? '').toString(),
      target:
          (json['target'] ?? json['targetName'] ?? fallbackTarget).toString(),
      targetType: targetType,
      targetId: targetId,
      targetTitle: (json['targetTitle'] ?? '').toString(),
      reason: (json['reason'] ?? '-').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? json['result'] ?? '-').toString(),
      result: (json['result'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
    );
  }
}
