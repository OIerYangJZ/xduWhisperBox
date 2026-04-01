class AppReleaseItem {
  AppReleaseItem({
    required this.platform,
    required this.versionName,
    required this.versionCode,
    required this.releaseNotes,
    required this.forceUpdate,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.sha256,
    required this.downloadUrl,
    required this.uploadedAt,
    required this.uploadedByUsername,
  });

  final String platform;
  final String versionName;
  final int versionCode;
  final String releaseNotes;
  final bool forceUpdate;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String sha256;
  final String downloadUrl;
  final String uploadedAt;
  final String uploadedByUsername;

  factory AppReleaseItem.fromJson(Map<String, dynamic> json) {
    int parseInt(dynamic value) {
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        return int.tryParse(value) ?? 0;
      }
      return 0;
    }

    bool parseBool(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final String normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    return AppReleaseItem(
      platform: (json['platform'] ?? 'android').toString(),
      versionName: (json['versionName'] ?? '').toString(),
      versionCode: parseInt(json['versionCode']),
      releaseNotes: (json['releaseNotes'] ?? '').toString(),
      forceUpdate: parseBool(json['forceUpdate']),
      fileName: (json['fileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      sizeBytes: parseInt(json['sizeBytes']),
      sha256: (json['sha256'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      uploadedAt: (json['uploadedAt'] ?? '').toString(),
      uploadedByUsername: (json['uploadedByUsername'] ?? '').toString(),
    );
  }
}
