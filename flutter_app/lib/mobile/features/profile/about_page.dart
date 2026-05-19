import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';
import '../../features/update/app_update_controller.dart';
import '../../features/update/app_update_dialog.dart';

class AboutPage extends ConsumerStatefulWidget {
  const AboutPage({super.key});

  @override
  ConsumerState<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends ConsumerState<AboutPage> {
  Future<void> _handleCheckUpdate() async {
    final controller = ref.read(appUpdateProvider);
    final hasUpdate = await controller.checkForUpdates(clearError: true);
    if (!mounted) return;
    if (hasUpdate && controller.latestRelease != null) {
      await showAppUpdateDialog(
        context,
        release: controller.latestRelease!,
        currentVersionLabel: controller.currentVersionLabel,
      );
      return;
    }
    if (controller.error != null && controller.error!.trim().isNotEmpty) {
      _showToast('检查更新失败：${controller.error}');
      return;
    }
    _showToast('当前已是最新版本');
  }

  String _updateSubtitle(AppUpdateController controller) {
    final current = '当前版本 ${controller.currentVersionLabel}';
    if (controller.hasUpdate && controller.latestRelease != null) {
      return '$current · 最新版本 ${controller.latestVersionLabel}';
    }
    return current;
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final updateController = ref.watch(appUpdateProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('关于与支持'),
        backgroundColor: colors.background,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: MobileTheme.primaryOf(context),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: MobileTheme.primaryOf(context).withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.wb_sunny_rounded, size: 50, color: Colors.white),
                ),
                const SizedBox(height: 16),
                const Text(
                  'See电',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  '西电校内匿名社区',
                  style: TextStyle(fontSize: 14, color: colors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version ${updateController.currentVersionLabel}',
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildTileCard([
            _buildListTile(
              icon: Icons.download_outlined,
              title: '下载 Android 客户端',
              subtitle: '检查并下载最新安装包',
              onTap: _handleCheckUpdate,
            ),
            _buildListTile(
              icon: updateController.hasUpdate
                  ? Icons.system_update_alt_rounded
                  : Icons.system_update_alt_outlined,
              title: '检查更新',
              subtitle: _updateSubtitle(updateController),
              trailing: updateController.checking
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: MobileTheme.primaryOf(context),
                      ),
                    )
                  : updateController.hasUpdate
                      ? const _UpdateBadge(label: '有新版本')
                      : null,
              onTap: updateController.checking ? null : _handleCheckUpdate,
            ),
          ]),
          _buildTileCard([
            _buildListTile(
              icon: Icons.description_outlined,
              title: '用户协议',
              subtitle: '查看平台服务条款',
              onTap: () => context.push('/legal/terms'),
            ),
            _buildListTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私政策',
              subtitle: '查看个人信息与数据处理说明',
              onTap: () => context.push('/legal/privacy'),
            ),
            _buildListTile(
              icon: Icons.gavel_outlined,
              title: '社区规范',
              subtitle: '了解发帖与互动规则',
              onTap: () => context.push('/legal/guidelines'),
            ),
            _buildListTile(
              icon: Icons.flag_outlined,
              title: '举报说明',
              subtitle: '了解举报受理与处理流程',
              onTap: () => context.push('/legal/report'),
            ),
          ]),
          _buildTileCard([
            _buildListTile(
              icon: Icons.help_outline,
              title: '帮助与反馈',
              subtitle: '问题反馈、联系方式与常见问题',
              onTap: () => context.push('/profile/help-feedback'),
            ),
            _buildListTile(
              icon: Icons.favorite_outline,
              title: '致谢页',
              subtitle: '感谢每一位参与建设与反馈的同学',
              onTap: () => context.push('/profile/acknowledgements'),
            ),
          ]),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '© 2026 XDU Whisper Box',
              style: TextStyle(fontSize: 11, color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTileCard(List<Widget> children) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      child: Column(
        children: List<Widget>.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(height: 0.5, indent: 56, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Widget? trailing,
  }) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: Icon(icon, color: colors.textSecondary, size: 20),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 18),
      onTap: onTap,
    );
  }
}

class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MobileTheme.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: MobileTheme.warning,
        ),
      ),
    );
  }
}
