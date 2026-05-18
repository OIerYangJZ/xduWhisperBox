// Admin overview data models

part of '../admin_models.dart';

class AdminOverview {
  AdminOverview({
    required this.todayNewUsers,
    required this.todayPosts,
    required this.todayComments,
    required this.todayReports,
    required this.pendingReviews,
    required this.pendingCancellationRequests,
    required this.activeUsers,
    required this.bannedUsers,
    required this.mutedUsers,
  });

  final int todayNewUsers;
  final int todayPosts;
  final int todayComments;
  final int todayReports;
  final int pendingReviews;
  final int pendingCancellationRequests;
  final int activeUsers;
  final int bannedUsers;
  final int mutedUsers;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      todayNewUsers: _toInt(json['todayNewUsers']) ?? 0,
      todayPosts: _toInt(json['todayPosts']) ?? 0,
      todayComments: _toInt(json['todayComments']) ?? 0,
      todayReports: _toInt(json['todayReports']) ?? 0,
      pendingReviews: _toInt(json['pendingReviews']) ?? 0,
      pendingCancellationRequests:
          _toInt(json['pendingCancellationRequests']) ?? 0,
      activeUsers: _toInt(json['activeUsers']) ?? 0,
      bannedUsers: _toInt(json['bannedUsers']) ?? 0,
      mutedUsers: _toInt(json['mutedUsers']) ?? 0,
    );
  }
}
