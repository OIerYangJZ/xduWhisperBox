import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/config/app_config.dart';
import '../profile/public_user_profile_page.dart';
import '../../models/conversation_item.dart';
import '../../models/direct_message_item.dart';
import '../../repositories/app_repositories.dart';
import '../../widgets/emoji/emoji_assistant_bar.dart';

typedef ConversationFlagsChanged =
    void Function({bool? blockedByMe, bool? blockedByPeer});

enum _MessageAction { copy, reply, recall }

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversation,
    this.onMessageSent,
    this.onConversationRead,
    this.onConversationRemoved,
    this.onConversationFlagsChanged,
    this.peerUserId,
  });

  final ConversationItem conversation;
  final ValueChanged<String>? onMessageSent;
  final VoidCallback? onConversationRead;
  final VoidCallback? onConversationRemoved;
  final ConversationFlagsChanged? onConversationFlagsChanged;
  final String? peerUserId;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  late ConversationItem _conversation;
  List<DirectMessageItem> _messages = const <DirectMessageItem>[];
  bool _loading = true;
  bool _sending = false;
  String? _error;
  String? _lastFailedContent;
  DirectMessageItem? _lastFailedReplyTarget;
  DirectMessageItem? _replyingTo;

  @override
  void initState() {
    super.initState();
    _conversation = widget.conversation;
    _loadMessages();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _loading || _sending;
    final bool blockedByMe = _conversation.blockedByMe;
    final bool blockedByPeer = _conversation.blockedByPeer;
    final bool inputEnabled = !_sending && !blockedByMe && !blockedByPeer;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: widget.peerUserId != null
              ? () => _navigateToProfile(context, widget.peerUserId!)
              : null,
          child: Row(
            children: <Widget>[
              _buildAvatar(_conversation.avatarUrl, _conversation.name),
              const SizedBox(width: 8),
              Expanded(child: Text(_conversation.name)),
            ],
          ),
        ),
        actions: <Widget>[
          IconButton(
            onPressed: _loading ? null : _loadMessages,
            icon: const Icon(Icons.refresh),
            tooltip: '刷新',
          ),
          PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'profile':
                  if (widget.peerUserId != null) {
                    _navigateToProfile(context, widget.peerUserId!);
                  }
                  break;
                case 'block':
                  _toggleBlock(true);
                  break;
                case 'unblock':
                  _toggleBlock(false);
                  break;
                case 'delete':
                  _deleteConversation();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              if (widget.peerUserId != null)
                const PopupMenuItem<String>(
                  value: 'profile',
                  child: Text('查看对方主页'),
                ),
              PopupMenuItem<String>(
                value: _conversation.blockedByMe ? 'unblock' : 'block',
                child: Text(_conversation.blockedByMe ? '取消屏蔽' : '屏蔽对方'),
              ),
              const PopupMenuItem<String>(value: 'delete', child: Text('删除会话')),
            ],
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: const Color(0xFFFFF4E5),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.error_outline, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF9A3412)),
                    ),
                  ),
                  if (_lastFailedContent != null && !_loading)
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => _send(
                              retryContent: _lastFailedContent,
                              retryReplyTarget: _lastFailedReplyTarget,
                            ),
                      child: const Text('重试发送'),
                    ),
                  TextButton(
                    onPressed: _loading ? null : _loadMessages,
                    child: const Text('重试'),
                  ),
                ],
              ),
            ),
          if (blockedByMe || blockedByPeer)
            _buildBlockBanner(
              blockedByMe: blockedByMe,
              blockedByPeer: blockedByPeer,
            ),
          Expanded(child: _buildMessageList()),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFE5ECF2))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (_replyingTo != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildReplyBanner(_replyingTo!),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          minLines: 1,
                          maxLines: 4,
                          enabled: inputEnabled,
                          decoration: InputDecoration(
                            hintText: blockedByPeer
                                ? '对方已屏蔽你，暂时无法发送消息'
                                : blockedByMe
                                ? '你已屏蔽对方，解除屏蔽后可继续发送'
                                : _replyingTo != null
                                ? '回复 ${_displaySender(_replyingTo!)}'
                                : '输入消息',
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 4),
                      EmojiAssistantBar(
                        controller: _inputController,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: busy || !inputEnabled ? null : () => _send(),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.send_rounded),
                        tooltip: '发送',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userId) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PublicUserProfilePage(userId: userId),
      ),
    );
  }

  void _showMessageActions(BuildContext context, DirectMessageItem message) {
    final bool isMe = message.fromMe;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('复制'),
              onTap: () => _handleMessageAction(
                context,
                _MessageAction.copy,
                message,
                sheetContext: ctx,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.reply_outlined),
              title: const Text('回复'),
              onTap: () => _handleMessageAction(
                context,
                _MessageAction.reply,
                message,
                sheetContext: ctx,
              ),
            ),
            if (isMe && message.canRecall)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.red),
                title: const Text('撤回'),
                onTap: () => _handleMessageAction(
                  context,
                  _MessageAction.recall,
                  message,
                  sheetContext: ctx,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    if (_loading && _messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error == null ? '还没有消息，先打个招呼吧。' : '消息加载失败，请重试。',
            style: const TextStyle(color: Colors.black54),
          ),
        ),
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: _messages.length,
      itemBuilder: (BuildContext context, int index) {
        final DirectMessageItem message = _messages[index];
        return Align(
          alignment: message.fromMe
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: GestureDetector(
            onLongPress: () => _showMessageActions(context, message),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              constraints: const BoxConstraints(maxWidth: 420),
              decoration: BoxDecoration(
                color: message.fromMe
                    ? const Color(0xFF155E75).withValues(alpha: 0.12)
                    : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF155E75).withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!message.fromMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.senderAlias,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF155E75),
                        ),
                      ),
                    ),
                  if (message.hasReply)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _buildQuotedMessage(message, message.fromMe),
                    ),
                  Text(message.content),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        message.timeText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                        ),
                      ),
                      if (message.fromMe) ...<Widget>[
                        const SizedBox(width: 6),
                        Text(
                          message.isRead ? '已读' : '未读',
                          style: TextStyle(
                            fontSize: 11,
                            color: message.isRead
                                ? const Color(0xFF0F766E)
                                : Colors.black45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      PopupMenuButton<_MessageAction>(
                        tooltip: '更多操作',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        onSelected: (_MessageAction action) =>
                            _handleMessageAction(context, action, message),
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuEntry<_MessageAction>>[
                              const PopupMenuItem<_MessageAction>(
                                value: _MessageAction.copy,
                                child: Text('复制'),
                              ),
                              const PopupMenuItem<_MessageAction>(
                                value: _MessageAction.reply,
                                child: Text('回复'),
                              ),
                              if (message.fromMe && message.canRecall)
                                const PopupMenuItem<_MessageAction>(
                                  value: _MessageAction.recall,
                                  child: Text('撤回'),
                                ),
                            ],
                        icon: const Icon(
                          Icons.more_horiz,
                          size: 16,
                          color: Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMessageAction(
    BuildContext context,
    _MessageAction action,
    DirectMessageItem message, {
    BuildContext? sheetContext,
  }) async {
    if (sheetContext != null && Navigator.of(sheetContext).canPop()) {
      Navigator.of(sheetContext).pop();
    }
    switch (action) {
      case _MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: message.content));
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
        return;
      case _MessageAction.reply:
        _handleReply(message);
        return;
      case _MessageAction.recall:
        await _handleRecall(message);
        return;
    }
  }

  void _handleReply(DirectMessageItem message) {
    setState(() {
      _replyingTo = message;
    });
    _inputFocusNode.requestFocus();
  }

  Future<void> _handleRecall(DirectMessageItem message) async {
    if (!message.canRecall) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('只能撤回 2 分钟内自己发送的消息')));
      return;
    }
    final bool recalledLastMessage =
        _messages.isNotEmpty && _messages.last.id == message.id;
    try {
      await AppRepositories.messages.recallMessage(
        conversationId: widget.conversation.id,
        messageId: message.id,
      );
      if (!mounted) return;
      final List<DirectMessageItem> remaining = _messages
          .where((DirectMessageItem item) => item.id != message.id)
          .toList();
      setState(() {
        _messages = remaining;
        if (_replyingTo?.id == message.id) {
          _replyingTo = null;
        }
        if (_lastFailedReplyTarget?.id == message.id) {
          _lastFailedReplyTarget = null;
        }
      });
      if (recalledLastMessage) {
        widget.onMessageSent?.call(_conversationPreviewText(remaining));
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('消息已撤回')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '撤回失败：$error';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('撤回失败：$error')));
    }
  }

  String _displaySender(DirectMessageItem? message) {
    if (message == null) {
      return '匿名同学';
    }
    return message.fromMe ? '我' : message.senderAlias;
  }

  String _conversationPreviewText(List<DirectMessageItem> messages) {
    if (messages.isEmpty) {
      return '开始聊天吧';
    }
    return messages.last.content.trim().isEmpty
        ? '开始聊天吧'
        : messages.last.content;
  }

  Widget _buildReplyBanner(DirectMessageItem message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E2EA)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF155E75),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '回复 ${_displaySender(message)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF155E75),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _replyingTo = null),
            icon: const Icon(Icons.close, size: 18),
            tooltip: '取消回复',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedMessage(DirectMessageItem message, bool isMe) {
    final Color accentColor = isMe
        ? const Color(0xFF0F172A)
        : const Color(0xFF155E75);
    final Color backgroundColor = isMe
        ? const Color(0xFFFFFFFF).withValues(alpha: 0.55)
        : const Color(0xFF155E75).withValues(alpha: 0.06);
    final Color bodyColor = isMe ? const Color(0xFF334155) : Colors.black54;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              width: 3,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(10),
                  bottomLeft: Radius.circular(10),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      message.replyToSender ?? '匿名同学',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.replyToContent ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: bodyColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBlockBanner({
    required bool blockedByMe,
    required bool blockedByPeer,
  }) {
    final String text = blockedByPeer
        ? '对方已屏蔽你，当前只能查看历史消息。'
        : '你已屏蔽对方，解除后才可继续发送。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFF3F4F6),
      child: Row(
        children: <Widget>[
          const Icon(Icons.shield_outlined, size: 18, color: Color(0xFF475569)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(color: Color(0xFF334155))),
          ),
          if (blockedByMe && !blockedByPeer)
            TextButton(
              onPressed: _sending ? null : () => _toggleBlock(false),
              child: const Text('取消屏蔽'),
            ),
        ],
      ),
    );
  }

  Future<void> _loadMessages() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final List<DirectMessageItem> messages = await AppRepositories.messages
          .fetchConversationMessages(widget.conversation.id);
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _conversation = _conversation.copyWith(
          unreadCount: 0,
          hasUnread: false,
        );
      });
      widget.onConversationRead?.call();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '消息加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _send({
    String? retryContent,
    DirectMessageItem? retryReplyTarget,
  }) async {
    final String content = (retryContent ?? _inputController.text).trim();
    final DirectMessageItem? replyTarget = retryReplyTarget ?? _replyingTo;
    if (content.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final DirectMessageItem created = await AppRepositories.messages
          .sendConversationMessage(
            conversationId: widget.conversation.id,
            content: content,
            replyToId: replyTarget?.id,
          );
      final DirectMessageItem finalCreated = created.hasReply
          ? created
          : created.copyWith(
              replyToId: replyTarget?.id,
              replyToSender: _displaySender(replyTarget),
              replyToContent: replyTarget?.content,
            );
      if (!mounted) return;
      setState(() {
        _messages = <DirectMessageItem>[..._messages, finalCreated];
        _lastFailedContent = null;
        _lastFailedReplyTarget = null;
        _replyingTo = null;
        _inputController.clear();
      });
      widget.onMessageSent?.call(finalCreated.content);
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _lastFailedContent = content;
        _lastFailedReplyTarget = replyTarget;
        _error = '发送失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleBlock(bool block) async {
    setState(() {
      _error = null;
    });
    try {
      final ConversationItem updated = await AppRepositories.messages
          .updateConversationBlock(
            conversationId: _conversation.id,
            block: block,
          );
      if (!mounted) return;
      setState(() {
        _conversation = _conversation.copyWith(
          blockedByMe: updated.blockedByMe,
          blockedByPeer: updated.blockedByPeer,
        );
      });
      widget.onConversationFlagsChanged?.call(
        blockedByMe: updated.blockedByMe,
        blockedByPeer: updated.blockedByPeer,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(block ? '已屏蔽对方' : '已取消屏蔽')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '操作失败：$error';
      });
    }
  }

  Future<void> _deleteConversation() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: const Text('删除后仅从你的列表中移除，会话历史不会立即物理删除。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    try {
      await AppRepositories.messages.deleteConversation(_conversation.id);
      if (!mounted) return;
      widget.onConversationRemoved?.call();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话已删除')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '删除会话失败：$error';
      });
    }
  }

  Widget _buildAvatar(String avatarUrl, String name) {
    final String resolved = AppConfig.resolveUrl(avatarUrl);
    final String fallback = name.trim().isEmpty
        ? '?'
        : name.trim().substring(0, 1);
    if (resolved.isNotEmpty) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: const Color(0xFFE5EAF3),
        child: ClipOval(
          child: Image.network(
            resolved,
            width: 28,
            height: 28,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                Text(fallback, style: const TextStyle(fontSize: 12)),
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 14,
      child: Text(fallback, style: const TextStyle(fontSize: 12)),
    );
  }
}
