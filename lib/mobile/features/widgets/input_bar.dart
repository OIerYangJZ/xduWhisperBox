import 'package:flutter/material.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

/// 通用底部输入框组件
/// 支持文本输入、发送按钮、图片/表情附件按钮、键盘弹出交互适配
class InputBar extends StatefulWidget {
  /// 发送回调
  final void Function(String text) onSubmit;

  /// 提示文字
  final String? placeholder;

  /// 自动聚焦
  final bool autofocus;

  /// 发送按钮文字
  final String sendLabel;

  /// 是否显示表情按钮
  final bool showEmoji;

  /// 是否显示图片按钮
  final bool showImage;

  /// 表情按钮点击回调（如果提供，表情按钮可用）
  final VoidCallback? onEmojiTap;

  /// 图片按钮点击回调
  final VoidCallback? onImageTap;

  /// 发送前校验回调，返回 true 才发送
  final bool Function(String text)? onValidate;

  const InputBar({
    super.key,
    required this.onSubmit,
    this.placeholder,
    this.autofocus = false,
    this.sendLabel = '发送',
    this.showEmoji = true,
    this.showImage = false,
    this.onEmojiTap,
    this.onImageTap,
    this.onValidate,
  });

  @override
  State<InputBar> createState() => InputBarState();
}

class InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focusNode.removeListener(_onFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onFocusChanged() {
    // 子类可通过覆写此方法响应焦点变化
  }

  /// 暴露给外部：清空输入框
  void clear() {
    _controller.clear();
    setState(() => _hasText = false);
  }

  /// 暴露给外部：追加文本（如插入 emoji）
  void appendText(String text) {
    final selection = _controller.selection;
    final newText = _controller.text.replaceRange(
      selection.start,
      selection.end,
      text,
    );
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: selection.start + text.length),
    );
  }

  /// 暴露给外部：获取当前文本
  String get text => _controller.text;

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    if (widget.onValidate != null && !widget.onValidate!(text)) return;

    widget.onSubmit(text);
    _controller.clear();
    setState(() => _hasText = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
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
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 表情按钮
              if (widget.showEmoji)
                GestureDetector(
                  onTap: () {
                    widget.onEmojiTap?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.emoji_emotions_outlined,
                      color: colors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),

              // 图片按钮
              if (widget.showImage)
                GestureDetector(
                  onTap: () {
                    widget.onImageTap?.call();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.image_outlined,
                      color: colors.textSecondary,
                      size: 24,
                    ),
                  ),
                ),

              // 输入框
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: 120,
                    minHeight: 36,
                  ),
                  decoration: BoxDecoration(
                    color: colors.background,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                    style: TextStyle(fontSize: 15, color: colors.textPrimary),
                    decoration: InputDecoration(
                      hintText: widget.placeholder ?? '说点什么...',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _hasText
                        ? primaryColor
                        : colors.textTertiary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Text(
                    widget.sendLabel,
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
        ),
      ),
    );
  }
}
