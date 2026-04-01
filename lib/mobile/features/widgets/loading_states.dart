import 'package:flutter/material.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

// ---------------------------------------------------------------------------
// 全屏 Loading 遮罩
// ---------------------------------------------------------------------------

/// 全屏加载遮罩层
class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: primaryColor,
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        message!,
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 带 Loading 状态的按钮
// ---------------------------------------------------------------------------

/// 带 loading 状态的按钮，防止重复点击
class LoadingButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final String label;
  final bool isLoading;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final double? width;
  final bool isOutlined;

  const LoadingButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.isLoading = false,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.isOutlined = false,
  });

  @override
  State<LoadingButton> createState() => _LoadingButtonState();
}

class _LoadingButtonState extends State<LoadingButton> {
  bool get _enabled => widget.onPressed != null && !widget.isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final bgColor = widget.backgroundColor ?? MobileTheme.primaryOf(context);
    final fgColor = widget.foregroundColor ?? Colors.white;

    if (widget.isOutlined) {
      return SizedBox(
        width: widget.width,
        height: 48,
        child: OutlinedButton(
          onPressed: _enabled ? widget.onPressed : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: bgColor,
            side: BorderSide(color: _enabled ? bgColor : colors.textTertiary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _buildChild(bgColor),
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: 48,
      child: ElevatedButton(
        onPressed: _enabled ? widget.onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: _enabled ? bgColor : colors.textTertiary,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: _buildChild(fgColor),
      ),
    );
  }

  Widget _buildChild(Color color) {
    if (widget.isLoading) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }
    return Text(
      widget.label,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    );
  }
}

// ---------------------------------------------------------------------------
// 错误重试组件
// ---------------------------------------------------------------------------

/// 错误重试状态组件，适用于各列表页
class ErrorRetryWidget extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  final IconData? icon;

  const ErrorRetryWidget({
    super.key,
    this.message,
    required this.onRetry,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon ?? Icons.wifi_off_rounded,
              size: 64,
              color: colors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              message ?? '加载失败，请稍后重试',
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 异步状态包装器
// ---------------------------------------------------------------------------

/// 异步数据加载状态枚举
enum AsyncState { idle, loading, success, error }

/// 异步操作状态包装组件
/// 简化页面中常见的 loading / error / empty / content 分支渲染
class AsyncPageState extends StatelessWidget {
  /// 当前状态
  final AsyncState state;

  /// 加载中显示的内容（可选，默认显示居中 loading）
  final Widget? loadingWidget;

  /// 错误时显示的内容（可选，默认显示 ErrorRetryWidget）
  final Widget? errorWidget;

  /// 空状态时显示的内容（可选）
  final Widget? emptyWidget;

  /// 成功时显示的子组件
  final Widget child;

  /// 错误消息（传给默认 errorWidget）
  final String? errorMessage;

  /// 重试回调（传给默认 errorWidget）
  final VoidCallback? onRetry;

  const AsyncPageState({
    super.key,
    required this.state,
    required this.child,
    this.loadingWidget,
    this.errorWidget,
    this.emptyWidget,
    this.errorMessage,
    this.onRetry,
  });

  /// 快捷构造：loading 状态
  const AsyncPageState.loading({super.key, this.loadingWidget})
    : state = AsyncState.loading,
      errorWidget = null,
      emptyWidget = null,
      child = const SizedBox.shrink(),
      errorMessage = null,
      onRetry = null;

  /// 快捷构造：错误状态
  const AsyncPageState.error({
    super.key,
    required this.errorMessage,
    required this.onRetry,
    this.errorWidget,
  }) : state = AsyncState.error,
       emptyWidget = null,
       loadingWidget = null,
       child = const SizedBox.shrink();

  /// 快捷构造：空状态
  const AsyncPageState.empty({super.key, required this.emptyWidget})
    : state = AsyncState.idle,
      errorWidget = null,
      loadingWidget = null,
      child = const SizedBox.shrink(),
      errorMessage = null,
      onRetry = null;

  @override
  Widget build(BuildContext context) {
    final primaryColor = MobileTheme.primaryOf(context);
    switch (state) {
      case AsyncState.loading:
      case AsyncState.idle:
        return loadingWidget ??
            Center(child: CircularProgressIndicator(color: primaryColor));
      case AsyncState.error:
        return errorWidget ??
            ErrorRetryWidget(
              message: errorMessage ?? '未知错误',
              onRetry: onRetry ?? () {},
            );
      case AsyncState.success:
        return child;
    }
  }
}
