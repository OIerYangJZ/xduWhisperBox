class UploadedImageItem {
  UploadedImageItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
    required this.moderationReason,
  });

  final String id;
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String status;
  final String moderationReason;

  bool get isApproved => status.toLowerCase() == 'approved';
  bool get isPending => status.toLowerCase() == 'pending';
  bool get isRisk => status.toLowerCase() == 'risk';

  factory UploadedImageItem.fromJson(Map<String, dynamic> json) {
    return UploadedImageItem(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      sizeBytes: _toInt(json['sizeBytes']) ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      moderationReason: (json['moderationReason'] ?? '').toString(),
    );
  }
}

int? _toInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}
