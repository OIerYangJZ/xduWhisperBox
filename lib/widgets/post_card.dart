import 'package:flutter/material.dart';

import '../models/post_item.dart';

class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.onTap,
  });

  final PostItem post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color mutedText = theme.colorScheme.onSurface.withValues(alpha: 0.64);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  if (post.isPinned) ...<Widget>[
                    _pill(
                      icon: Icons.push_pin_outlined,
                      text: post.pinDurationLabel.isEmpty
                          ? '置顶中'
                          : '置顶 · ${post.pinDurationLabel}',
                      textColor: const Color(0xFFB45309),
                      backgroundColor:
                          const Color(0xFFB45309).withValues(alpha: 0.12),
                    ),
                    const SizedBox(width: 8),
                  ],
                  _pill(
                    icon: Icons.category_outlined,
                    text: post.channel,
                    textColor: theme.colorScheme.primary,
                    backgroundColor:
                        theme.colorScheme.primary.withValues(alpha: 0.1),
                  ),
                  const SizedBox(width: 8),
                  _pill(
                    icon: Icons.verified_outlined,
                    text: post.status.label,
                    textColor: _statusColor(post.status),
                    backgroundColor:
                        _statusColor(post.status).withValues(alpha: 0.12),
                  ),
                  const Spacer(),
                  if (post.hasImage)
                    _pill(
                      icon: Icons.photo_library_outlined,
                      text: '含图片',
                      textColor: const Color(0xFF0F766E),
                      backgroundColor:
                          const Color(0xFF0F766E).withValues(alpha: 0.1),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                post.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.86),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: post.tags.isEmpty
                    ? <Widget>[
                        Text(
                          '#暂无标签',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mutedText,
                          ),
                        ),
                      ]
                    : post.tags
                        .map(
                          (String tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 9, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FB),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: const Color(0xFF155E75)
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                            child: Text(
                              '#$tag',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF155E75),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 12),
              Divider(
                height: 12,
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Text(
                    '${post.authorAlias} · ${_relativeTime(post.createdAt)}'
                    '${post.isPinned && post.pinExpiresAt != null ? ' · 置顶至 ${_pinExpireText(post.pinExpiresAt!)}' : ''}',
                    style:
                        theme.textTheme.bodySmall?.copyWith(color: mutedText),
                  ),
                  const Spacer(),
                  _metric(
                      icon: Icons.visibility_outlined,
                      value: post.viewCount),
                  const SizedBox(width: 10),
                  _metric(
                      icon: Icons.mode_comment_outlined,
                      value: post.commentCount),
                  const SizedBox(width: 10),
                  _metric(
                      icon: Icons.thumb_up_alt_outlined, value: post.likeCount),
                  const SizedBox(width: 10),
                  _metric(
                      icon: post.isFavorited
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_outlined,
                      value: post.favoriteCount),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _metric({required IconData icon, required int value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 3),
          Text('$value',
              style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _pill({
    required IconData icon,
    required String text,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(PostStatus status) {
    switch (status) {
      case PostStatus.ongoing:
        return const Color(0xFF126E5E);
      case PostStatus.resolved:
        return const Color(0xFF2F5EA8);
      case PostStatus.closed:
        return const Color(0xFF686D76);
    }
  }

  String _relativeTime(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟前';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours} 小时前';
    }
    return '${diff.inDays} 天前';
  }

  String _pinExpireText(DateTime time) {
    return '${time.month.toString().padLeft(2, '0')}-${time.day.toString().padLeft(2, '0')} '
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}
