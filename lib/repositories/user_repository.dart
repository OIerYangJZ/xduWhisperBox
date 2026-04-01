import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_utils.dart';
import '../models/follow_user_item.dart';
import '../models/my_comment_item.dart';
import '../models/report_item.dart';
import '../models/user_profile.dart';
import '../models/public_user_profile.dart';

class UserRepository {
  UserRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<UserProfile> fetchProfile() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.me);
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return UserProfile.fromJson(map);
    }
    throw Exception('个人资料加载失败：服务端未返回有效数据');
  }

  Future<void> updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) {
    return _apiClient.patch(
      ApiEndpoints.privacy,
      body: <String, dynamic>{
        'allowStrangerDm': allowStrangerDm,
        'showContactable': showContactable,
      },
    );
  }

  Future<void> updateNotificationPreferences({
    required bool notifyComment,
    required bool notifyReply,
    required bool notifyLike,
    required bool notifyFavorite,
    required bool notifyReportResult,
    required bool notifySystem,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'notifyComment': notifyComment,
      'notifyReply': notifyReply,
      'notifyLike': notifyLike,
      'notifyFavorite': notifyFavorite,
      'notifyReportResult': notifyReportResult,
      'notifySystem': notifySystem,
    };

    try {
      await _apiClient.patch(ApiEndpoints.notificationPreferences, body: body);
      return;
    } on ApiException catch (error) {
      final int? statusCode = error.statusCode;
      if (statusCode != 404 && statusCode != 405) {
        rethrow;
      }
    }

    await _updateNotificationPreferencesFallback(body);
  }

  Future<void> _updateNotificationPreferencesFallback(
    Map<String, dynamic> body,
  ) async {
    final List<Future<dynamic> Function()> attempts =
        <Future<dynamic> Function()>[
          () =>
              _apiClient.post(ApiEndpoints.notificationPreferences, body: body),
          () => _apiClient.patch(
            ApiEndpoints.notificationPreferencesLegacy,
            body: body,
          ),
          () => _apiClient.post(
            ApiEndpoints.notificationPreferencesLegacy,
            body: body,
          ),
        ];

    ApiException? lastApiError;
    for (final attempt in attempts) {
      try {
        await attempt();
        return;
      } on ApiException catch (error) {
        lastApiError = error;
        final int? statusCode = error.statusCode;
        if (statusCode != 404 && statusCode != 405) {
          rethrow;
        }
      }
    }

    if (lastApiError != null) {
      throw lastApiError;
    }
  }

  Future<void> updateProfile({
    required String nickname,
    String? avatarUrl,
    String? bio,
    String? backgroundImageUrl,
    String? gender,
  }) {
    final body = <String, dynamic>{'nickname': nickname};

    if (avatarUrl != null) {
      body['avatarUrl'] = avatarUrl;
    }
    if (bio != null) {
      body['bio'] = bio;
    }
    if (backgroundImageUrl != null) {
      body['backgroundImageUrl'] = backgroundImageUrl;
    }
    if (gender != null) {
      body['gender'] = gender;
    }

    return _apiClient.patch(ApiEndpoints.me, body: body);
  }

  Future<String> uploadAvatar({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.avatarUpload,
      body: <String, dynamic>{
        'fileName': fileName,
        'avatarContentType': contentType,
        'contentType': contentType,
        'avatarDataBase64': dataBase64,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    return (map['avatarUrl'] ?? '').toString();
  }

  Future<String> uploadBackgroundImage({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.uploadImages,
      body: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    return (map['url'] ?? '').toString();
  }

  Future<List<MyCommentItem>> fetchMyComments() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myComments);
      final List<dynamic> list = extractList(response);
      final List<MyCommentItem> items = list
          .map((dynamic item) => MyCommentItem.fromJson(asMap(item)))
          .where((MyCommentItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty || !AppConfig.enableMockFallback) {
        return items;
      }
    } catch (_) {
      return <MyCommentItem>[];
    }

    return <MyCommentItem>[];
  }

  Future<void> deleteMyComment(String commentId) {
    return _apiClient.delete(ApiEndpoints.commentById(commentId));
  }

  Future<List<ReportItem>> fetchMyReports() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myReports);
      final List<dynamic> list = extractList(response);
      final List<ReportItem> items = list
          .map((dynamic item) => ReportItem.fromJson(asMap(item)))
          .where((ReportItem item) => item.id.isNotEmpty)
          .toList();
      if (items.isNotEmpty || !AppConfig.enableMockFallback) {
        return items;
      }
    } catch (_) {
      return <ReportItem>[];
    }

    return <ReportItem>[];
  }

  Future<ReportItem> fetchMyReportDetail(String reportId) async {
    try {
      final dynamic response = await _apiClient.get(
        ApiEndpoints.reportById(reportId),
      );
      final Map<String, dynamic> map = extractMap(response);
      if (map.isNotEmpty) {
        return ReportItem.fromJson(map);
      }
    } catch (_) {
      // ignore and fallback
    }

    final List<ReportItem> rows = await fetchMyReports();
    return rows.firstWhere(
      (ReportItem item) => item.id == reportId,
      orElse: () => ReportItem(
        id: reportId,
        target: '-',
        targetType: '',
        targetId: '',
        targetTitle: '',
        reason: '-',
        description: '',
        status: '-',
        result: '',
        createdAt: '',
        handledAt: '',
      ),
    );
  }

  Future<void> submitAccountCancellationRequest({String? reason}) {
    return _apiClient.post(
      ApiEndpoints.meCancellationRequest,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<void> submitLevelUpgradeRequest({String? reason}) {
    return _apiClient.post(
      ApiEndpoints.meLevelUpgradeRequest,
      body: <String, dynamic>{
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<List<FollowUserItem>> fetchFollowing() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myFollowing);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
          .where((FollowUserItem item) => item.userId.isNotEmpty)
          .toList();
    } catch (_) {
      return <FollowUserItem>[];
    }
  }

  Future<List<FollowUserItem>> fetchFollowers() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myFollowers);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
          .where((FollowUserItem item) => item.userId.isNotEmpty)
          .toList();
    } catch (_) {
      return <FollowUserItem>[];
    }
  }

  Future<List<FollowUserItem>> fetchFriends() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myFriends);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => FollowUserItem.fromJson(asMap(item)))
          .where((FollowUserItem item) => item.userId.isNotEmpty)
          .toList();
    } catch (_) {
      return <FollowUserItem>[];
    }
  }

  Future<List<PublicUserProfile>> searchUsers(String keyword) async {
    final String normalized = keyword.trim();
    if (normalized.isEmpty) {
      return <PublicUserProfile>[];
    }
    final dynamic response = await _apiClient.get(
      ApiEndpoints.userSearch,
      queryParameters: <String, dynamic>{'keyword': normalized},
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => PublicUserProfile.fromJson(asMap(item)))
        .where((PublicUserProfile item) => item.id.isNotEmpty)
        .toList();
  }

  Future<void> followUser(String userId) {
    return _apiClient.post(
      ApiEndpoints.followUser(userId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unfollowUser(String userId) {
    return _apiClient.post(
      ApiEndpoints.unfollowUser(userId),
      body: const <String, dynamic>{},
    );
  }

  Future<PublicUserProfile> fetchUserProfile(String userId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.userProfile(userId),
    );
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return PublicUserProfile.fromJson(map);
    }
    throw Exception('用户资料加载失败');
  }
}
