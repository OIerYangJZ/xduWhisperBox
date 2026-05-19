import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class SettingsMainPage extends ConsumerStatefulWidget {
  const SettingsMainPage({super.key});

  @override
  ConsumerState<SettingsMainPage> createState() => _SettingsMainPageState();
}

class _SettingsMainPageState extends ConsumerState<SettingsMainPage> {
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出当前账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确定退出'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(authRepositoryProvider).logout();
    } catch (_) {}
    AuthStore.instance.clear();
    if (!mounted) return;
    context.go('/auth/login');
  }

  void _showToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final user = AuthStore.instance.currentUser;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // 用户简要信息
          if (user != null)
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: colors.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: colors.divider.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: MobileTheme.primaryOf(
                      context,
                    ).withValues(alpha: 0.1),
                    child: Text(
                      (user.nickname.isNotEmpty ? user.nickname[0] : '?')
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: MobileTheme.primaryOf(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.nickname,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
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
            ),

          _buildSectionTitle('通用设置'),
          _buildTileCard([
            _buildMenuTile(
              icon: Icons.lock_outline,
              title: '账号与安全',
              subtitle: '修改密码、用户等级、注销账号',
              onTap: () => context.push('/profile/settings/account'),
            ),
            _buildMenuTile(
              icon: Icons.privacy_tip_outlined,
              title: '隐私设置',
              subtitle: '私信权限、可见性管理',
              onTap: () => context.push('/profile/settings/privacy'),
            ),
            _buildMenuTile(
              icon: Icons.notifications_none_outlined,
              title: '通知设置',
              subtitle: '推送消息、提醒项管理',
              onTap: () => context.push('/profile/settings/notifications'),
            ),
          ]),

          _buildSectionTitle('校园工具 (XDYou)'),
          _buildTileCard([
            _buildMenuTile(
              icon: Icons.school_outlined,
              title: '课表与教务',
              subtitle: '课表显示设置、学号绑定',
              onTap: () {
                _showToast('校园工具设置正在迁移中，敬请期待');
              },
            ),
          ]),

          _buildSectionTitle('偏好设置'),
          _buildTileCard([
            _buildMenuTile(
              icon: Icons.palette_outlined,
              title: '界面外观',
              subtitle: '深色模式、多语言',
              onTap: () => context.push('/profile/settings/display'),
            ),
          ]),

          _buildSectionTitle('其他'),
          _buildTileCard([
            _buildMenuTile(
              icon: Icons.info_outline,
              title: '关于与支持',
              subtitle: '版本更新、法律协议、帮助反馈',
              onTap: () => context.push('/profile/settings/about'),
            ),
          ]),

          const SizedBox(height: 24),

          // 退出登录按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: OutlinedButton(
              onPressed: _logout,
              style: OutlinedButton.styleFrom(
                foregroundColor: MobileTheme.error,
                side: BorderSide(color: colors.divider, width: 0.8),
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '退出登录',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: Text(
              '西电树洞 See电',
              style: TextStyle(
                fontSize: 12,
                color: colors.textTertiary.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildTileCard(List<Widget> children) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colors.divider.withValues(alpha: 0.5),
          width: 0.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: List<Widget>.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) {
            return Divider(
              height: 0.5,
              indent: 56,
              color: colors.divider.withValues(alpha: 0.5),
            );
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = MobileColors.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: colors.textSecondary, size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textTertiary),
      ),
      trailing: Icon(Icons.chevron_right, size: 20, color: colors.textTertiary),
      onTap: onTap,
    );
  }
}
