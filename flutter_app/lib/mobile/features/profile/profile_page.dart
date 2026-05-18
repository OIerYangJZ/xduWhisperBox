import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../shell/mobile_shell.dart';
import 'package:xdu_treehole_web/core/config/app_config.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/models/user_profile.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/comment_item.dart';
import 'package:xdu_treehole_web/models/my_comment_item.dart';
import 'package:xdu_treehole_web/models/follow_user_item.dart';
import '../../core/state/mobile_providers.dart';
import '../widgets/avatar_widget.dart';
import '../home/post_card.dart';

/// 个人主页 — Twitter/Instagram 混合风格
/// 无卡片、无圆角、紧凑信息流布局
class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _scrollController = ScrollController();
  double _lastScrollOffset = 0;
  UserProfile? _profile;
  List<FollowUserItem> _followers = [];
  List<FollowUserItem> _following = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadProfile();
    _loadFollowData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final delta = _scrollController.position.pixels - _lastScrollOffset;
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }
    _lastScrollOffset = _scrollController.position.pixels;
  }

  Future<void> _loadProfile() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final profile = await repo.fetchProfile();
      AuthStore.instance.setCurrentUser(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      // 使用缓存的 currentUser
      if (!mounted) return;
      setState(() {
        _profile = AuthStore.instance.currentUser;
      });
    }
  }

  Future<void> _loadFollowData() async {
    try {
      final repo = ref.read(userRepositoryProvider);
      final results = await Future.wait([
        repo.fetchFollowers(),
        repo.fetchFollowing(),
      ]);
      if (!mounted) return;
      setState(() {
        _followers = results[0];
        _following = results[1];
      });
    } catch (_) {}
  }

  void _showFollowSheet(String title, List<FollowUserItem> users) {
    final colors = MobileColors.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FollowListSheet(title: title, users: users),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final user = _profile ?? AuthStore.instance.currentUser;
    final backgroundImageUrl = AppConfig.resolveUrl(
      user?.backgroundImageUrl ?? '',
    );
    final bool hasBackgroundImage = backgroundImageUrl.isNotEmpty;
    final bool isLightMode = Theme.of(context).brightness == Brightness.light;
    final Color profilePrimaryTextColor = isLightMode
        ? Colors.black
        : colors.textPrimary;
    final Color profileSecondaryTextColor = isLightMode
        ? Colors.black
        : colors.textSecondary;
    final double profileTopSpacing = hasBackgroundImage ? 120 : 60;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        controller: _scrollController,
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: colors.surface)),
                  if (hasBackgroundImage)
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CachedNetworkImage(
                          imageUrl: backgroundImageUrl,
                          fit: BoxFit.cover,
                          fadeInDuration: const Duration(milliseconds: 120),
                          imageBuilder: (context, imageProvider) => Image(
                            image: imageProvider,
                            fit: BoxFit.cover,
                            filterQuality: FilterQuality.low,
                          ),
                          placeholder: (context, url) => DecoratedBox(
                            decoration: BoxDecoration(
                              color: MobileTheme.primaryWithAlpha(
                                context,
                                0.08,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) =>
                              const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  if (hasBackgroundImage)
                    Positioned.fill(
                      child: ColoredBox(
                        color: colors.surface.withValues(alpha: 0.08),
                      ),
                    ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: profileTopSpacing,
                        color: hasBackgroundImage
                            ? Colors.transparent
                            : MobileTheme.primaryWithAlpha(context, 0.08),
                      ),

                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -24),
                              child: GestureDetector(
                                onTap: () async {
                                  await context.push('/profile/edit');
                                  if (mounted) {
                                    await _loadProfile();
                                  }
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: colors.surface,
                                      width: 4,
                                    ),
                                  ),
                                  child: AvatarWidget(
                                    avatarUrl: user?.avatarUrl,
                                    nickname: user?.nickname ?? '匿',
                                    radius: 36,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            Transform.translate(
                              offset: const Offset(0, -16),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () async {
                                      await context.push('/profile/edit');
                                      if (mounted) {
                                        await _loadProfile();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        border: Border.all(
                                          color: colors.divider,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        '编辑资料',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: colors.textPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () async {
                                      await context.push(
                                        '/profile/settings/main',
                                      );
                                      if (mounted) {
                                        await _loadProfile();
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surface,
                                        border: Border.all(
                                          color: colors.divider,
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 16,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        color: hasBackgroundImage
                            ? colors.surface.withValues(alpha: 0.72)
                            : Colors.transparent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                              child: Text(
                                user?.nickname ?? '匿名同学',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: profilePrimaryTextColor,
                                ),
                              ),
                            ),
                            if (user?.bio != null && user!.bio.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Text(
                                  user.bio,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: profileSecondaryTextColor,
                                  ),
                                ),
                              ),
                            if (user?.gender != null && user!.gender.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      user.gender == '男'
                                          ? Icons.male
                                          : Icons.female,
                                      size: 16,
                                      color: profileSecondaryTextColor,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      user.gender,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: profileSecondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              child: Row(
                                children: [
                                  _StatChip(
                                    label: '粉丝',
                                    value: '${_followers.length}',
                                    onTap: () =>
                                        _showFollowSheet('粉丝', _followers),
                                    primaryColor: profilePrimaryTextColor,
                                    secondaryColor: profileSecondaryTextColor,
                                  ),
                                  const SizedBox(width: 20),
                                  _StatChip(
                                    label: '关注',
                                    value: '${_following.length}',
                                    onTap: () =>
                                        _showFollowSheet('关注', _following),
                                    primaryColor: profilePrimaryTextColor,
                                    secondaryColor: profileSecondaryTextColor,
                                  ),
                                  const SizedBox(width: 20),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: MobileTheme.accent.withValues(
                                        alpha: hasBackgroundImage ? 0.18 : 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                      border: hasBackgroundImage
                                          ? Border.all(
                                              color: MobileTheme.accent
                                                  .withValues(alpha: 0.3),
                                              width: 0.6,
                                            )
                                          : null,
                                    ),
                                    child: Text(
                                      user?.userLevelLabel ?? 'Lv.1',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: MobileTheme.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        color: colors.surface,
                        child: Divider(height: 0.5, color: colors.divider),
                      ),
                      Material(
                        color: colors.surface,
                        child: TabBar(
                          controller: _tabController,
                          labelColor: colors.textPrimary,
                          unselectedLabelColor: colors.textSecondary,
                          indicatorColor: MobileTheme.primaryOf(context),
                          indicatorSize: TabBarIndicatorSize.tab,
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          isScrollable: false,
                          tabs: const [
                            Tab(text: '帖子'),
                            Tab(text: '收藏'),
                            Tab(text: '动态'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [_MyPostsTab(), _MyFavoritesTab(), _MyActivitiesTab()],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Color? primaryColor;
  final Color? secondaryColor;

  const _StatChip({
    required this.label,
    required this.value,
    this.onTap,
    this.primaryColor,
    this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            height: 1.0,
            color: primaryColor ?? colors.textPrimary,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            height: 1.0,
            color: secondaryColor ?? colors.textSecondary,
          ),
        ),
      ],
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: row);
    }
    return row;
  }
}

/// 关注/粉丝列表底部弹出面板
class _FollowListSheet extends StatelessWidget {
  final String title;
  final List<FollowUserItem> users;

  const _FollowListSheet({required this.title, required this.users});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final mutual = users.where((u) => u.isMutual).toList();
    final others = users.where((u) => !u.isMutual).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          children: [
            // 拖动条
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // 标题
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${users.length}',
                    style: TextStyle(fontSize: 14, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Divider(height: 0.5, color: colors.divider),
            // 列表
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Text(
                        '暂无数据',
                        style: TextStyle(
                          fontSize: 14,
                          color: colors.textTertiary,
                        ),
                      ),
                    )
                  : ListView(
                      controller: scrollCtrl,
                      children: [
                        if (mutual.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Text(
                              '好友',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          ...mutual.map((u) => _FollowUserTile(user: u)),
                          if (others.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                              child: Text(
                                '其他',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                        ],
                        ...others.map((u) => _FollowUserTile(user: u)),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FollowUserTile extends StatelessWidget {
  final FollowUserItem user;

  const _FollowUserTile({required this.user});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return ListTile(
      leading: AvatarWidget(
        avatarUrl: user.avatarUrl.isNotEmpty ? user.avatarUrl : null,
        nickname: user.nickname,
        radius: 20,
      ),
      title: Text(
        user.nickname,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: colors.textPrimary,
        ),
      ),
      trailing: user.isMutual
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MobileTheme.primaryWithAlpha(context, 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '好友',
                style: TextStyle(
                  fontSize: 12,
                  color: MobileTheme.primaryOf(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }
}

/// 我的帖子 Tab — 真实数据
class _MyPostsTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyPostsTab> createState() => _MyPostsTabState();
}

class _MyPostsTabState extends ConsumerState<_MyPostsTab> {
  List<PostItem> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await ref.read(postRepositoryProvider).fetchMyPosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: MobileTheme.primaryOf(context)),
      );
    }
    if (_posts.isEmpty) {
      return const _EmptyHint(icon: Icons.article_outlined, text: '还没有发过帖子');
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
          onLike: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isLiked) {
                await repo.unlikePost(post.id);
              } else {
                await repo.likePost(post.id);
              }
              _load();
            } catch (_) {}
          },
        );
      },
    );
  }
}

/// 我的收藏 Tab — 真实数据
class _MyFavoritesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyFavoritesTab> createState() => _MyFavoritesTabState();
}

class _MyFavoritesTabState extends ConsumerState<_MyFavoritesTab> {
  List<PostItem> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final posts = await ref.read(postRepositoryProvider).fetchFavoritePosts();
      if (!mounted) return;
      setState(() {
        _posts = posts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: MobileTheme.primaryOf(context)),
      );
    }
    if (_posts.isEmpty) {
      return const _EmptyHint(icon: Icons.star_outline, text: '还没有收藏');
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _posts.length,
      itemBuilder: (context, i) {
        final post = _posts[i];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
          onLike: () async {
            try {
              final repo = ref.read(postRepositoryProvider);
              if (post.isLiked) {
                await repo.unlikePost(post.id);
              } else {
                await repo.likePost(post.id);
              }
              _load();
            } catch (_) {}
          },
        );
      },
    );
  }
}

/// 动态 Tab — 我的评论真实数据
class _MyActivitiesTab extends ConsumerStatefulWidget {
  @override
  ConsumerState<_MyActivitiesTab> createState() => _MyActivitiesTabState();
}

class _MyActivitiesTabState extends ConsumerState<_MyActivitiesTab> {
  List<MyCommentItem> _comments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final comments = await ref.read(userRepositoryProvider).fetchMyComments();
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openCommentDetail(MyCommentItem comment) async {
    String postId = comment.postId.trim();
    if (postId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('正在定位原帖...'),
            duration: Duration(milliseconds: 900),
          ),
        );
      }
      postId = await _resolvePostIdByCommentId(comment.id);
    }

    if (!mounted) return;
    if (postId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法定位到原帖，帖子可能已删除或无访问权限')));
      return;
    }
    context.push(
      '/post/${Uri.encodeComponent(postId)}?commentId=${Uri.encodeComponent(comment.id)}',
    );
  }

  Future<String> _resolvePostIdByCommentId(String commentId) async {
    final String targetCommentId = commentId.trim();
    if (targetCommentId.isEmpty) {
      return '';
    }

    final postRepo = ref.read(postRepositoryProvider);
    final List<PostItem> candidates = <PostItem>[];
    try {
      candidates.addAll(await postRepo.fetchMyPosts());
    } catch (_) {}
    try {
      candidates.addAll(await postRepo.fetchFavoritePosts());
    } catch (_) {}
    try {
      candidates.addAll(await postRepo.fetchPosts());
    } catch (_) {}

    final Set<String> seenPostIds = <String>{};
    final List<String> orderedPostIds = <String>[];
    for (final PostItem post in candidates) {
      final String postId = post.id.trim();
      if (postId.isEmpty || !seenPostIds.add(postId)) {
        continue;
      }
      orderedPostIds.add(postId);
      if (orderedPostIds.length >= 200) {
        break;
      }
    }

    for (final String postId in orderedPostIds) {
      try {
        final List<CommentItem> comments = await postRepo.fetchComments(postId);
        if (comments.any((CommentItem c) => c.id.trim() == targetCommentId)) {
          return postId;
        }
      } catch (_) {}
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: MobileTheme.primaryOf(context)),
      );
    }
    if (_comments.isEmpty) {
      return _EmptyHint(icon: Icons.comment_outlined, text: '还没有评论过');
    }
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: _comments.length,
      separatorBuilder: (_, __) => Divider(height: 0.5, color: colors.divider),
      itemBuilder: (context, i) {
        final c = _comments[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _openCommentDetail(c),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.postTitle,
                  style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  c.content,
                  style: TextStyle(fontSize: 14, color: colors.textPrimary),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  c.timeText,
                  style: TextStyle(fontSize: 12, color: colors.textTertiary),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyHint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Icon(icon, size: 48, color: colors.divider),
            const SizedBox(height: 12),
            Text(
              text,
              style: TextStyle(fontSize: 14, color: colors.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
