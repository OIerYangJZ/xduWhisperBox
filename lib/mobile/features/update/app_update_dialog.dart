import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/core/utils/browser_download.dart';
import 'package:xdu_treehole_web/models/app_release_item.dart';
import 'package:xdu_treehole_web/mobile/core/theme/mobile_colors.dart';
import 'package:xdu_treehole_web/mobile/core/theme/mobile_theme.dart';

Future<void> showAppUpdateDialog(
  BuildContext context, {
  required AppReleaseItem release,
  required String currentVersionLabel,
}) {
  final String resolvedUrl = AppConfig.resolveUrl(release.downloadUrl);
  return showDialog<void>(
    context: context,
    barrierDismissible: !release.forceUpdate,
    builder: (dialogContext) {
      final colors = MobileColors.of(dialogContext);
      return PopScope(
        canPop: !release.forceUpdate,
        child: Dialog(
          backgroundColor: colors.cardBackground,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.divider, width: 0.5),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: MobileTheme.primaryWithAlpha(context, 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.system_update_alt_rounded,
                            color: MobileTheme.primaryOf(context),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                release.forceUpdate ? '发现重要更新' : '发现新版本',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '最新版本 ${_versionLabel(release)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _InfoBlock(
                      title: '版本信息',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: '当前版本', value: currentVersionLabel),
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: '最新版本',
                            value: _versionLabel(release),
                          ),
                          const SizedBox(height: 8),
                          _InfoRow(
                            label: '更新类型',
                            value: release.forceUpdate ? '强制更新' : '可选更新',
                            valueColor: release.forceUpdate
                                ? MobileTheme.warning
                                : colors.textPrimary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '更新说明',
                      child: Text(
                        release.releaseNotes.trim().isEmpty
                            ? '本次版本暂无额外说明。'
                            : release.releaseNotes.trim(),
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoBlock(
                      title: '安装包信息',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _InfoChip(text: release.fileName),
                          _InfoChip(text: _formatFileSize(release.sizeBytes)),
                          if (release.uploadedAt.trim().isNotEmpty)
                            _InfoChip(text: release.uploadedAt.trim()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (!release.forceUpdate)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('稍后再说'),
                            ),
                          ),
                        if (!release.forceUpdate) const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final bool started = await triggerBrowserDownload(
                                resolvedUrl,
                              );
                              if (context.mounted) {
                                if (started) {
                                  Navigator.of(dialogContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('已开始下载新版本')),
                                  );
                                } else {
                                  await Clipboard.setData(
                                    ClipboardData(text: resolvedUrl),
                                  );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('无法直接下载，已复制更新链接'),
                                      ),
                                    );
                                  }
                                }
                              }
                            },
                            icon: const Icon(Icons.download_outlined),
                            label: const Text('立即更新'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 13, color: colors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: valueColor ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

String _versionLabel(AppReleaseItem release) {
  if (release.versionCode > 0) {
    return '${release.versionName}（${release.versionCode}）';
  }
  return release.versionName;
}

String _formatFileSize(int sizeBytes) {
  if (sizeBytes < 1024) {
    return '$sizeBytes B';
  }
  final double kb = sizeBytes / 1024;
  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }
  final double mb = kb / 1024;
  return '${mb.toStringAsFixed(2)} MB';
}
