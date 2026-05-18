import 'package:flutter/material.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

/// 评论输入框组件
/// 固定在底部，支持表情和图片附件
class CommentInputBar extends StatefulWidget {
  final Function(String) onSubmit;
  final String? placeholder;
  final bool autofocus;
  final ScrollController? scrollController;
  final VoidCallback? onEmojiToggle;
  final ValueChanged<bool>? onFocusChanged;
  final VoidCallback? onTextFieldTap;

  const CommentInputBar({
    super.key,
    required this.onSubmit,
    this.placeholder = '写下你的评论...',
    this.autofocus = false,
    this.scrollController,
    this.onEmojiToggle,
    this.onFocusChanged,
    this.onTextFieldTap,
  });

  @override
  State<CommentInputBar> createState() => _CommentInputBarState();
}

class _CommentInputBarState extends State<CommentInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    widget.onFocusChanged?.call(_focusNode.hasFocus);
    if (_focusNode.hasFocus && widget.scrollController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.scrollController!.hasClients) {
          widget.scrollController!.animateTo(
            widget.scrollController!.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    widget.onSubmit(text);
    _controller.clear();
    setState(() {
      _hasText = false;
    });
  }

  /// 供父组件调用，插入表情到输入框
  void insertEmoji(String emoji) {
    final text = _controller.text;
    final selection = _controller.selection;
    final newText = text.replaceRange(selection.start, selection.end, emoji);
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selection.start + emoji.length,
      ),
    );
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  void unfocus() {
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 8, 8, 8 + bottomInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 表情按钮
          GestureDetector(
            onTap: widget.onEmojiToggle,
            child: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                Icons.emoji_emotions_outlined,
                color: colors.textSecondary,
                size: 24,
              ),
            ),
          ),

          // 输入框
          Expanded(
            child: Container(
              constraints: const BoxConstraints(maxHeight: 120, minHeight: 36),
              decoration: BoxDecoration(
                color: colors.background,
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                onTap: widget.onTextFieldTap,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                style: TextStyle(fontSize: 15, color: colors.textPrimary),
                decoration: InputDecoration(
                  hintText: widget.placeholder,
                  hintStyle: TextStyle(
                    color: colors.textTertiary,
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // 发送按钮
          GestureDetector(
            onTap: _hasText ? _submit : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _hasText
                    ? MobileTheme.primaryOf(context)
                    : colors.textTertiary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '发送',
                style: TextStyle(
                  color: _hasText ? Colors.white : colors.textTertiary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 表情选择面板，从页面底部弹出
class EmojiPickerBar extends StatelessWidget {
  final void Function(String emoji) onEmojiTap;

  const EmojiPickerBar({super.key, required this.onEmojiTap});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final emojis = [
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤗',
      '🤭',
      '🤫',
      '🤔',
      '🤐',
      '🤨',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '😮‍💨',
      '🤥',
      '😌',
      '😔',
      '😪',
      '🤤',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🤧',
      '🥵',
      '🥶',
      '🥴',
      '😵',
      '🤯',
      '🤠',
      '🥳',
      '😎',
      '🤓',
      '😕',
      '😟',
      '🙁',
      '😮',
      '😯',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😰',
      '😥',
      '😢',
      '😭',
      '😱',
      '👍',
      '👎',
      '👏',
      '🙌',
      '🤝',
      '🙏',
      '💪',
      '🤘',
    ];

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: emojis.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => onEmojiTap(emojis[index]),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }
}
