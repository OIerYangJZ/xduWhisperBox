import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/conversation_item.dart';
import '../../models/dm_request_item.dart';

class MessagesState {
  const MessagesState({
    this.requests = const <DmRequestItem>[],
    this.conversations = const <ConversationItem>[],
    this.loading = true,
    this.actionBusy = false,
    this.error,
  });

  final List<DmRequestItem> requests;
  final List<ConversationItem> conversations;
  final bool loading;
  final bool actionBusy;
  final String? error;

  MessagesState copyWith({
    List<DmRequestItem>? requests,
    List<ConversationItem>? conversations,
    bool? loading,
    bool? actionBusy,
    String? error,
    bool clearError = false,
  }) {
    return MessagesState(
      requests: requests ?? this.requests,
      conversations: conversations ?? this.conversations,
      loading: loading ?? this.loading,
      actionBusy: actionBusy ?? this.actionBusy,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class MessagesController extends StateNotifier<MessagesState> {
  MessagesController(this._ref) : super(const MessagesState());

  final Ref _ref;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    await _reloadData();
  }

  Future<void> refresh() async {
    await _reloadData(showLoading: false);
  }

  Future<bool> handleRequest({
    required String requestId,
    required bool accept,
  }) async {
    if (state.actionBusy) {
      return false;
    }
    state = state.copyWith(actionBusy: true, clearError: true);
    try {
      await _ref.read(messageRepositoryProvider).handleDmRequest(
            requestId: requestId,
            accept: accept,
          );
      await _reloadData(
        showLoading: false,
        preserveActionBusy: true,
      );
      state = state.copyWith(actionBusy: false, clearError: true);
      return true;
    } catch (error) {
      state = state.copyWith(actionBusy: false, error: '操作失败：$error');
      return false;
    }
  }

  Future<bool> _reloadData({
    bool showLoading = true,
    bool preserveActionBusy = false,
  }) async {
    if (showLoading) {
      state = state.copyWith(loading: true, clearError: true);
    }

    try {
      final List<DmRequestItem> requests =
          await _ref.read(messageRepositoryProvider).fetchDmRequests();
      final List<ConversationItem> conversations =
          await _ref.read(messageRepositoryProvider).fetchConversations();
      state = state.copyWith(
        requests: requests,
        conversations: conversations,
        loading: false,
        actionBusy: preserveActionBusy ? state.actionBusy : false,
        clearError: true,
      );
      return true;
    } catch (error) {
      state = state.copyWith(
        loading: false,
        actionBusy: preserveActionBusy ? state.actionBusy : false,
        error: '消息加载失败：$error',
      );
      return false;
    }
  }

  void updateConversationPreview({
    required String conversationId,
    required String message,
  }) {
    final List<ConversationItem> rows = List<ConversationItem>.from(
      state.conversations,
    );
    final int index = rows.indexWhere(
      (ConversationItem item) => item.id == conversationId,
    );
    if (index < 0) {
      return;
    }

    final ConversationItem current = rows[index];
    final ConversationItem updated = current.copyWith(
      lastMessage: message,
      timeText: _formatNowTime(),
      unreadCount: 0,
      hasUnread: false,
    );
    rows.removeAt(index);
    rows.insert(0, updated);
    state = state.copyWith(conversations: rows, clearError: true);
  }

  void markConversationRead(String conversationId) {
    final List<ConversationItem> rows = List<ConversationItem>.from(
      state.conversations,
    );
    final int index = rows.indexWhere(
      (ConversationItem item) => item.id == conversationId,
    );
    if (index < 0) {
      return;
    }
    rows[index] = rows[index].copyWith(unreadCount: 0, hasUnread: false);
    state = state.copyWith(conversations: rows, clearError: true);
  }

  void updateConversationFlags({
    required String conversationId,
    bool? blockedByMe,
    bool? blockedByPeer,
  }) {
    final List<ConversationItem> rows = List<ConversationItem>.from(
      state.conversations,
    );
    final int index = rows.indexWhere(
      (ConversationItem item) => item.id == conversationId,
    );
    if (index < 0) {
      return;
    }
    rows[index] = rows[index].copyWith(
      blockedByMe: blockedByMe,
      blockedByPeer: blockedByPeer,
    );
    state = state.copyWith(conversations: rows, clearError: true);
  }

  void removeConversation(String conversationId) {
    final List<ConversationItem> rows = state.conversations
        .where((ConversationItem item) => item.id != conversationId)
        .toList();
    state = state.copyWith(conversations: rows, clearError: true);
  }

  Future<void> deleteConversation(String conversationId) async {
    try {
      await _ref.read(messageRepositoryProvider).deleteConversation(conversationId);
    } catch (_) {}
    removeConversation(conversationId);
  }

  Future<void> recallMessage({required String conversationId, required String messageId}) async {
    try {
      await _ref.read(messageRepositoryProvider).recallMessage(
        conversationId: conversationId,
        messageId: messageId,
      );
    } catch (_) {}
  }

  void removeMessage(String conversationId, String messageId) {
    // Update conversation preview: show the second-to-last message as the new preview
    final List<ConversationItem> rows = List<ConversationItem>.from(state.conversations);
    final int idx = rows.indexWhere((c) => c.id == conversationId);
    if (idx >= 0) {
      rows[idx] = rows[idx].copyWith(
        lastMessage: '对方撤回了一条消息',
        timeText: _formatNowTime(),
      );
      state = state.copyWith(conversations: rows, clearError: true);
    }
  }

  String _formatNowTime() {
    final DateTime now = DateTime.now();
    final String hh = now.hour.toString().padLeft(2, '0');
    final String mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

final messagesControllerProvider =
    StateNotifierProvider<MessagesController, MessagesState>(
  (Ref ref) => MessagesController(ref),
);
