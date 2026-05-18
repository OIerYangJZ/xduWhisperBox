import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:xdu_treehole_web/models/notification_item.dart';

import '../../core/state/mobile_providers.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/theme/mobile_theme.dart';
import '../../core/utils/time_utils.dart';
import '../widgets/avatar_widget.dart';

class NotificationCenterPage extends ConsumerStatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  ConsumerState<NotificationCenterPage> createState() =>
      _NotificationCenterPageState();
}

class _NotificationCenterPageState
    extends ConsumerState<NotificationCenterPage> {
  final Map<String, String> _actorAvatarCache = <String, String>{};
  final Set<String> _actorAvatarLoading = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsControllerProvider.notifier).loadInitial();
    });
  }

  Future<void> _refresh() async {
    await ref.read(notificationsControllerProvider.notifier).refresh();
  }

  void _markAllRead() {
    ref.read(notificationsControllerProvider.notifier).markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsControllerProvider);
    final colors = MobileColors.of(context);
    if (state.items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _prefetchActorAvatars(state.items);
      });
    }

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('通知中心'),
        actions: [
          if (state.unreadCount > 0)
            TextButton(
              onPressed: state.actionBusy ? null : _markAllRead,
              child: state.actionBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('全部已读'),
            ),
        ],
      ),
      body: state.loading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? _buildErrorState(state.error!)
          : state.items.isEmpty
          ? _buildEmptyState()
          : _buildNotificationList(state.items),
    );
  }

  Widget _buildErrorState(String error) {
    final colors = MobileColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            error,
            style: TextStyle(fontSize: 14, color: colors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _refresh, child: const Text('重试')),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colors = MobileColors.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_none, size: 64, color: colors.textTertiary),
          const SizedBox(height: 16),
          Text(
            '暂无通知',
            style: TextStyle(fontSize: 16, color: colors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(List<NotificationItem> items) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return _NotificationTile(
            notification: item,
            resolvedActorAvatarUrl: _resolveActorAvatarUrl(item),
            onTap: () => _handleNotificationTap(item),
          );
        },
      ),
    );
  }

  void _prefetchActorAvatars(List<NotificationItem> items) {
    for (final NotificationItem item in items) {
      if (!_isActorDrivenType(item.type)) {
        continue;
      }
      final String actorId = item.actorId.trim();
      final String payloadAvatar = item.actorAvatarUrl.trim();
      if (payloadAvatar.isNotEmpty && actorId.isNotEmpty) {
        _actorAvatarCache[actorId] = payloadAvatar;
      }
      if (actorId.isEmpty ||
          _actorAvatarCache.containsKey(actorId) ||
          _actorAvatarLoading.contains(actorId)) {
        continue;
      }
      _actorAvatarLoading.add(actorId);
      ref
          .read(userRepositoryProvider)
          .fetchUserProfile(actorId)
          .then((profile) {
            if (!mounted) {
              return;
            }
            setState(() {
              final String avatarUrl = profile.avatarUrl.trim();
              if (avatarUrl.isNotEmpty) {
                _actorAvatarCache[actorId] = avatarUrl;
              }
              _actorAvatarLoading.remove(actorId);
            });
          })
          .catchError((_) {
            if (!mounted) {
              return;
            }
            setState(() {
              _actorAvatarLoading.remove(actorId);
            });
          });
    }
  }

  bool _isActorDrivenType(String type) {
    switch (type) {
      case 'comment':
      case 'reply':
      case 'like':
      case 'favorite':
        return true;
      default:
        return false;
    }
  }

  String _resolveActorAvatarUrl(NotificationItem item) {
    final String payloadAvatar = item.actorAvatarUrl.trim();
    if (payloadAvatar.isNotEmpty) {
      return payloadAvatar;
    }
    final String actorId = item.actorId.trim();
    if (actorId.isEmpty) {
      return '';
    }
    return _actorAvatarCache[actorId] ?? '';
  }

  void _handleNotificationTap(NotificationItem notification) {
    ref
        .read(notificationsControllerProvider.notifier)
        .markRead(notification.id);
    if (notification.postId.isNotEmpty) {
      context.push('/post/${notification.postId}');
    }
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.resolvedActorAvatarUrl,
    required this.onTap,
  });

  final NotificationItem notification;
  final String resolvedActorAvatarUrl;
  final VoidCallback onTap;

  IconData get _icon {
    switch (notification.type) {
      case 'comment':
        return Icons.comment_outlined;
      case 'reply':
        return Icons.reply_outlined;
      case 'like':
        return Icons.thumb_up_outlined;
      case 'favorite':
        return Icons.star_outline;
      case 'report_result':
        return Icons.flag_outlined;
      case 'system':
        return Icons.campaign_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(BuildContext context) {
    switch (notification.type) {
      case 'comment':
      case 'reply':
        return Colors.blue;
      case 'like':
        return Colors.red;
      case 'favorite':
        return Colors.amber;
      case 'report_result':
        return Colors.orange;
      case 'system':
        return Colors.purple;
      default:
        return MobileTheme.primaryOf(context);
    }
  }

  bool get _preferActorAvatar {
    return notification.actorId.trim().isNotEmpty ||
        notification.actorAlias.trim().isNotEmpty ||
        notification.actorAvatarUrl.trim().isNotEmpty;
  }

  String get _timeText {
    final DateTime? parsed = DateTime.tryParse(notification.createdAt);
    if (parsed != null) {
      final DateTime localTime = parsed.isUtc ? parsed.toLocal() : parsed;
      return formatRelativeTime(localTime);
    }
    final String fallback = notification.timeText.trim();
    return fallback.isEmpty ? '--' : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final String actorNickname = notification.actorAlias.trim().isNotEmpty
        ? notification.actorAlias.trim()
        : '树洞';

    return Material(
      color: colors.surface,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _preferActorAvatar
                  ? AvatarWidget(
                      avatarUrl: resolvedActorAvatarUrl,
                      nickname: actorNickname,
                      radius: 20,
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _iconColor(context).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(_icon, color: _iconColor(context), size: 20),
                    ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.displayTitle,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w600,
                              color: colors.textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (!notification.isRead) ...[
                          Container(
                            width: 7,
                            height: 7,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: BoxDecoration(
                              color: MobileTheme.primaryOf(context),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          _timeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      style: TextStyle(
                        fontSize: 14,
                        color: colors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
}
