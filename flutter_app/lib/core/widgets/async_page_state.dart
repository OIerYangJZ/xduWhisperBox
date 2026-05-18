import 'package:flutter/material.dart';

class AsyncPageState extends StatelessWidget {
  const AsyncPageState({
    super.key,
    required this.loading,
    required this.error,
    required this.child,
    this.onRetry,
    this.loadingLabel,
    this.emptyFallback,
  });

  final bool loading;
  final String? error;
  final Widget child;
  final VoidCallback? onRetry;
  final String? loadingLabel;
  final Widget? emptyFallback;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            if (loadingLabel != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(loadingLabel!),
            ],
          ],
        ),
      );
    }

    if (error != null && (emptyFallback != null)) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _ErrorBanner(message: error!, onRetry: onRetry),
          const SizedBox(height: 12),
          emptyFallback!,
        ],
      );
    }

    return Column(
      children: <Widget>[
        if (error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: _ErrorBanner(message: error!, onRetry: onRetry),
          ),
        Expanded(child: child),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: Colors.red),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              child: const Text('重试'),
            ),
        ],
      ),
    );
  }
}
