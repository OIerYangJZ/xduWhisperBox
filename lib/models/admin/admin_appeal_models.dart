// Admin appeal and pin request models

part of '../admin_models.dart';

class AdminAppealEntry {
  AdminAppealEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.studentId,
    required this.userNickname,
    required this.appealType,
    required this.appealTypeLabel,
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.content,
    required this.status,
    required this.statusLabel,
    required this.adminNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
    required this.userDeleted,
    required this.userBanned,
    required this.userMuted,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String studentId;
  final String userNickname;
  final String appealType;
  final String appealTypeLabel;
  final String targetType;
  final String targetId;
  final String title;
  final String content;
  final String status;
  final String statusLabel;
  final String adminNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;
  final bool userDeleted;
  final bool userBanned;
  final bool userMuted;

  factory AdminAppealEntry.fromJson(Map<String, dynamic> json) {
    return AdminAppealEntry(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      appealType: (json['appealType'] ?? 'other').toString(),
      appealTypeLabel: (json['appealTypeLabel'] ?? '其他申诉').toString(),
      targetType: (json['targetType'] ?? '').toString(),
      targetId: (json['targetId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待处理').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
      userDeleted: _toBool(json['userDeleted']) ?? false,
      userBanned: _toBool(json['userBanned']) ?? false,
      userMuted: _toBool(json['userMuted']) ?? false,
    );
  }
}

class AdminPostPinRequestEntry {
  AdminPostPinRequestEntry({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.userId,
    required this.userEmail,
    required this.userNickname,
    required this.userLevel,
    required this.userLevelLabel,
    required this.durationMinutes,
    required this.durationLabel,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.adminNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
    required this.postDeleted,
    required this.postPinned,
  });

  final String id;
  final String postId;
  final String postTitle;
  final String userId;
  final String userEmail;
  final String userNickname;
  final int userLevel;
  final String userLevelLabel;
  final int durationMinutes;
  final String durationLabel;
  final String reason;
  final String status;
  final String statusLabel;
  final String adminNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;
  final bool postDeleted;
  final bool postPinned;

  factory AdminPostPinRequestEntry.fromJson(Map<String, dynamic> json) {
    return AdminPostPinRequestEntry(
      id: (json['id'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      postTitle: (json['postTitle'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      userLevel: _toInt(json['userLevel']) ?? 2,
      userLevelLabel: (json['userLevelLabel'] ?? '二级用户').toString(),
      durationMinutes: _toInt(json['durationMinutes']) ?? 0,
      durationLabel: (json['durationLabel'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待处理').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
      postDeleted: _toBool(json['postDeleted']) ?? false,
      postPinned: _toBool(json['postPinned']) ?? false,
    );
  }
}
