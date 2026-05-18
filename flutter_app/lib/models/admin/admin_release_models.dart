// Admin release publishing models

part of '../admin_models.dart';

class AdminAndroidRelease {
  AdminAndroidRelease({
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
    required this.objectKey,
    required this.uploadedAt,
    required this.uploadedBy,
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
  final String objectKey;
  final String uploadedAt;
  final String uploadedBy;
  final String uploadedByUsername;

  factory AdminAndroidRelease.fromJson(Map<String, dynamic> json) {
    return AdminAndroidRelease(
      platform: (json['platform'] ?? 'android').toString(),
      versionName: (json['versionName'] ?? '').toString(),
      versionCode: _toInt(json['versionCode']) ?? 0,
      releaseNotes: (json['releaseNotes'] ?? '').toString(),
      forceUpdate: _toBool(json['forceUpdate']) ?? false,
      fileName: (json['fileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      sizeBytes: _toInt(json['sizeBytes']) ?? 0,
      sha256: (json['sha256'] ?? '').toString(),
      downloadUrl: (json['downloadUrl'] ?? '').toString(),
      objectKey: (json['objectKey'] ?? '').toString(),
      uploadedAt: (json['uploadedAt'] ?? '').toString(),
      uploadedBy: (json['uploadedBy'] ?? '').toString(),
      uploadedByUsername: (json['uploadedByUsername'] ?? '').toString(),
    );
  }
}
