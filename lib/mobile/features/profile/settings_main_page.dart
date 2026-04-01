import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';
import '../../features/update/app_update_controller.dart';
import '../../features/update/app_update_dialog.dart';

class SettingsMainPage extends ConsumerStatefulWidget {
  const SettingsMainPage({super.key});

  @override
  ConsumerState<SettingsMainPage> createState() => _SettingsMainPageState();
}

class _SettingsMainPageState extends ConsumerState<SettingsMainPage> {
  UserProfile? _profile;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await ref.read(userRepositoryProvider).fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _updatePrivacy({
    required bool allowStrangerDm,
    required bool showContactable,
  }) async {
    setState(() => _saving = true);
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
    } catch (_) {
      _showToast('设置失败');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _promptLevelUpgradeRequest() async {
    final profile = _profile;
    if (profile == null || profile.isLevelOneUser) return;
    final request = profile.levelUpgradeRequest;
    if (request?.status == 'pending') {
      _showToast('你已经提交过申请了，请等待管理员审核');
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('申请成为一级用户'),
        content: const Text('确认提交一级用户申请吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认提交'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).submitLevelUpgradeRequest();
      await _loadProfile();
      _showToast('一级用户申请已提交');
    } catch (e) {
      _showToast('提交失败：$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _levelUpgradeSubtitle(UserLevelRequestSummary? request) {
    if (request == null) return '当前为二级用户，可申请升级为一级用户';
    final buffer = StringBuffer(
      '${request.statusLabel} · ${request.createdAt}',
    );
    if (request.adminNote.trim().isNotEmpty) {
      buffer.write(' · ${request.adminNote.trim()}');
    }
    return buffer.toString();
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

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('外观'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              title: '跟随系统',
              value: ThemeMode.system,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.system, ctx),
            ),
            _ThemeOption(
              title: '浅色',
              value: ThemeMode.light,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.light, ctx),
            ),
            _ThemeOption(
              title: '深色',
              value: ThemeMode.dark,
              current: ref.read(appSettingsProvider).themeMode,
              onTap: () => _setBrightness(ThemeMode.dark, ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setBrightness(
    ThemeMode mode,
    BuildContext dialogContext,
  ) async {
    await ref.read(appSettingsProvider.notifier).setBrightness(mode);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_themeModeLabel(mode)}');
  }

  String _themeModeLabel(ThemeMode mode) {
    if (mode == ThemeMode.system) return '跟随系统';
    if (mode == ThemeMode.light) return '浅色';
    if (mode == ThemeMode.dark) return '深色';
    return '未知';
  }

  void _showLanguageDialog() {
    final currentLocale = ref.read(appSettingsProvider).locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('语言'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _LocaleOption(
              title: '简体中文',
              locale: const Locale('zh', 'CN'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('zh', 'CN'), ctx),
            ),
            _LocaleOption(
              title: '繁體中文',
              locale: const Locale.fromSubtags(
                languageCode: 'zh',
                scriptCode: 'Hant',
              ),
              current: currentLocale,
              onTap: () => _setLocale(
                const Locale.fromSubtags(
                  languageCode: 'zh',
                  scriptCode: 'Hant',
                ),
                ctx,
              ),
            ),
            _LocaleOption(
              title: 'English',
              locale: const Locale('en', 'US'),
              current: currentLocale,
              onTap: () => _setLocale(const Locale('en', 'US'), ctx),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale loc, BuildContext dialogContext) async {
    await ref.read(appSettingsProvider.notifier).setLocale(loc);
    if (!mounted) return;
    Navigator.pop(dialogContext);
    _showToast('已切换到 ${_localeLabel(loc)}');
  }

  String _localeLabel(Locale loc) {
    final code = loc.scriptCode != null && loc.scriptCode!.isNotEmpty
        ? '${loc.languageCode}_${loc.scriptCode}'
        : '${loc.languageCode}_${loc.countryCode ?? ''}';
    if (code == 'zh_CN') return '简体中文';
    if (code == 'zh_Hant' || code == 'zh_TW') return '繁體中文';
    if (code == 'en_US' || code == 'en_') return 'English';
    return '${loc.languageCode}_${loc.countryCode ?? ''}';
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
    final updateController = ref.watch(appUpdateProvider);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.background,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(
                color: MobileTheme.primaryOf(context),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _SectionTitle(title: '账号设置'),
                _tileCard([
                  if (!(_profile?.isLevelOneUser ?? false))
                    _ListTile(
                      icon: Icons.workspace_premium_outlined,
                      title: '申请成为一级用户',
                      subtitle: _levelUpgradeSubtitle(
                        _profile?.levelUpgradeRequest,
                      ),
                      onTap:
                          _saving ||
                              _profile?.levelUpgradeRequest?.status == 'pending'
                          ? null
                          : _promptLevelUpgradeRequest,
                    ),
                ]),
                _SectionTitle(title: '隐私设置'),
                _tileCard([
                  _SwitchTile(
                    icon: Icons.chat_bubble_outline,
                    title: '允许陌生人私信',
                    subtitle: '关闭后，其他人无法通过你的公开主页或帖子给你发起私信',
                    value: _profile?.allowStrangerDm ?? false,
                    onChanged: _saving
                        ? null
                        : (value) => _updatePrivacy(
                            allowStrangerDm: value,
                            showContactable: _profile?.showContactable ?? false,
                          ),
                  ),
                  _SwitchTile(
                    icon: Icons.visibility_outlined,
                    title: '显示"可联系"状态',
                    subtitle: '开启后其他用户可看到你的联系方式',
                    value: _profile?.showContactable ?? false,
                    onChanged: _saving
                        ? null
                        : (value) => _updatePrivacy(
                            allowStrangerDm: _profile?.allowStrangerDm ?? false,
                            showContactable: value,
                          ),
                  ),
                ]),
                _SectionTitle(title: '通知设置'),
                _tileCard([
                  _ListTile(
                    icon: Icons.notifications_outlined,
                    title: '通知设置',
                    subtitle: '管理评论、回复、点赞、收藏等站内通知',
                    onTap: () =>
                        context.push('/profile/settings/notifications'),
                  ),
                ]),
                _SectionTitle(title: '界面设置'),
                _tileCard([
                  _ListTile(
                    icon: Icons.brightness_6_outlined,
                    title: '主题',
                    subtitle: _themeModeLabel(
                      ref.watch(appSettingsProvider).themeMode,
                    ),
                    onTap: _showThemeDialog,
                  ),
                  _ListTile(
                    icon: Icons.language_outlined,
                    title: '语言',
                    subtitle: _localeLabel(
                      ref.watch(appSettingsProvider).locale ??
                          const Locale('zh', 'CN'),
                    ),
                    onTap: _showLanguageDialog,
                  ),
                ]),
                _SectionTitle(title: '关于与支持'),
                _tileCard([
                  _ListTile(
                    icon: Icons.download_outlined,
                    title: '下载 Android 客户端',
                    subtitle: '检查并下载最新安装包',
                    onTap: _handleCheckUpdate,
                  ),
                  _ListTile(
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
                    onTap: updateController.checking
                        ? null
                        : _handleCheckUpdate,
                  ),
                  _ListTile(
                    icon: Icons.info_outline,
                    title: '当前版本',
                    subtitle: '版本信息',
                    trailing: Text(
                      updateController.currentVersionLabel,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textSecondary,
                      ),
                    ),
                    onTap: null,
                  ),
                  _ListTile(
                    icon: Icons.description_outlined,
                    title: '用户协议',
                    subtitle: '查看平台服务条款',
                    onTap: () => context.push('/legal/terms'),
                  ),
                  _ListTile(
                    icon: Icons.privacy_tip_outlined,
                    title: '隐私政策',
                    subtitle: '查看个人信息与数据处理说明',
                    onTap: () => context.push('/legal/privacy'),
                  ),
                  _ListTile(
                    icon: Icons.gavel_outlined,
                    title: '社区规范',
                    subtitle: '了解发帖与互动规则',
                    onTap: () => context.push('/legal/guidelines'),
                  ),
                  _ListTile(
                    icon: Icons.flag_outlined,
                    title: '举报说明',
                    subtitle: '了解举报受理与处理流程',
                    onTap: () => context.push('/legal/report'),
                  ),
                  _ListTile(
                    icon: Icons.help_outline,
                    title: '帮助与反馈',
                    subtitle: '问题反馈、联系方式与常见问题',
                    onTap: () => context.push('/profile/help-feedback'),
                  ),
                  _ListTile(
                    icon: Icons.favorite_outline,
                    title: '致谢页',
                    subtitle: '感谢每一位参与建设与反馈的同学',
                    onTap: () => context.push('/profile/acknowledgements'),
                  ),
                ]),
                _SectionTitle(title: '账号安全'),
                _tileCard([
                  _ListTile(
                    icon: Icons.no_accounts_outlined,
                    title: '注销账号',
                    subtitle: '提交注销申请并进入管理员审核流程',
                    titleColor: MobileTheme.error,
                    onTap: _showCancelAccountHint,
                  ),
                ]),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _logout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MobileTheme.error,
                    side: BorderSide(color: colors.divider, width: 0.5),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('退出登录'),
                ),
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
            return Divider(height: 0.5, indent: 56, color: colors.divider);
          }
          return children[index ~/ 2];
        }),
      ),
    );
  }

  void _showCancelAccountHint() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('注销账号'),
        content: const Text('账号注销后将永久删除所有数据，且无法恢复。\n\n确认要注销账号吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
            onPressed: () {
              Navigator.pop(ctx);
              _showCancelAccountPassword();
            },
            child: const Text('继续注销'),
          ),
        ],
      ),
    );
  }

  void _showCancelAccountPassword() {
    final passwordController = TextEditingController();
    bool obscure = true;
    bool submitting = false;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('验证身份'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('请输入统一认证密码以确认注销申请：', style: TextStyle(fontSize: 14)),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: obscure,
                decoration: InputDecoration(
                  hintText: '统一认证密码',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setDialogState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: MobileTheme.error),
              onPressed: submitting
                  ? null
                  : () async {
                      if (passwordController.text.isEmpty) return;
                      setDialogState(() => submitting = true);
                      try {
                        final studentId =
                            AuthStore.instance.currentUser?.studentId ?? '';
                        await ref
                            .read(authRepositoryProvider)
                            .login(
                              identifier: studentId,
                              password: passwordController.text,
                            );
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        _submitCancellationRequest();
                      } catch (_) {
                        setDialogState(() => submitting = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('统一认证密码错误，请重新输入')),
                          );
                        }
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('确认注销'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitCancellationRequest() async {
    try {
      await ref
          .read(userRepositoryProvider)
          .submitAccountCancellationRequest(reason: '用户主动申请注销');
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('申请已提交'),
          content: const Text(
            '注销申请已提交给管理员审核。审核通过后，账号和所有数据将被永久删除。\n\n审核结果将通过邮件通知您。',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _logout();
              },
              child: const Text('知道了'),
            ),
          ],
        ),
      );
    } catch (_) {
      _showToast('申请提交失败，请稍后重试');
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.titleColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color? titleColor;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? colors.textPrimary,
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
            trailing ??
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: onTap == null
                      ? colors.textTertiary.withValues(alpha: 0.5)
                      : colors.textTertiary,
                ),
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.title,
    required this.value,
    required this.current,
    required this.onTap,
  });

  final String title;
  final ThemeMode value;
  final ThemeMode current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = value == current;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
      onTap: onTap,
    );
  }
}

class _LocaleOption extends StatelessWidget {
  const _LocaleOption({
    required this.title,
    required this.locale,
    required this.current,
    required this.onTap,
  });

  final String title;
  final Locale locale;
  final Locale? current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected =
        locale.languageCode == current?.languageCode &&
        locale.countryCode == current?.countryCode;
    return ListTile(
      title: Text(title),
      trailing: selected
          ? Icon(Icons.check, color: MobileTheme.primaryOf(context))
          : null,
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
