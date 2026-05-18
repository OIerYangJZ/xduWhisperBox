import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/models/direct_message_item.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';

/// 聊天页
/// 支持消息气泡、时间戳分组、发送消息
class ChatPage extends ConsumerStatefulWidget {
  final String conversationId;
  final String? peerName;
  final String? peerAvatar;
  final String? peerUserId;

  const ChatPage({
    super.key,
    required this.conversationId,
    this.peerName,
    this.peerAvatar,
    this.peerUserId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  List<DirectMessageItem> _messages = [];
  bool _isLoading = true;
  String? _error;
  bool _isSending = false;
  bool _firstMessageWarningDismissed = false;
  bool _blockedByMe = false;
  bool _selectMode = false;
  final Set<String> _selectedMessages = {};
  OverlayEntry? _overlayEntry;

  /// 当前正在回复的消息
  DirectMessageItem? _replyingTo;

  UserProfile? get _currentUser => AuthStore.instance.currentUser;
  String get _myAvatar => _currentUser?.avatarUrl ?? '';
  String get _myUserId => _currentUser?.userId ?? '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _hideOverlay(rebuild: false);
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final messages = await messageRepo.fetchConversationMessages(
        widget.conversationId,
      );
      // 后端已在获取消息时自动标记已读，这里同步更新本地状态
      ref
          .read(messagesControllerProvider.notifier)
          .markConversationRead(widget.conversationId);

      // 查找会话的屏蔽状态
      final conversations = ref.read(messagesControllerProvider).conversations;
      final conversation = conversations
          .where((c) => c.id == widget.conversationId)
          .firstOrNull;

      if (mounted) {
        setState(() {
          _messages = messages;
          _blockedByMe = conversation?.blockedByMe ?? false;
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSend() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    final replyTarget = _replyingTo;

    // 清空输入框和回复状态
    _messageController.clear();
    setState(() => _replyingTo = null);

    // 乐观更新：先添加消息到列表
    final tempMessage = DirectMessageItem(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      createdAt: DateTime.now().toIso8601String(),
      timeText: '刚刚',
      fromMe: true,
      senderAlias: '我',
      isRead: false,
      readAt: '',
      deliveryStatus: 'sending',
      serverCanRecall: true,
      replyToId: replyTarget?.id,
      replyToSender: replyTarget?.senderAlias,
      replyToContent: replyTarget?.content,
    );

    setState(() {
      _messages.add(tempMessage);
    });
    _scrollToBottom();

    setState(() {
      _isSending = true;
    });

    try {
      final messageRepo = ref.read(messageRepositoryProvider);
      final sentMessage = await messageRepo.sendConversationMessage(
        conversationId: widget.conversationId,
        content: content,
        replyToId: replyTarget?.id,
      );

      // 后端若不支持回复字段，用乐观数据补充
      final finalMessage = sentMessage.hasReply
          ? sentMessage
          : sentMessage.copyWith(
              replyToId: replyTarget?.id,
              replyToSender: replyTarget?.senderAlias,
              replyToContent: replyTarget?.content,
            );

      // 更新消息状态为已发送
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = finalMessage;
          }
        });
        // 更新上层会话列表的预览和未读数
        ref
            .read(messagesControllerProvider.notifier)
            .updateConversationPreview(
              conversationId: widget.conversationId,
              message: content,
            );
      }
    } catch (e) {
      // 发送失败，标记为失败状态
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = DirectMessageItem(
              id: tempMessage.id,
              content: content,
              createdAt: tempMessage.createdAt,
              timeText: '发送失败',
              fromMe: true,
              senderAlias: '我',
              isRead: false,
              readAt: '',
              deliveryStatus: 'failed',
              serverCanRecall: false,
              replyToId: replyTarget?.id,
              replyToSender: replyTarget?.senderAlias,
              replyToContent: replyTarget?.content,
            );
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('发送失败: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return PopScope(
      canPop: _overlayEntry == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _overlayEntry != null) {
          _hideOverlay();
        }
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: _selectMode ? _buildSelectModeAppBar() : _buildNormalAppBar(),
        body: Column(
          children: [
            // 首条消息提示横幅
            if (!_isLoading &&
                _messages.isEmpty &&
                !_firstMessageWarningDismissed)
              _buildFirstMessageBanner(),

            // 消息列表
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? _buildErrorView()
                  : _buildMessageList(),
            ),

            // 输入区域
            if (!_selectMode) _buildInputArea(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    final colors = MobileColors.of(context);
    return AppBar(
      backgroundColor: colors.surface,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => context.pop(),
      ),
      title: GestureDetector(
        onTap: widget.peerUserId != null
            ? () => context.push('/user/${widget.peerUserId}')
            : null,
        child: Row(
          children: [
            // 头像
            if (widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundColor: MobileTheme.primaryWithAlpha(context, 0.1),
                backgroundImage: CachedNetworkImageProvider(
                  widget.peerAvatar!.startsWith('http')
                      ? widget.peerAvatar!
                      : AppConfig.resolveUrl(widget.peerAvatar!),
                ),
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: MobileTheme.primaryWithAlpha(context, 0.1),
                child: Text(
                  (widget.peerName ?? '用户').substring(0, 1),
                  style: TextStyle(
                    color: MobileTheme.primaryOf(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.peerName ?? '聊天',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.more_horiz),
          onPressed: () => _showOptionsSheet(),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildSelectModeAppBar() {
    final colors = MobileColors.of(context);
    return AppBar(
      backgroundColor: colors.surface,
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: _exitSelectMode,
      ),
      title: Text(
        '已选择 ${_selectedMessages.length} 条',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.delete), onPressed: _batchDelete),
      ],
    );
  }

  Widget _buildErrorView() {
    final colors = MobileColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: _loadMessages, child: const Text('重试')),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    final colors = MobileColors.of(context);
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          '暂无消息，开始聊天吧~',
          style: TextStyle(color: colors.textTertiary, fontSize: 14),
        ),
      );
    }

    // 按时间分组消息
    final groupedMessages = _groupMessagesByTime();

    return GestureDetector(
      onTap: () {
        _focusNode.unfocus();
        _hideOverlay();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: groupedMessages.length,
        itemBuilder: (context, index) {
          final item = groupedMessages[index];
          if (item is String) {
            // 时间标签
            return _buildTimeLabel(item);
          } else if (item is DirectMessageItem) {
            return _buildMessageBubble(item);
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  List<dynamic> _groupMessagesByTime() {
    final List<dynamic> result = [];
    DateTime? lastTime;

    for (final message in _messages) {
      // 解析 UTC 时间并转换为本地时区，避免时区偏差
      final messageTime =
          DateTime.tryParse(message.createdAt)?.toUtc().toLocal() ??
          DateTime.now();
      final label = _formatTimeLabel(messageTime);

      if (lastTime == null || _shouldShowTimeLabel(lastTime, messageTime)) {
        result.add(label);
        lastTime = messageTime;
      }
      result.add(message);
    }

    return result;
  }

  bool _shouldShowTimeLabel(DateTime last, DateTime current) {
    return current.difference(last).inMinutes > 5;
  }

  String _formatTimeLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDay = DateTime(time.year, time.month, time.day);

    if (messageDay == today) {
      return '今天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (messageDay == yesterday) {
      return '昨天 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.month}/${time.day} ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildTimeLabel(String label) {
    final colors = MobileColors.of(context);
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
    );
  }

  bool _isRecalled(DirectMessageItem message) {
    return message.deliveryStatus == 'recalled';
  }

  DirectMessageItem _toRecalledMessage(DirectMessageItem message) {
    return message.copyWith(
      content: message.fromMe ? '你撤回了一条消息' : '对方撤回了一条消息',
      deliveryStatus: 'recalled',
      serverCanRecall: false,
    );
  }

  String _conversationPreviewText(List<DirectMessageItem> messages) {
    if (messages.isEmpty) return '开始聊天吧';
    final String content = messages.last.content.trim();
    return content.isEmpty ? '开始聊天吧' : content;
  }

  Widget _buildRecalledPlaceholder(DirectMessageItem message) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Text(
          message.content,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: colors.textTertiary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(DirectMessageItem message) {
    final colors = MobileColors.of(context);
    final isMe = message.fromMe;
    final isSelected = _selectedMessages.contains(message.id);
    if (_isRecalled(message)) {
      return _buildRecalledPlaceholder(message);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            // 对方头像（可点击进入对方主页）
            GestureDetector(
              onTap: widget.peerUserId != null
                  ? () => context.push('/user/${widget.peerUserId}')
                  : null,
              child: widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(
                        widget.peerAvatar!.startsWith('http')
                            ? widget.peerAvatar!
                            : AppConfig.resolveUrl(widget.peerAvatar!),
                      ),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: MobileTheme.primaryWithAlpha(
                        context,
                        0.1,
                      ),
                      child: Text(
                        (widget.peerName ?? '用户').substring(0, 1),
                        style: TextStyle(
                          fontSize: 12,
                          color: MobileTheme.primaryOf(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isMe
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                // 消息气泡
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _selectMode ? () => _toggleSelect(message) : null,
                  onLongPressStart: (details) =>
                      _showMessageOverlay(message, details.globalPosition),
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.7,
                    ),
                    decoration: BoxDecoration(
                      color: isMe
                          ? MobileTheme.primaryOf(context)
                          : colors.surface,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(isMe ? 18 : 4),
                        topRight: Radius.circular(isMe ? 4 : 18),
                        bottomLeft: const Radius.circular(18),
                        bottomRight: const Radius.circular(18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 引用块（Telegram 风格）
                        if (message.hasReply)
                          _buildQuotedMessage(message, isMe, colors),

                        // 正文
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text(
                            message.content,
                            style: TextStyle(
                              fontSize: 15,
                              color: isMe ? Colors.white : colors.textPrimary,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 发送失败重试
                if (isMe && message.deliveryStatus == 'failed')
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: GestureDetector(
                      onTap: () => _retrySend(message),
                      child: const Text(
                        '点击重试',
                        style: TextStyle(
                          fontSize: 11,
                          color: MobileTheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            // 自己头像（可点击进入个人主页）
            GestureDetector(
              onTap: _myUserId.isNotEmpty
                  ? () => context.push('/user/$_myUserId')
                  : null,
              child: _myAvatar.isNotEmpty
                  ? CircleAvatar(
                      radius: 16,
                      backgroundImage: CachedNetworkImageProvider(
                        _myAvatar.startsWith('http')
                            ? _myAvatar
                            : AppConfig.resolveUrl(_myAvatar),
                      ),
                    )
                  : CircleAvatar(
                      radius: 16,
                      backgroundColor: MobileTheme.primaryWithAlpha(
                        context,
                        0.1,
                      ),
                      child: Icon(
                        Icons.person,
                        size: 16,
                        color: MobileTheme.primaryOf(context),
                      ),
                    ),
            ),
          ],
          if (_selectMode)
            GestureDetector(
              onTap: () => _toggleSelect(message),
              child: Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(left: 6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? MobileTheme.primaryOf(context)
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? MobileTheme.primaryOf(context)
                        : colors.textTertiary,
                    width: 1.5,
                  ),
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
        ],
      ),
    );
  }

  void _showMessageOverlay(DirectMessageItem message, Offset globalPosition) {
    _hideOverlay(rebuild: false);
    HapticFeedback.mediumImpact();
    final media = MediaQuery.of(context);
    const double leftPadding = 8.0;
    const double rightPadding = 4.0;
    final double maxWidth = media.size.width - leftPadding - rightPadding;
    final int actionCount = message.canRecall ? 5 : 4;
    final double estimatedWidth = (actionCount * 62.0)
        .clamp(228.0, maxWidth)
        .toDouble();
    const double selfMessageHorizontalOffset = 6.0;
    const double actionBarHeightEstimate = 48.0;
    const double verticalGap = 8.0;
    final double left =
        (globalPosition.dx -
                estimatedWidth / 2 +
                (message.fromMe ? selfMessageHorizontalOffset : 0))
            .clamp(
              leftPadding,
              media.size.width - estimatedWidth - rightPadding,
            )
            .toDouble();
    final double top = (globalPosition.dy - actionBarHeightEstimate - verticalGap)
        .clamp(
          media.padding.top + 8.0,
          media.size.height - actionBarHeightEstimate - verticalGap,
        )
        .toDouble();

    _overlayEntry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          GestureDetector(
            onTap: _hideOverlay,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
          Positioned(
            left: left,
            top: top,
            child: _MessageActionBar(
              message: message,
              maxWidth: maxWidth,
              onCopy: () {
                Clipboard.setData(ClipboardData(text: message.content));
                _hideOverlay();
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
              },
              onForward: () => _openForwardPicker(message),
              onDetail: () => _showMessageDetail(message),
              onReply: () => _handleReply(message),
              onRecall: () => _handleRecall(message),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
    if (mounted) {
      setState(() {});
    }
  }

  void _hideOverlay({bool rebuild = true}) {
    if (_overlayEntry == null) return;
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (rebuild && mounted) {
      setState(() {});
    }
  }

  void _toggleSelect(DirectMessageItem message) {
    setState(() {
      if (_selectedMessages.contains(message.id)) {
        _selectedMessages.remove(message.id);
        if (_selectedMessages.isEmpty) {
          _selectMode = false;
        }
      } else {
        _selectedMessages.add(message.id);
      }
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selectMode = false;
      _selectedMessages.clear();
    });
  }

  Future<void> _batchDelete() async {
    if (_selectedMessages.isEmpty) return;
    final recallableIds = _messages
        .where(
          (message) =>
              _selectedMessages.contains(message.id) && message.canRecall,
        )
        .map((message) => message.id)
        .toSet();
    if (recallableIds.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('只能撤回 2 分钟内自己发送的消息')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('批量撤回'),
        content: Text('确定撤回选中的 ${recallableIds.length} 条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('撤回', style: TextStyle(color: MobileTheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(messageRepositoryProvider);
    for (final id in recallableIds) {
      await repo.recallMessage(
        conversationId: widget.conversationId,
        messageId: id,
      );
    }
    setState(() {
      _messages = _messages
          .map((m) => recallableIds.contains(m.id) ? _toRecalledMessage(m) : m)
          .toList();
      _selectedMessages.clear();
      _selectMode = false;
      if (_replyingTo != null && recallableIds.contains(_replyingTo!.id)) {
        _replyingTo = null;
      }
    });
    ref
        .read(messagesControllerProvider.notifier)
        .updateConversationPreview(
          conversationId: widget.conversationId,
          message: _conversationPreviewText(_messages),
        );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已撤回 ${recallableIds.length} 条消息')),
      );
    }
  }

  Future<void> _handleRecall(DirectMessageItem message) async {
    _hideOverlay();
    if (!message.canRecall) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('只能撤回 2 分钟内自己发送的消息')));
      return;
    }
    final recalledLastMessage =
        _messages.isNotEmpty && _messages.last.id == message.id;
    try {
      await ref
          .read(messageRepositoryProvider)
          .recallMessage(
            conversationId: widget.conversationId,
            messageId: message.id,
          );
      setState(() {
        final int index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = _toRecalledMessage(_messages[index]);
        }
        _selectedMessages.remove(message.id);
        if (_replyingTo?.id == message.id) {
          _replyingTo = null;
        }
      });
      if (recalledLastMessage) {
        ref
            .read(messagesControllerProvider.notifier)
            .updateConversationPreview(
              conversationId: widget.conversationId,
              message: _conversationPreviewText(_messages),
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('消息已撤回')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('撤回失败: $e')));
      }
    }
  }

  String _formatFullTime(String createdAt) {
    final dt =
        DateTime.tryParse(createdAt)?.toUtc().toLocal() ?? DateTime.now();
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  void _showMessageDetail(DirectMessageItem message) {
    _hideOverlay();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('消息详情'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailRow('发送时间', _formatFullTime(message.createdAt)),
            _detailRow('发送方', message.fromMe ? '我' : message.senderAlias),
            _detailRow(
              '状态',
              message.deliveryStatus == 'read'
                  ? '已送达'
                  : message.deliveryStatus == 'sent'
                  ? '已发送'
                  : message.deliveryStatus == 'failed'
                  ? '发送失败'
                  : message.deliveryStatus,
            ),
            if (!message.fromMe && message.isRead) _detailRow('已读状态', '已读'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(color: colors.textTertiary, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPrimary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _openForwardPicker(DirectMessageItem message) {
    _hideOverlay();
    final conversations = ref.read(messagesControllerProvider).conversations;
    final available = conversations
        .where((c) => !c.isBlocked && c.id != widget.conversationId)
        .toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: MobileColors.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              '转发给',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                '暂无其他会话',
                style: TextStyle(color: MobileTheme.textTertiary),
              ),
            )
          else
            ...available.map(
              (c) => ListTile(
                leading: CircleAvatar(
                  radius: 18,
                  backgroundColor: MobileTheme.primaryWithAlpha(context, 0.1),
                  backgroundImage: c.avatarUrl.isNotEmpty
                      ? CachedNetworkImageProvider(
                          c.avatarUrl.startsWith('http')
                              ? c.avatarUrl
                              : AppConfig.resolveUrl(c.avatarUrl),
                        )
                      : null,
                  child: c.avatarUrl.isEmpty
                      ? Icon(
                          Icons.person,
                          color: MobileTheme.primaryOf(context),
                          size: 18,
                        )
                      : null,
                ),
                title: Text(c.name),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(messageRepositoryProvider)
                        .sendConversationMessage(
                          conversationId: c.id,
                          content: '[转发] ${message.content}',
                        );
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(const SnackBar(content: Text('已转发')));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('转发失败: $e')));
                    }
                  }
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  void _handleReply(DirectMessageItem message) {
    _hideOverlay();
    setState(() => _replyingTo = message);
    _focusNode.requestFocus();
  }

  void _retrySend(DirectMessageItem failedMessage) {
    setState(() {
      _messages.removeWhere((m) => m.id == failedMessage.id);
    });
    _messageController.text = failedMessage.content;
    _handleSend();
  }

  /// 气泡内引用块（Telegram 风格：半透明背景 + 左侧竖线 + 发送人 + 截断内容）
  Widget _buildQuotedMessage(
    DirectMessageItem message,
    bool isMe,
    MobileColors colors,
  ) {
    final quoteColor = isMe
        ? Colors.white.withValues(alpha: 0.25)
        : MobileTheme.primaryWithAlpha(context, 0.08);
    final accentColor = isMe
        ? Colors.white.withValues(alpha: 0.85)
        : MobileTheme.primaryOf(context);
    final textColor = isMe
        ? Colors.white.withValues(alpha: 0.9)
        : colors.textSecondary;

    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      decoration: BoxDecoration(
        color: quoteColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 左侧竖线
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 发送人名称
                    Text(
                      message.replyToSender ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    // 被引用内容（截断至2行）
                    Text(
                      message.replyToContent ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: textColor,
                        height: 1.3,
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

  Widget _buildInputArea() {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 回复预览条
            if (_replyingTo != null) _buildReplyPreviewBar(colors),

            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(
                        maxHeight: 120,
                        minHeight: 36,
                      ),
                      decoration: BoxDecoration(
                        color: colors.background,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        style: TextStyle(
                          fontSize: 16,
                          color: colors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: '输入消息...',
                          hintStyle: TextStyle(
                            color: colors.textTertiary,
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _canSend() ? _handleSend : null,
                    child: Container(
                      width: 44,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _canSend()
                            ? MobileTheme.primaryOf(context)
                            : colors.textTertiary.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: _isSending
                          ? const Center(
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 输入框上方的回复预览条（Telegram 风格）
  Widget _buildReplyPreviewBar(MobileColors colors) {
    final msg = _replyingTo!;
    final isMe = msg.fromMe;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 4),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          // 左侧彩色竖线
          Container(
            width: 3,
            height: 36,
            decoration: BoxDecoration(
              color: MobileTheme.primaryOf(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isMe ? '我' : msg.senderAlias,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MobileTheme.primaryOf(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  msg.content,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                ),
              ],
            ),
          ),
          // 关闭按钮
          IconButton(
            icon: Icon(Icons.close, size: 18, color: colors.textTertiary),
            onPressed: () => setState(() => _replyingTo = null),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  bool _canSend() => _messageController.text.trim().isNotEmpty && !_isSending;

  Widget _buildFirstMessageBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      color: const Color(0xFFFFF8E1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(0xFFF59E0B)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '你与对方尚未建立会话。在对方回复或关注你之前，你只能发送一条消息，请谨慎措辞。',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF92400E),
                height: 1.4,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _firstMessageWarningDismissed = true),
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsSheet() {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: MobileTheme.error,
              ),
              title: const Text('删除会话'),
              onTap: () {
                Navigator.pop(context);
                _confirmDeleteConversation();
              },
            ),
            ListTile(
              leading: Icon(
                _blockedByMe ? Icons.check_circle_outline : Icons.block,
                color: MobileTheme.error,
              ),
              title: Text(_blockedByMe ? '解除屏蔽' : '屏蔽对方'),
              onTap: () {
                Navigator.pop(context);
                _confirmBlockUser();
              },
            ),
            ListTile(
              leading: Icon(
                Icons.person_add_outlined,
                color: MobileTheme.primaryOf(context),
              ),
              title: const Text('查看对方主页'),
              onTap: () {
                Navigator.pop(context);
                if (widget.peerUserId != null) {
                  context.push('/user/${widget.peerUserId}');
                }
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteConversation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除会话'),
        content: const Text('确定要删除这个会话吗？删除后双方聊天记录都将消失。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                ref
                    .read(messagesControllerProvider.notifier)
                    .deleteConversation(widget.conversationId);
                if (mounted) {
                  context.pop();
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('会话已删除')));
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _confirmBlockUser() {
    final isBlocking = !_blockedByMe;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isBlocking ? '屏蔽对方' : '解除屏蔽'),
        content: Text(
          isBlocking ? '确定要屏蔽对方吗？屏蔽后对方将无法给你发送消息。' : '确定要解除屏蔽吗？解除后对方可以继续给你发消息。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                final messageRepo = ref.read(messageRepositoryProvider);
                await messageRepo.updateConversationBlock(
                  conversationId: widget.conversationId,
                  block: isBlocking,
                );
                if (mounted) {
                  setState(() => _blockedByMe = isBlocking);
                  ref
                      .read(messagesControllerProvider.notifier)
                      .updateConversationFlags(
                        conversationId: widget.conversationId,
                        blockedByMe: isBlocking,
                      );
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(isBlocking ? '已屏蔽对方' : '已解除屏蔽')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('操作失败: $e')));
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: isBlocking
                  ? MobileTheme.error
                  : MobileTheme.primaryOf(context),
            ),
            child: Text(isBlocking ? '屏蔽' : '解除屏蔽'),
          ),
        ],
      ),
    );
  }
}

class _MessageActionBar extends StatelessWidget {
  final DirectMessageItem message;
  final double maxWidth;
  final VoidCallback onCopy;
  final VoidCallback onForward;
  final VoidCallback onDetail;
  final VoidCallback onReply;
  final VoidCallback onRecall;

  const _MessageActionBar({
    required this.message,
    required this.maxWidth,
    required this.onCopy,
    required this.onForward,
    required this.onDetail,
    required this.onReply,
    required this.onRecall,
  });

  @override
  Widget build(BuildContext context) {
    final isRecallable = message.canRecall;

    final buttons = <Widget>[];
    buttons.add(_actionButton(Icons.content_copy, '复制', onCopy));
    buttons.add(_actionButton(Icons.ios_share, '转发', onForward));
    buttons.add(_actionButton(Icons.info_outline, '详情', onDetail));
    buttons.add(_actionButton(Icons.reply, '回复', onReply));
    if (isRecallable) {
      buttons.add(_actionButton(Icons.undo, '撤回', onRecall));
    }

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      color: const Color(0xFF4A4A4A),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: IntrinsicHeight(
            child: Row(mainAxisSize: MainAxisSize.min, children: buttons),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
