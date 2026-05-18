// Admin user management models

part of '../admin_models.dart';

class AdminUserEntry {
  AdminUserEntry({
    required this.id,
    required this.email,
    required this.studentId,
    required this.alias,
    required this.avatarUrl,
    required this.verified,
    required this.userLevel,
    required this.userLevelLabel,
    required this.banned,
    required this.muted,
    required this.deleted,
    required this.postCount,
    required this.commentCount,
    required this.reportCount,
    required this.createdAt,
    required this.hasPendingCancellationRequest,
    required this.hasPendingAppeal,
    required this.hasPendingLevelUpgradeRequest,
  });

  final String id;
  final String email;
  final String studentId;
  final String alias;
  final String avatarUrl;
  final bool verified;
  final int userLevel;
  final String userLevelLabel;
  final bool banned;
  final bool muted;
  final bool deleted;
  final int postCount;
  final int commentCount;
  final int reportCount;
  final String createdAt;
  final bool hasPendingCancellationRequest;
  final bool hasPendingAppeal;
  final bool hasPendingLevelUpgradeRequest;

  factory AdminUserEntry.fromJson(Map<String, dynamic> json) {
    return AdminUserEntry(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      alias: (json['alias'] ?? '匿名同学').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      verified: _toBool(json['verified']) ?? false,
      userLevel: _toInt(json['userLevel']) ?? 2,
      userLevelLabel: (json['userLevelLabel'] ?? '二级用户').toString(),
      banned: _toBool(json['banned']) ?? false,
      muted: _toBool(json['muted']) ?? false,
      deleted: _toBool(json['deleted']) ?? false,
      postCount: _toInt(json['postCount']) ?? 0,
      commentCount: _toInt(json['commentCount']) ?? 0,
      reportCount: _toInt(json['reportCount']) ?? 0,
      createdAt: (json['createdAt'] ?? '').toString(),
      hasPendingCancellationRequest:
          _toBool(json['hasPendingCancellationRequest']) ?? false,
      hasPendingAppeal: _toBool(json['hasPendingAppeal']) ?? false,
      hasPendingLevelUpgradeRequest:
          _toBool(json['hasPendingLevelUpgradeRequest']) ?? false,
    );
  }
}

class AdminAccountCancellationRequest {
  AdminAccountCancellationRequest({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.userNickname,
    required this.studentId,
    required this.avatarUrl,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.reviewNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String userNickname;
  final String studentId;
  final String avatarUrl;
  final String reason;
  final String status;
  final String statusLabel;
  final String reviewNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;

  factory AdminAccountCancellationRequest.fromJson(Map<String, dynamic> json) {
    return AdminAccountCancellationRequest(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      avatarUrl: (json['avatarUrl'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待审核').toString(),
      reviewNote: (json['reviewNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
    );
  }
}

class AdminUserLevelRequestEntry {
  AdminUserLevelRequestEntry({
    required this.id,
    required this.userId,
    required this.userEmail,
    required this.studentId,
    required this.userNickname,
    required this.currentLevel,
    required this.currentLevelLabel,
    required this.targetLevel,
    required this.targetLevelLabel,
    required this.reason,
    required this.status,
    required this.statusLabel,
    required this.adminNote,
    required this.createdAt,
    required this.handledAt,
    required this.handledBy,
    required this.userDeleted,
    required this.userCurrentLevel,
    required this.userCurrentLevelLabel,
  });

  final String id;
  final String userId;
  final String userEmail;
  final String studentId;
  final String userNickname;
  final int currentLevel;
  final String currentLevelLabel;
  final int targetLevel;
  final String targetLevelLabel;
  final String reason;
  final String status;
  final String statusLabel;
  final String adminNote;
  final String createdAt;
  final String handledAt;
  final String handledBy;
  final bool userDeleted;
  final int userCurrentLevel;
  final String userCurrentLevelLabel;

  factory AdminUserLevelRequestEntry.fromJson(Map<String, dynamic> json) {
    return AdminUserLevelRequestEntry(
      id: (json['id'] ?? '').toString(),
      userId: (json['userId'] ?? '').toString(),
      userEmail: (json['userEmail'] ?? '').toString(),
      studentId: (json['studentId'] ?? '').toString(),
      userNickname: (json['userNickname'] ?? '匿名同学').toString(),
      currentLevel: _toInt(json['currentLevel']) ?? 2,
      currentLevelLabel: (json['currentLevelLabel'] ?? '二级用户').toString(),
      targetLevel: _toInt(json['targetLevel']) ?? 1,
      targetLevelLabel: (json['targetLevelLabel'] ?? '一级用户').toString(),
      reason: (json['reason'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      statusLabel: (json['statusLabel'] ?? '待处理').toString(),
      adminNote: (json['adminNote'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      handledAt: (json['handledAt'] ?? '').toString(),
      handledBy: (json['handledBy'] ?? '').toString(),
      userDeleted: _toBool(json['userDeleted']) ?? false,
      userCurrentLevel: _toInt(json['userCurrentLevel']) ?? 2,
      userCurrentLevelLabel:
          (json['userCurrentLevelLabel'] ?? '二级用户').toString(),
    );
  }
}
