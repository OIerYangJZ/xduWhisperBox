// Admin content review models

part of '../admin_models.dart';

class AdminReviewItem {
  AdminReviewItem({
    required this.id,
    required this.targetType,
    required this.title,
    required this.content,
    required this.authorAlias,
    required this.authorUserId,
    required this.authorNickname,
    required this.authorEmail,
    required this.authorStudentId,
    required this.createdAt,
    required this.reviewStatus,
    required this.riskMarked,
  });

  final String id;
  final String targetType;
  final String title;
  final String content;
  final String authorAlias;
  final String authorUserId;
  final String authorNickname;
  final String authorEmail;
  final String authorStudentId;
  final String createdAt;
  final String reviewStatus;
  final bool riskMarked;

  factory AdminReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminReviewItem(
      id: (json['id'] ?? '').toString(),
      targetType: (json['targetType'] ?? 'post').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      authorAlias: (json['authorAlias'] ?? '匿名同学').toString(),
      authorUserId: (json['authorUserId'] ?? '').toString(),
      authorNickname:
          (json['authorNickname'] ?? json['authorAlias'] ?? '匿名同学').toString(),
      authorEmail: (json['authorEmail'] ?? '').toString(),
      authorStudentId: (json['authorStudentId'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      reviewStatus: (json['reviewStatus'] ?? 'pending').toString(),
      riskMarked: _toBool(json['riskMarked']) ?? false,
    );
  }
}

class AdminImageReviewItem {
  AdminImageReviewItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.status,
    required this.moderationReason,
    required this.reviewNote,
    required this.createdAt,
    required this.postId,
    required this.uploaderId,
    required this.uploaderAlias,
  });

  final String id;
  final String url;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String status;
  final String moderationReason;
  final String reviewNote;
  final String createdAt;
  final String postId;
  final String uploaderId;
  final String uploaderAlias;

  factory AdminImageReviewItem.fromJson(Map<String, dynamic> json) {
    return AdminImageReviewItem(
      id: (json['id'] ?? '').toString(),
      url: (json['url'] ?? '').toString(),
      fileName: (json['fileName'] ?? '').toString(),
      contentType: (json['contentType'] ?? '').toString(),
      sizeBytes: _toInt(json['sizeBytes']) ?? 0,
      status: (json['status'] ?? 'pending').toString(),
      moderationReason: (json['moderationReason'] ?? '').toString(),
      reviewNote: (json['reviewNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      uploaderId: (json['uploaderId'] ?? '').toString(),
      uploaderAlias: (json['uploaderAlias'] ?? '匿名同学').toString(),
    );
  }
}
