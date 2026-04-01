import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';

/// 帮助与反馈页
class HelpAndFeedbackPage extends StatelessWidget {
  const HelpAndFeedbackPage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('帮助与反馈'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 常见问题
          _buildSectionHeader(context, '常见问题'),
          const SizedBox(height: 8),
          _buildFAQItem(
            context,
            icon: Icons.lock_outline,
            title: '统一认证登录失败？',
            description: '请确认学号和西电统一身份认证密码输入正确；如果验证码多次失败，可稍后重试。',
          ),
          _buildFAQItem(
            context,
            icon: Icons.mail_outline,
            title: '为什么没有注册和找回密码？',
            description: '普通用户已切换为西电统一身份认证登录，不再提供站内注册、邮箱验证和本地找回密码。',
          ),
          _buildFAQItem(
            context,
            icon: Icons.visibility_off_outlined,
            title: '如何匿名发帖？',
            description: '在发帖页面底部开关区域，开启"匿名发布"开关，可自定义匿名别名或使用系统随机生成。',
          ),
          _buildFAQItem(
            context,
            icon: Icons.flag_outlined,
            title: '举报后多久处理？',
            description:
                '管理员将在 24 小时内审核处理。工作日 9:00-18:00 平均处理时长 2-6 小时，处理结果可在"我的举报"中查看。',
          ),
          _buildFAQItem(
            context,
            icon: Icons.block_outlined,
            title: '如何屏蔽某用户？',
            description: '目前支持通过举报功能反馈不希望接收私信的对象，管理员将酌情处理。',
          ),

          const SizedBox(height: 24),

          // 反馈入口
          _buildSectionHeader(context, '我要反馈'),
          const SizedBox(height: 8),
          _buildMenuItem(
            context,
            icon: Icons.flag_outlined,
            title: '举报说明',
            subtitle: '了解如何举报违规内容',
            onTap: () => context.push('/legal/report'),
          ),
          _buildMenuItem(
            context,
            icon: Icons.article_outlined,
            title: '我的举报记录',
            subtitle: '查看所有举报的处理状态',
            onTap: () => context.push('/profile/reports'),
          ),

          const SizedBox(height: 24),

          // 联系管理员
          _buildSectionHeader(context, '联系管理员'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: MobileTheme.primaryWithAlpha(context, 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.headset_mic_outlined,
                    color: MobileTheme.primaryOf(context),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '仍有疑问？',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '可通过站内私信联系管理员，或发送邮件至平台管理员邮箱。',
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

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = MobileColors.of(context);
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildFAQItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: MobileTheme.primaryOf(context), size: 20),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: colors.textPrimary,
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(56, 0, 16, 16),
          children: [
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: colors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = MobileColors.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: MobileTheme.primaryWithAlpha(context, 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: MobileTheme.primaryOf(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
