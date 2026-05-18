import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

/// 管理员控制台页
class AdminConsolePage extends ConsumerStatefulWidget {
  const AdminConsolePage({super.key});

  @override
  ConsumerState<AdminConsolePage> createState() => _AdminConsolePageState();
}

class _AdminConsolePageState extends ConsumerState<AdminConsolePage> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('管理员后台'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 概览卡片
                  _buildOverviewCards(),

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
                          title: '帖子审核',
                          subtitle: '审核用户发布的帖子',
                          badge: '3',
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 56),
                        _AdminMenuItem(
                          icon: Icons.comment_outlined,
                          title: '评论审核',
                          subtitle: '审核用户评论',
                          badge: null,
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 56),
                        _AdminMenuItem(
                          icon: Icons.image_outlined,
                          title: '图片审核',
                          subtitle: '审核用户上传的图片',
                          badge: '5',
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 56),
                        _AdminMenuItem(
                          icon: Icons.flag_outlined,
                          title: '举报管理',
                          subtitle: '处理用户举报',
                          badge: '2',
                          onTap: () {},
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
                          subtitle: '查看和管理用户',
                          badge: null,
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 56),
                        _AdminMenuItem(
                          icon: Icons.block_outlined,
                          title: '禁言管理',
                          subtitle: '管理被禁言用户',
                          badge: null,
                          onTap: () {},
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
                          subtitle: '向用户发送系统公告',
                          badge: null,
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 56),
                        _AdminMenuItem(
                          icon: Icons.settings_outlined,
                          title: '系统配置',
                          subtitle: '配置平台参数',
                          badge: null,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildOverviewCards() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: '用户总数',
            value: '1,234',
            icon: Icons.people,
            color: MobileTheme.primaryOf(context),
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '今日帖子',
            value: '56',
            icon: Icons.article,
            color: MobileTheme.success,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            title: '待审核',
            value: '10',
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
