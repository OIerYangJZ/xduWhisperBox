import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/navigation/post_detail_nav.dart';
import '../core/navigation/url_query_state.dart';
import '../models/conversation_item.dart';
import '../models/post_item.dart';
import '../repositories/app_repositories.dart';
import '../features/feed/feed_page.dart';
import '../features/messages/messages_page.dart';
import '../features/messages/messages_controller.dart';
import '../features/notifications/notification_center_page.dart';
import '../features/notifications/notifications_controller.dart';
import '../features/post/create_post_page.dart';
import '../features/profile/profile_page.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;
  bool _postUrlHandled = false;
  final GlobalKey<ProfilePageState> _profilePageKey =
      GlobalKey<ProfilePageState>();

  static const List<String> _titles = <String>['首页', '消息', '个人中心'];

  static const List<String> _subtitles = <String>[
    '发现校园新鲜事',
    '查看私信与申请',
    '管理你的账号信息',
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(messagesControllerProvider.notifier).loadInitial();
      await ref.read(notificationsControllerProvider.notifier).loadInitial();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restorePostFromUrlIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      const FeedPage(),
      const MessagesPage(),
      ProfilePage(key: _profilePageKey),
    ];
    final MessagesState messagesState = ref.watch(messagesControllerProvider);
    final NotificationsState notificationsState = ref.watch(
      notificationsControllerProvider,
    );
    final int unreadCount = messagesState.conversations.fold<int>(
      0,
      (int sum, ConversationItem item) => sum + item.unreadCount,
    );
    final bool showMessageDot =
        unreadCount > 0 ||
        messagesState.requests.any((item) => item.status == 'pending');
    final int notificationUnreadCount = notificationsState.unreadCount;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 68,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.forum_outlined,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _titles[_currentIndex],
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              _subtitles[_currentIndex],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.84),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationCenterPage(),
                ),
              );
              if (!mounted) {
                return;
              }
              await ref
                  .read(notificationsControllerProvider.notifier)
                  .refresh();
            },
            tooltip: '通知',
            icon: Badge(
              isLabelVisible: notificationUnreadCount > 0,
              label: Text(
                notificationUnreadCount > 99
                    ? '99+'
                    : '$notificationUnreadCount',
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Color(0xFF0E7490),
                Color(0xFF155E75),
                Color(0xFF0F766E),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Stack(
        children: <Widget>[
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[Color(0xFFF1F8FB), Color(0xFFEAF3F8)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -80,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF0EA5A4).withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            left: -110,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF155E75).withValues(alpha: 0.06),
              ),
            ),
          ),
          IndexedStack(index: _currentIndex, children: pages),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openCreatePost,
              icon: const Icon(Icons.edit_square),
              label: const Text('发帖'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 74,
        selectedIndex: _currentIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
          if (index == 2) {
            _profilePageKey.currentState?.refreshProfile();
          }
        },
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: _selectedIcon(Icons.home_rounded),
            label: '首页',
          ),
          NavigationDestination(
            icon: _messageNavIcon(
              icon: const Icon(Icons.chat_bubble_outline),
              badgeCount: unreadCount,
              showDot: showMessageDot,
            ),
            selectedIcon: _messageNavIcon(
              icon: _selectedIcon(Icons.chat_bubble_rounded),
              badgeCount: unreadCount,
              showDot: showMessageDot,
            ),
            label: '消息',
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: _selectedIcon(Icons.person_rounded),
            label: '我的',
          ),
        ],
      ),
    );
  }

  Widget _selectedIcon(IconData icon) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: const Color(0xFF155E75).withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Icon(icon, size: 18),
    );
  }

  Widget _messageNavIcon({
    required Widget icon,
    required int badgeCount,
    required bool showDot,
  }) {
    if (!showDot) {
      return icon;
    }
    return Badge(
      isLabelVisible: true,
      smallSize: 8,
      label: badgeCount > 0
          ? Text(badgeCount > 99 ? '99+' : '$badgeCount')
          : null,
      child: icon,
    );
  }

  Future<void> _openCreatePost() async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (_) => const CreatePostPage()),
    );
    if (!mounted || created != true) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('帖子已发布并立即展示。')));
  }

  Future<void> _restorePostFromUrlIfNeeded() async {
    if (_postUrlHandled) {
      return;
    }
    _postUrlHandled = true;
    final String? postId = currentPostIdFromUrl();
    if (postId == null || postId.trim().isEmpty) {
      return;
    }
    try {
      final PostItem post = await AppRepositories.posts.fetchPostDetail(postId);
      if (!mounted) {
        return;
      }
      await openPostDetailPage(context, post: post);
    } catch (_) {
      // Ignore deep-link restore errors to avoid blocking home page.
      setPostIdOnUrl(null);
    }
  }
}
