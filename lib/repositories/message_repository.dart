import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../models/conversation_item.dart';
import '../models/direct_message_item.dart';
import '../models/dm_request_item.dart';

class MessageRepository {
  MessageRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<DmRequestItem>> fetchDmRequests() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.dmRequests);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => DmRequestItem.fromJson(asMap(item)))
          .where((DmRequestItem item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <DmRequestItem>[];
    }
  }

  Future<void> handleDmRequest({
    required String requestId,
    required bool accept,
  }) async {
    final String action = accept ? 'accept' : 'reject';
    await _apiClient.post(
      ApiEndpoints.dmRequestAction(requestId, action),
      body: const <String, dynamic>{},
    );
  }

  Future<void> createDmRequest({
    String? postId,
    String? targetUserId,
    String? reason,
  }) {
    if ((postId == null || postId.trim().isEmpty) &&
        (targetUserId == null || targetUserId.trim().isEmpty)) {
      throw ArgumentError('postId 和 targetUserId 至少提供一个');
    }
    return _apiClient.post(
      ApiEndpoints.dmRequests,
      body: <String, dynamic>{
        if (postId != null && postId.trim().isNotEmpty) 'postId': postId.trim(),
        if (targetUserId != null && targetUserId.trim().isNotEmpty)
          'targetUserId': targetUserId.trim(),
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
  }

  Future<List<ConversationItem>> fetchConversations() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.conversations);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => ConversationItem.fromJson(asMap(item)))
          .where((ConversationItem item) => item.id.isNotEmpty)
          .toList();
    } catch (_) {
      return <ConversationItem>[];
    }
  }

  Future<List<DirectMessageItem>> fetchConversationMessages(
    String conversationId,
  ) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.dmConversationMessages(conversationId),
    );
    final List<dynamic> list = extractList(response);
    return list
        .map((dynamic item) => DirectMessageItem.fromJson(asMap(item)))
        .where((DirectMessageItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<DirectMessageItem> sendConversationMessage({
    required String conversationId,
    required String content,
    String? replyToId,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.dmConversationMessages(conversationId),
      body: <String, dynamic>{
        'content': content,
        if (replyToId != null) 'replyToId': replyToId,
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    return DirectMessageItem.fromJson(map);
  }

  Future<void> deleteConversation(String conversationId) {
    return _apiClient.delete(ApiEndpoints.dmConversation(conversationId));
  }

  Future<ConversationItem> updateConversationBlock({
    required String conversationId,
    required bool block,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.dmConversationBlock(conversationId, block),
      body: const <String, dynamic>{},
    );
    final Map<String, dynamic> data = extractMap(response);
    return ConversationItem.fromJson(<String, dynamic>{
      'id': conversationId,
      ...data,
    });
  }

  Future<ConversationItem> createDirectConversation(
    String targetUserId, {
    String? fromPostId,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.directConversation,
      body: <String, dynamic>{
        'targetUserId': targetUserId.trim(),
        if (fromPostId != null && fromPostId.trim().isNotEmpty)
          'fromPostId': fromPostId.trim(),
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    return ConversationItem.fromJson(data);
  }

  Future<void> recallMessage({required String conversationId, required String messageId}) {
    return _apiClient.delete(
      ApiEndpoints.dmMessageRecall(messageId),
      queryParameters: {'conversationId': conversationId},
    );
  }
}
