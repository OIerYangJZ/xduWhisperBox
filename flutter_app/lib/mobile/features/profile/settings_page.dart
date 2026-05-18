import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadProfile();
    });
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    setState(() {
      _saving = true;
    });

    try {
      await ref
          .read(userRepositoryProvider)
          .updatePrivacy(
            allowStrangerDm: allowStrangerDm,
            showContactable: showContactable,
          );
      if (!mounted) return;
      setState(() {
        _profile = _profile?.copyWith(
          allowStrangerDm: allowStrangerDm,
          showContactable: showContactable,
        );
      });
      _showToast('隐私设置已更新');
    } catch (e) {
      if (!mounted) return;
      _showToast('设置失败：${e.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

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
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('隐私设置'),
        backgroundColor: colors.surface,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: MobileTheme.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: MobileTheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: MobileTheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                // 隐私设置
                Container(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.divider.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        icon: Icons.chat_bubble_outline,
                        iconColor: MobileTheme.primaryOf(context),
                        title: '允许陌生人私信',
                        subtitle: '关闭后，其他人无法通过你的公开主页或帖子给你发起私信',
                        value: _profile?.allowStrangerDm ?? false,
                        onChanged: _saving
                            ? null
                            : (value) => _updatePrivacy(
                                allowStrangerDm: value,
                                showContactable:
                                    _profile?.showContactable ?? false,
                              ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: Divider(
                          height: 1,
                          thickness: 0.5,
                          color: colors.divider,
                        ),
                      ),
                      _buildSwitchTile(
                        icon: Icons.visibility_outlined,
                        iconColor: MobileTheme.accent,
                        title: '显示"可联系"状态',
                        subtitle: '开启后，其他用户可以看到你的联系方式',
                        value: _profile?.showContactable ?? false,
                        onChanged: _saving
                            ? null
                            : (value) => _updatePrivacy(
                                allowStrangerDm:
                                    _profile?.allowStrangerDm ?? false,
                                showContactable: value,
                              ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // 退出登录
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MobileTheme.error,
                      side: const BorderSide(color: MobileTheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('退出登录'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 22, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: MobileTheme.primaryOf(context),
          ),
        ],
      ),
    );
  }
}
