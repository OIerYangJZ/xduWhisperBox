// Admin account management models

part of '../admin_models.dart';

class AdminCurrentUser {
  AdminCurrentUser({
    required this.username,
    required this.role,
    required this.roleLabel,
    required this.isPrimary,
  });

  final String username;
  final String role;
  final String roleLabel;
  final bool isPrimary;

  factory AdminCurrentUser.fromJson(Map<String, dynamic> json) {
    return AdminCurrentUser(
      username: (json['username'] ?? '').toString(),
      role: (json['role'] ?? 'secondary').toString(),
      roleLabel: (json['roleLabel'] ?? '二级管理员').toString(),
      isPrimary: _toBool(json['isPrimary']) ?? false,
    );
  }
}

class AdminAccountEntry {
  AdminAccountEntry({
    required this.id,
    required this.username,
    required this.role,
    required this.roleLabel,
    required this.active,
    required this.statusLabel,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
  });

  final String id;
  final String username;
  final String role;
  final String roleLabel;
  final bool active;
  final String statusLabel;
  final String createdAt;
  final String updatedAt;
  final String createdBy;

  factory AdminAccountEntry.fromJson(Map<String, dynamic> json) {
    return AdminAccountEntry(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? '').toString(),
      role: (json['role'] ?? 'secondary').toString(),
      roleLabel: (json['roleLabel'] ?? '二级管理员').toString(),
      active: _toBool(json['active']) ?? true,
      statusLabel: (json['statusLabel'] ?? '启用中').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      updatedAt: (json['updatedAt'] ?? '').toString(),
      createdBy: (json['createdBy'] ?? '').toString(),
    );
  }
}
