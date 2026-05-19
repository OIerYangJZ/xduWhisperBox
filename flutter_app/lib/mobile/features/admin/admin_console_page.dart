import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../models/admin_models.dart';
import '../../../repositories/admin_repository.dart';
import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';

/// 管理员控制台页
class AdminConsolePage extends ConsumerStatefulWidget {
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> {
  AdminOverview? _overview;
  bool _isLoading = true;
  String? _error;

  AdminRepository get _repo => ref.read(adminRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final overview = await _repo.fetchOverview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final overview = _overview;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('管理员后台'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: _isLoading && overview == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: MobileTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '加载失败: $_error',
                          style: const TextStyle(color: MobileTheme.error, fontSize: 13),
                        ),
                      ),
                    
                    // 概览卡片
                    _buildOverviewCards(overview),

                    const SizedBox(height: 24),

                    // 功能入口
                    const _SectionTitle(title: '内容管理'),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _AdminMenuItem(
                            icon: Icons.article_outlined,
                            title: '内容审核',
                            subtitle: '审核帖子和评论',
                            badge: overview != null && overview.pendingReviews > 0
                                ? overview.pendingReviews.toString()
                                : null,
                            onTap: () => context.push('/admin/reviews'),
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.image_outlined,
                            title: '图片审核',
                            subtitle: '管理用户上传图片',
                            badge: null,
                            onTap: () => context.push('/admin/images'),
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.flag_outlined,
                            title: '举报管理',
                            subtitle: '处理内容举报',
                            badge: overview != null && overview.todayReports > 0
                                ? overview.todayReports.toString()
                                : null,
                            onTap: () => context.push('/admin/reports'),
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.person_off_outlined,
                            title: '注销申请',
                            subtitle: '审核账号注销请求',
                            badge: overview != null && overview.pendingCancellationRequests > 0
                                ? overview.pendingCancellationRequests.toString()
                                : null,
                            onTap: () {
                              _showComingSoon('注销审核功能即将上线');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const _SectionTitle(title: '用户管理'),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _AdminMenuItem(
                            icon: Icons.people_outline,
                            title: '用户列表',
                            subtitle: '查看、禁言或封禁用户',
                            badge: null,
                            onTap: () {
                              _showComingSoon('用户管理功能即将上线');
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.workspace_premium_outlined,
                            title: '等级申请',
                            subtitle: '审核一级用户申请',
                            badge: null,
                            onTap: () {
                              _showComingSoon('等级审核功能即将上线');
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    const _SectionTitle(title: '系统管理'),
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _AdminMenuItem(
                            icon: Icons.campaign_outlined,
                            title: '发布公告',
                            subtitle: '编辑和发布系统公告',
                            badge: null,
                            onTap: () {
                              _showComingSoon('公告管理功能即将上线');
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.settings_outlined,
                            title: '系统配置',
                            subtitle: '风控、速率与存储配置',
                            badge: null,
                            onTap: () {
                              _showComingSoon('系统配置逻辑正在迁移');
                            },
                          ),
                          const Divider(height: 1, indent: 56),
                          _AdminMenuItem(
                            icon: Icons.download_outlined,
                            title: '数据导出',
                            subtitle: '导出用户/内容/日志数据',
                            badge: null,
                            onTap: () {
                              _showComingSoon('数据导出功能请暂使用 Web 端');
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _showComingSoon(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildOverviewCards(AdminOverview? overview) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '今日用户',
            value: overview?.todayNewUsers.toString() ?? '-',
            icon: Icons.person_add_alt_1,
            color: MobileTheme.primaryOf(context),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '今日发帖',
            value: overview?.todayPosts.toString() ?? '-',
            icon: Icons.article,
            color: MobileTheme.success,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '待审核项',
            value: overview?.pendingReviews.toString() ?? '-',
            icon: Icons.pending_actions,
            color: MobileTheme.warning,
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _AdminMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? badge;
  final VoidCallback onTap;

  const _AdminMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MobileTheme.primaryWithAlpha(context, 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: MobileTheme.primaryOf(context),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            if (badge != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MobileTheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: colors.textTertiary),
          ],
        ),
      ),
    );
  }
}
