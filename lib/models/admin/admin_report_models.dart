// Admin report handling models

part of '../admin_models.dart';

class AdminReportEntry {
  AdminReportEntry({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.reason,
    required this.description,
    required this.status,
    required this.result,
    required this.reporterAlias,
    required this.createdAt,
  });

  final String id;
  final String targetType;
  final String targetId;
  final String reason;
  final String description;
  final String status;
  final String result;
  final String reporterAlias;
  final String createdAt;

  factory AdminReportEntry.fromJson(Map<String, dynamic> json) {
    return AdminReportEntry(
      id: (json['id'] ?? '').toString(),
      targetType: (json['targetType'] ?? 'other').toString(),
      targetId: (json['targetId'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      status: (json['status'] ?? 'pending').toString(),
      result: (json['result'] ?? '').toString(),
      reporterAlias: (json['reporterAlias'] ?? '匿名同学').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
    );
  }
}
