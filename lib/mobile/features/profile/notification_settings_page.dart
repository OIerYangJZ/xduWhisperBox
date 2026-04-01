import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error.toString().replaceAll('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _updateNotificationPreferences({
    bool? notifyComment,
    bool? notifyReply,
    bool? notifyLike,
    bool? notifyFavorite,
    bool? notifyReportResult,
    bool? notifySystem,
  }) async {
    final current = _profile;
    if (current == null) {
      return;
    }
    final next = current.copyWith(
      notifyComment: notifyComment ?? current.notifyComment,
      notifyReply: notifyReply ?? current.notifyReply,
      notifyLike: notifyLike ?? current.notifyLike,
      notifyFavorite: notifyFavorite ?? current.notifyFavorite,
      notifyReportResult: notifyReportResult ?? current.notifyReportResult,
      notifySystem: notifySystem ?? current.notifySystem,
    );

    setState(() {
      _saving = true;
      _profile = next;
    });
    try {
      await ref
          .read(userRepositoryProvider)
          .updateNotificationPreferences(
            notifyComment: next.notifyComment,
            notifyReply: next.notifyReply,
            notifyLike: next.notifyLike,
            notifyFavorite: next.notifyFavorite,
            notifyReportResult: next.notifyReportResult,
            notifySystem: next.notifySystem,
          );
      _showToast('通知设置已更新');
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _profile = current);
      _showToast('设置失败：${error.toString().replaceAll('Exception: ', '')}');
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showToast(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final profile = _profile;
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('通知设置'),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                if (_error != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: MobileTheme.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: MobileTheme.error),
                    ),
                  ),
                _SectionTitle(title: '站内通知'),
                _tileCard([
                  _SwitchTile(
                    title: '评论通知',
                    subtitle: '有人评论你的帖子时提醒',
                    value: profile?.notifyComment ?? true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _updateNotificationPreferences(notifyComment: value),
                  ),
                  _SwitchTile(
                    title: '回复通知',
                    subtitle: '有人回复你的评论时提醒',
                    value: profile?.notifyReply ?? true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _updateNotificationPreferences(notifyReply: value),
                  ),
                  _SwitchTile(
                    title: '点赞通知',
                    subtitle: '帖子或评论被点赞时提醒',
                    value: profile?.notifyLike ?? true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _updateNotificationPreferences(notifyLike: value),
                  ),
                  _SwitchTile(
                    title: '收藏通知',
                    subtitle: '帖子被收藏时提醒',
                    value: profile?.notifyFavorite ?? true,
                    onChanged: _saving
                        ? null
                        : (value) => _updateNotificationPreferences(
                            notifyFavorite: value,
                          ),
                  ),
                  _SwitchTile(
                    title: '举报结果通知',
                    subtitle: '举报被处理后提醒',
                    value: profile?.notifyReportResult ?? true,
                    onChanged: _saving
                        ? null
                        : (value) => _updateNotificationPreferences(
                            notifyReportResult: value,
                          ),
                  ),
                  _SwitchTile(
                    title: '系统通知',
                    subtitle: '系统公告与版本提醒',
                    value: profile?.notifySystem ?? true,
                    onChanged: _saving
                        ? null
                        : (value) =>
                              _updateNotificationPreferences(notifySystem: value),
                  ),
                ]),
              ],
            ),
    );
  }

  Widget _tileCard(List<Widget> children) {
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
            return Divider(height: 0.5, indent: 16, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
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
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeThumbColor: MobileTheme.primaryOf(context),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 12, color: colors.textSecondary, height: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
