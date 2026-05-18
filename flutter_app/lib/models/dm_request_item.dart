class DmRequestItem {
  DmRequestItem({
    required this.id,
    required this.fromAlias,
    required this.fromAvatarUrl,
    required this.reason,
    required this.timeText,
    required this.status,
    required this.statusLabel,
  });

  final String id;
  final String fromAlias;
  final String fromAvatarUrl;
  final String reason;
  final String timeText;
  final String status;
  final String statusLabel;

  factory DmRequestItem.fromJson(Map<String, dynamic> json) {
    return DmRequestItem(
      id: (json['id'] ?? json['requestId'] ?? '').toString(),
      fromAlias:
          (json['fromAlias'] ?? json['fromName'] ?? json['from'] ?? '匿名同学')
              .toString(),
      fromAvatarUrl:
          (json['fromAvatarUrl'] ?? json['avatarUrl'] ?? '').toString(),
      reason: (json['reason'] ?? json['message'] ?? '请求联系').toString(),
      timeText: (json['timeText'] ?? json['time'] ?? json['createdAt'] ?? '-')
          .toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? _statusLabel(json['status']))
          .toString(),
    );
  }

  static String _statusLabel(dynamic status) {
    final String normalized = (status ?? 'pending').toString().toLowerCase();
    switch (normalized) {
      case 'accepted':
        return '已同意';
      case 'rejected':
        return '已拒绝';
      case 'pending':
      default:
        return '待处理';
    }
  }
}
