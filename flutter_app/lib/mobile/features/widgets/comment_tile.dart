import 'package:flutter/material.dart';

import 'package:xdu_treehole_web/models/comment_item.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/utils/time_utils.dart';
import 'avatar_widget.dart';

/// 评论列表项组件
/// 支持嵌套回复、点赞、时间戳格式化
class CommentTile extends StatelessWidget {
  final CommentItem comment;
  final VoidCallback? onLike;
  final VoidCallback? onReply;
  final VoidCallback? onTap;
  final int indentLevel; // 嵌套层级，0 为顶级

  const CommentTile({
    super.key,
    required this.comment,
    this.onLike,
    this.onReply,
    this.onTap,
    this.indentLevel = 0,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    final isNested = indentLevel > 0;
    final leftPadding = isNested ? (indentLevel * 48.0).clamp(0.0, 160.0) : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.only(
          left: leftPadding + 16,
          right: 16,
          top: 12,
          bottom: 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 头像
                AvatarWidget(
                  avatarUrl: comment.authorAvatar,
                  nickname: comment.authorNickname,
                  radius: isNested ? 18 : 22,
                ),
                const SizedBox(width: 10),

                // 内容区
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 作者行
                      Row(
                        children: [
                          Text(
                            comment.authorNickname.isNotEmpty
                                ? comment.authorNickname
                                : '匿名同学',
                            style: TextStyle(
                              fontSize: isNested ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: isNested
                                  ? colors.textSecondary
                                  : colors.textPrimary,
                            ),
                          ),
                          if (comment.isPinned) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: MobileTheme.accent.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: const Text(
                                '置顶',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: MobileTheme.accent,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _formatTime(comment.createdAt),
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textTertiary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // 评论正文
                      Text(
                        comment.content,
                        style: TextStyle(
                          fontSize: isNested ? 13 : 14,
                          color: colors.textSecondary,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // 操作栏
                      Row(
                        children: [
                          // 点赞
                          _ActionItem(
                            icon: comment.isLiked
                                ? Icons.favorite
                                : Icons.favorite_border,
                            label: comment.likeCount > 0
                                ? '${comment.likeCount}'
                                : null,
                            isActive: comment.isLiked,
                            activeColor: MobileTheme.accent,
                            onTap: onLike,
                          ),

                          const SizedBox(width: 16),

                          // 回复
                          _ActionItem(
                            icon: Icons.chat_bubble_outline,
                            label: '回复',
                            onTap: onReply,
                          ),

                          if (comment.replies.isNotEmpty) ...[
                            const SizedBox(width: 16),
                            GestureDetector(
                              onTap: onTap,
                              child: Text(
                                '展开 ${comment.effectiveReplyCount} 条回复',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // 嵌套子评论
            if (comment.replies.isNotEmpty) ...[
              const SizedBox(height: 4),
              // 竖线连接
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: leftPadding + 22),
                  Container(
                    width: 2,
                    height: comment.replies.length * 72.0,
                    decoration: BoxDecoration(
                      color: colors.divider,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: comment.replies.map((reply) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: CommentTile(
                            comment: reply,
                            onLike: null,
                            onReply: null,
                            indentLevel: indentLevel + 1,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return formatRelativeTime(dateTime);
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  const _ActionItem({
    required this.icon,
    this.label,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final color = isActive
        ? (activeColor ?? MobileTheme.primaryOf(context))
        : colors.textTertiary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            if (label != null) ...[
              const SizedBox(width: 3),
              Text(label!, style: TextStyle(fontSize: 12, color: color)),
            ],
          ],
        ),
      ),
    );
  }
}
