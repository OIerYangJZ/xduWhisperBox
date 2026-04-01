import 'dart:typed_data';

import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/admin_models.dart';

class AdminRepository {
  AdminRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<AdminCurrentUser> fetchCurrentAdmin() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminMe);
    final Map<String, dynamic> data = extractMap(response);
    return AdminCurrentUser.fromJson(data);
  }

  Future<AdminOverview> fetchOverview() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminOverview);
    final Map<String, dynamic> data = extractMap(response);
    return AdminOverview.fromJson(data);
  }

  Future<List<AdminReviewItem>> fetchReviews({
    required String type,
    required String status,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminReviews,
      queryParameters: <String, dynamic>{'type': type, 'status': status},
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminReviewItem.fromJson(asMap(item)))
        .where((AdminReviewItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleReview({
    required String targetType,
    required String targetId,
    required String action,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminReviewAction(targetType, targetId, action),
      body: const <String, dynamic>{},
    );
  }

  Future<void> handleReviewBatch({
    required String targetType,
    required List<String> targetIds,
    required String action,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminReviewBatch,
      body: <String, dynamic>{
        'targetType': targetType,
        'targetIds': targetIds,
        'action': action,
      },
    );
  }

  Future<List<AdminReportEntry>> fetchReports({
    String status = 'all',
    String? reason,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminReports,
      queryParameters: <String, dynamic>{
        'status': status,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );

    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminReportEntry.fromJson(asMap(item)))
        .where((AdminReportEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<AdminImageReviewItem>> fetchImageReviews({
    String status = 'pending',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminImageReviews,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );

    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminImageReviewItem.fromJson(asMap(item)))
        .where((AdminImageReviewItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleReport({
    required String reportId,
    required String action,
    String? result,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminReportHandle(reportId),
      body: <String, dynamic>{
        'action': action,
        if (result != null && result.trim().isNotEmpty) 'result': result.trim(),
      },
    );
  }

  Future<List<AdminUserEntry>> fetchUsers() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminUsers);
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminUserEntry.fromJson(asMap(item)))
        .where((AdminUserEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<AdminPostPinRequestEntry>> fetchPostPinRequests({
    String status = 'all',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminPostPinRequests,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminPostPinRequestEntry.fromJson(asMap(item)))
        .where((AdminPostPinRequestEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handlePostPinRequest({
    required String requestId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminPostPinRequestHandle(requestId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<List<AdminUserLevelRequestEntry>> fetchUserLevelRequests({
    String status = 'all',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminUserLevelRequests,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminUserLevelRequestEntry.fromJson(asMap(item)))
        .where((AdminUserLevelRequestEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleUserLevelRequest({
    required String requestId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminUserLevelRequestHandle(requestId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<List<AdminAccountEntry>> fetchAdminAccounts() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminAccounts);
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminAccountEntry.fromJson(asMap(item)))
        .where((AdminAccountEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> createAdminAccount({
    required String username,
    required String password,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminAccounts,
      body: <String, dynamic>{'username': username, 'password': password},
    );
  }

  Future<void> updateAdminAccount({
    required String adminId,
    required String action,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminAccountAction(adminId),
      body: <String, dynamic>{'action': action},
    );
  }

  Future<List<AdminAccountCancellationRequest>>
  fetchAccountCancellationRequests({
    String status = 'all',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminAccountCancellationRequests,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    final List<dynamic> list = extractList(response);
    return list
        .map(
          (dynamic item) =>
              AdminAccountCancellationRequest.fromJson(asMap(item)),
        )
        .where((AdminAccountCancellationRequest item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> updateUserState({
    required String userId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminUserAction(userId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> handleAccountCancellationRequest({
    required String requestId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminAccountCancellationHandle(requestId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<List<AdminAppealEntry>> fetchAppeals({
    String status = 'all',
    String? keyword,
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminAppeals,
      queryParameters: <String, dynamic>{
        'status': status,
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
      },
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminAppealEntry.fromJson(asMap(item)))
        .where((AdminAppealEntry item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> handleAppeal({
    required String appealId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminAppealHandle(appealId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<void> handleImageReview({
    required String uploadId,
    required String action,
    String? note,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminImageReview(uploadId),
      body: <String, dynamic>{
        'action': action,
        if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
      },
    );
  }

  Future<AdminChannelTagData> fetchChannelTagData() async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminChannelsTags,
    );
    final Map<String, dynamic> data = extractMap(response);
    return AdminChannelTagData.fromJson(data);
  }

  Future<void> addChannel(String name) {
    return _apiClient.post(
      ApiEndpoints.adminChannels,
      body: <String, dynamic>{'name': name},
    );
  }

  Future<void> renameChannel({
    required String oldName,
    required String newName,
  }) {
    return _apiClient.patch(
      ApiEndpoints.adminChannelByName(_encodePath(oldName)),
      body: <String, dynamic>{'newName': newName},
    );
  }

  Future<void> deleteChannel(String name) {
    return _apiClient.delete(
      ApiEndpoints.adminChannelByName(_encodePath(name)),
    );
  }

  Future<void> addTag(String name) {
    return _apiClient.post(
      ApiEndpoints.adminTags,
      body: <String, dynamic>{'name': name},
    );
  }

  Future<void> renameTag({required String oldName, required String newName}) {
    return _apiClient.patch(
      ApiEndpoints.adminTagByName(_encodePath(oldName)),
      body: <String, dynamic>{'newName': newName},
    );
  }

  Future<void> deleteTag(String name) {
    return _apiClient.delete(ApiEndpoints.adminTagByName(_encodePath(name)));
  }

  Future<AdminSystemConfig> fetchConfig() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminConfig);
    final Map<String, dynamic> data = extractMap(response);
    return AdminSystemConfig.fromJson(data);
  }

  Future<AdminAndroidRelease?> fetchAndroidRelease() async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminAndroidRelease,
    );
    final Map<String, dynamic> map = asMap(response);
    if (!map.containsKey('data') || map['data'] == null) {
      return null;
    }
    final Map<String, dynamic> data = extractMap(response);
    if (data.isEmpty) {
      return null;
    }
    return AdminAndroidRelease.fromJson(data);
  }

  Future<AdminAndroidRelease> uploadAndroidRelease({
    required String versionName,
    required int versionCode,
    required String releaseNotes,
    required bool forceUpdate,
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final dynamic response = await _apiClient.postMultipart(
      ApiEndpoints.adminAndroidRelease,
      fields: <String, String>{
        'versionName': versionName,
        'versionCode': versionCode.toString(),
        'releaseNotes': releaseNotes,
        'forceUpdate': forceUpdate ? 'true' : 'false',
      },
      fileFieldName: 'file',
      fileBytes: fileBytes,
      fileName: fileName,
      timeout: const Duration(minutes: 8),
    );
    final Map<String, dynamic> data = extractMap(response);
    return AdminAndroidRelease.fromJson(data);
  }

  Future<void> updateConfig(AdminSystemConfig config) {
    return _apiClient.patch(
      ApiEndpoints.adminConfig,
      body: config.toRequestJson(),
    );
  }

  Future<List<AdminSystemAnnouncement>> fetchAnnouncements() async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminAnnouncements,
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => AdminSystemAnnouncement.fromJson(asMap(item)))
        .where((AdminSystemAnnouncement item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> publishAnnouncement({
    required String title,
    required String content,
  }) {
    return _apiClient.post(
      ApiEndpoints.adminAnnouncements,
      body: <String, dynamic>{'title': title, 'content': content},
    );
  }

  Future<AdminExportFile> exportData({
    required String scope,
    String format = 'csv',
    String reviewType = 'post',
    String reviewStatus = 'all',
    String reportStatus = 'all',
    String appealStatus = 'all',
  }) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.adminExport,
      queryParameters: <String, dynamic>{
        'scope': scope,
        'format': format,
        'reviewType': reviewType,
        'reviewStatus': reviewStatus,
        'reportStatus': reportStatus,
        'appealStatus': appealStatus,
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    return AdminExportFile.fromJson(data);
  }

  String _encodePath(String value) {
    return Uri.encodeComponent(value);
  }
}
