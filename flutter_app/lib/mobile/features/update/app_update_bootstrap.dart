import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xdu_treehole_web/mobile/core/state/mobile_providers.dart';

import 'app_update_dialog.dart';

class AppUpdateBootstrap extends ConsumerStatefulWidget {
  const AppUpdateBootstrap({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppUpdateBootstrap> createState() => _AppUpdateBootstrapState();
}

class _AppUpdateBootstrapState extends ConsumerState<AppUpdateBootstrap> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) {
      return;
    }
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupCheck();
    });
  }

  Future<void> _runStartupCheck() async {
    final controller = ref.read(appUpdateProvider);
    await controller.checkForUpdates(clearError: true);
    if (!mounted || !controller.consumeStartupPrompt()) {
      return;
    }
    final release = controller.latestRelease;
    if (release == null) {
      return;
    }
    await showAppUpdateDialog(
      context,
      release: release,
      currentVersionLabel: controller.currentVersionLabel,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
