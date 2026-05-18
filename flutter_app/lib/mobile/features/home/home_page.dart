import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../../features/widgets/shimmer_loading.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'post_card.dart';
import '../shell/mobile_shell.dart';

/// 每个频道对应的图标和颜色
const Map<String, _ChannelMeta> _channelMeta = <String, _ChannelMeta>{
  '全部': _ChannelMeta(Icons.menu_rounded, Color(0xFF8E8E93)),
  '综合': _ChannelMeta(Icons.wb_sunny_rounded, Color(0xFF6B7FD7)),
  '找对象': _ChannelMeta(Icons.favorite_rounded, Color(0xFFE05E7A)),
  '找搭子': _ChannelMeta(Icons.group_rounded, Color(0xFFE09C5E)),
  '交友扩列': _ChannelMeta(Icons.people_alt_rounded, Color(0xFF5EC4AF)),
  '吐槽日常': _ChannelMeta(Icons.mode_comment_rounded, Color(0xFF9B6ED4)),
  '八卦吃瓜': _ChannelMeta(Icons.local_fire_department_rounded, Color(0xFFD4A05E)),
  '求助问答': _ChannelMeta(Icons.live_help_rounded, Color(0xFF5EAAD4)),
  '失物招领': _ChannelMeta(Icons.manage_search_rounded, Color(0xFFD45E8A)),
  '二手交易': _ChannelMeta(Icons.storefront_rounded, Color(0xFF5EAF7C)),
  '学习交流': _ChannelMeta(Icons.menu_book_rounded, Color(0xFF5E8FD4)),
  '活动拼车': _ChannelMeta(Icons.directions_car_filled_rounded, Color(0xFF5E8FD4)),
  '其他': _ChannelMeta(Icons.more_horiz_rounded, Color(0xFF8E8E93)),
  // 兼容历史命名
  '学习': _ChannelMeta(Icons.menu_book_rounded, Color(0xFF5E8FD4)),
  '二手': _ChannelMeta(Icons.storefront_rounded, Color(0xFF5EAF7C)),
  '失物': _ChannelMeta(Icons.manage_search_rounded, Color(0xFFD45E8A)),
  '吐槽': _ChannelMeta(Icons.mode_comment_rounded, Color(0xFF9B6ED4)),
  '问答': _ChannelMeta(Icons.live_help_rounded, Color(0xFF5EAAD4)),
  '租房': _ChannelMeta(Icons.apartment_rounded, Color(0xFF5EC4AF)),
  '情感': _ChannelMeta(Icons.favorite_rounded, Color(0xFFE05E7A)),
  '娱乐': _ChannelMeta(Icons.local_movies_rounded, Color(0xFFD4A05E)),
  '校园': _ChannelMeta(Icons.account_balance_rounded, Color(0xFF5EAF7C)),
  '生活': _ChannelMeta(Icons.local_cafe_rounded, Color(0xFFAA8B6E)),
  '运动': _ChannelMeta(Icons.directions_run_rounded, Color(0xFFD45E5E)),
  '表白': _ChannelMeta(Icons.local_florist_rounded, Color(0xFFE05E9B)),
  '公告': _ChannelMeta(Icons.campaign_rounded, Color(0xFF5E8FD4)),
};

const List<IconData> _fallbackIcons = <IconData>[
  Icons.topic_rounded,
  Icons.explore_rounded,
  Icons.coffee_rounded,
  Icons.palette_rounded,
  Icons.science_rounded,
  Icons.sports_basketball_rounded,
  Icons.music_note_rounded,
  Icons.pets_rounded,
  Icons.travel_explore_rounded,
  Icons.emoji_objects_rounded,
  Icons.auto_stories_rounded,
  Icons.flight_takeoff_rounded,
];

const List<Color> _fallbackColors = <Color>[
  Color(0xFF6B7FD7),
  Color(0xFF5EAAD4),
  Color(0xFF5EAF7C),
  Color(0xFFE09C5E),
  Color(0xFFD45E8A),
  Color(0xFF9B6ED4),
  Color(0xFFAA8B6E),
  Color(0xFFD45E5E),
  Color(0xFF5EC4AF),
];

Map<String, _ChannelMeta> _resolveChannelMetaMap(List<String> channels) {
  final resolved = <String, _ChannelMeta>{};
  final usedIcons = <IconData>{};
  final usedColors = <Color>{};

  for (final channel in channels) {
    final matched = _channelMeta[channel] ?? _metaFromKeyword(channel);
    if (matched != null) {
      final seed = channel.hashCode & 0x7fffffff;
      final icon = usedIcons.contains(matched.icon)
          ? _pickUnusedIcon(seed, usedIcons)
          : matched.icon;
      final color = usedColors.contains(matched.color)
          ? _pickUnusedColor(seed, usedColors)
          : matched.color;
      resolved[channel] = _ChannelMeta(icon, color);
      usedIcons.add(icon);
      usedColors.add(color);
    }
  }

  for (final channel in channels) {
    if (resolved.containsKey(channel)) continue;
    final seed = channel.hashCode & 0x7fffffff;
    final icon = _pickUnusedIcon(seed, usedIcons);
    final color = _pickUnusedColor(seed, usedColors);
    usedIcons.add(icon);
    usedColors.add(color);
    resolved[channel] = _ChannelMeta(icon, color);
  }

  return resolved;
}

_ChannelMeta? _metaFromKeyword(String channel) {
  if (channel.contains('二手')) return _channelMeta['二手交易'];
  if (channel.contains('失物')) return _channelMeta['失物招领'];
  if (channel.contains('吐槽')) return _channelMeta['吐槽日常'];
  if (channel.contains('问答') || channel.contains('求助')) {
    return _channelMeta['求助问答'];
  }
  if (channel.contains('学习')) return _channelMeta['学习交流'];
  if (channel.contains('找搭子')) return _channelMeta['找搭子'];
  if (channel.contains('找对象')) return _channelMeta['找对象'];
  if (channel.contains('交友')) return _channelMeta['交友扩列'];
  if (channel.contains('吃瓜') || channel.contains('八卦'))
    return _channelMeta['八卦吃瓜'];
  if (channel.contains('拼车') || channel.contains('活动'))
    return _channelMeta['活动拼车'];
  return null;
}

IconData _pickUnusedIcon(int seed, Set<IconData> usedIcons) {
  if (usedIcons.length >= _fallbackIcons.length) {
    return _fallbackIcons[seed % _fallbackIcons.length];
  }
  for (var i = 0; i < _fallbackIcons.length; i++) {
    final icon = _fallbackIcons[(seed + i) % _fallbackIcons.length];
    if (!usedIcons.contains(icon)) return icon;
  }
  return Icons.grid_view_rounded;
}

Color _pickUnusedColor(int seed, Set<Color> usedColors) {
  if (usedColors.length >= _fallbackColors.length) {
    return _fallbackColors[seed % _fallbackColors.length];
  }
  for (var i = 0; i < _fallbackColors.length; i++) {
    final color = _fallbackColors[(seed + i) % _fallbackColors.length];
    if (!usedColors.contains(color)) return color;
  }
  return const Color(0xFF8E8E93);
}

class _ChannelMeta {
  final IconData icon;
  final Color color;
  const _ChannelMeta(this.icon, this.color);
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final _scrollController = ScrollController();
  final _channelScrollController = ScrollController();

  /// FAB 是否已隐藏（与底部导航栏同步）
  bool _fabVisible = true;
  double _lastScrollOffset = 0;
  bool _isRefreshing = false;
  bool _showRefreshSuccessFlash = false;
  List<String> _lockedOrderPostIds = const <String>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(feedControllerProvider.notifier).loadInitial();
    });
    _scrollController.addListener(_onScroll);
    BottomNavVisibilityNotifier.instance.addListener(_onNavVisibilityChanged);
  }

  void _onNavVisibilityChanged() {
    if (!mounted) return;
    final visible = BottomNavVisibilityNotifier.instance.visible;
    if (_fabVisible != visible) {
      setState(() => _fabVisible = visible);
    }
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }

  List<PostItem> _postsForDisplay(List<PostItem> posts) {
    if (_lockedOrderPostIds.isEmpty || posts.length <= 1) {
      return posts;
    }

    final Map<String, PostItem> byId = <String, PostItem>{
      for (final post in posts) post.id: post,
    };
    final List<PostItem> ordered = <PostItem>[];

    for (final postId in _lockedOrderPostIds) {
      final post = byId.remove(postId);
      if (post != null) {
        ordered.add(post);
      }
    }

    if (byId.isNotEmpty) {
      for (final post in posts) {
        if (byId.containsKey(post.id)) {
          ordered.add(post);
        }
      }
    }

    return ordered;
  }

  Future<void> _refreshHomeFeed() async {
    if (_isRefreshing) {
      return;
    }

    setState(() {
      _isRefreshing = true;
    });

    bool refreshSucceeded = false;
    try {
      await ref.read(feedControllerProvider.notifier).refreshPosts();
      refreshSucceeded = ref.read(feedControllerProvider).error == null;
    } finally {
      if (!mounted) {
        return;
      }
      setState(() {
        _isRefreshing = false;
        _showRefreshSuccessFlash = refreshSucceeded;
      });
      if (refreshSucceeded) {
        await Future<void>.delayed(const Duration(milliseconds: 140));
        if (!mounted) {
          return;
        }
        setState(() {
          _showRefreshSuccessFlash = false;
        });
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 每次回到首页时恢复底部导航栏可见性
    BottomNavVisibilityNotifier.instance.show();
  }

  @override
  void dispose() {
    BottomNavVisibilityNotifier.instance.removeListener(
      _onNavVisibilityChanged,
    );
    _scrollController.dispose();
    _channelScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // 懒加载更多
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (maxScroll - currentScroll < 200) {
      ref.read(feedControllerProvider.notifier).loadMoreIfNeeded();
    }

    final delta = currentScroll - _lastScrollOffset;

    // 底部导航栏显示/隐藏（任何明显方向性滚动即触发）
    if (delta > 1) {
      BottomNavVisibilityNotifier.instance.hide();
    } else if (delta < -1) {
      BottomNavVisibilityNotifier.instance.show();
    }

    _lastScrollOffset = currentScroll;
  }

  Future<void> _handleLike(PostItem post) async {
    final wasLiked = post.isLiked;
    final optimistic = post.copyWith(
      isLiked: !wasLiked,
      likeCount: post.likeCount + (wasLiked ? -1 : 1),
    );
    ref.read(feedControllerProvider.notifier).replacePost(optimistic);
    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (wasLiked) {
        await postRepo.unlikePost(post.id);
      } else {
        await postRepo.likePost(post.id);
      }
    } catch (_) {
      ref.read(feedControllerProvider.notifier).replacePost(post);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
      }
    }
  }

  Future<void> _handleFavorite(PostItem post) async {
    // 乐观更新：先本地更新，API 失败再回滚
    final optimistic = post.copyWith(
      isFavorited: !post.isFavorited,
      favoriteCount: post.favoriteCount + (post.isFavorited ? -1 : 1),
    );
    ref.read(feedControllerProvider.notifier).replacePost(optimistic);
    try {
      final postRepo = ref.read(postRepositoryProvider);
      if (post.isFavorited) {
        await postRepo.unfavoritePost(post.id);
      } else {
        await postRepo.favoritePost(post.id);
      }
    } catch (_) {
      ref.read(feedControllerProvider.notifier).replacePost(post);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
      }
    }
  }

  /// 将指定 channel chip 滚动到可视区域中央
  void _scrollChannelToCenter(int index) {
    if (!_channelScrollController.hasClients) return;
    final scrollWidth = _channelScrollController.position.maxScrollExtent;
    if (scrollWidth <= 0) return;

    const estimatedChipWidth = 90.0;
    final targetOffset =
        (index * estimatedChipWidth) -
        (MediaQuery.of(context).size.width / 2) +
        (estimatedChipWidth / 2);
    final clamped = targetOffset.clamp(0.0, scrollWidth);
    _channelScrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = MobileTheme.primaryOf(context);
    final feedState = ref.watch(feedControllerProvider);
    final visiblePosts = _postsForDisplay(feedState.posts);
    final notificationsState = ref.watch(notificationsControllerProvider);
    final resolvedChannelMeta = _resolveChannelMetaMap(feedState.channels);
    final selectedChannelMeta = resolvedChannelMeta[feedState.selectedChannel];
    final selectedChannelIcon = selectedChannelMeta?.icon ?? Icons.menu_rounded;
    final selectedChannelIconColor =
        selectedChannelMeta?.color ?? colors.textPrimary;
    // 监听「滚动到顶部」触发器（必须在 build 中调用，initState 中调用不可靠）
    ref.listen<int>(scrollToTopTriggerProvider, (_, __) {
      _scrollToTop();
    });
    ref.listen<int>(
      feedControllerProvider.select((state) => state.orderVersion),
      (_, __) {
        final posts = ref.read(feedControllerProvider).posts;
        if (!mounted) {
          return;
        }
        setState(() {
          _lockedOrderPostIds = posts
              .map((post) => post.id)
              .toList(growable: false);
        });
      },
    );

    return Scaffold(
      backgroundColor: colors.background,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _refreshHomeFeed,
            color: primaryColor,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // 小红书风格 AppBar：频道选择器 + 排序 + 操作按钮全部在顶部
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 50,
                  backgroundColor: isDarkMode ? Colors.black : colors.surface,
                  elevation: 0,
                  scrolledUnderElevation: isDarkMode ? 0 : 0.5,
                  surfaceTintColor: Colors.transparent,
                  toolbarHeight: 50,
                  titleSpacing: 0,
                  systemOverlayStyle: isDarkMode
                      ? SystemUiOverlayStyle.light
                      : SystemUiOverlayStyle.dark,
                  title: Row(
                    children: [
                      // 频道下拉选择器（仅三横线图标）
                      PopupMenuButton<String>(
                        offset: const Offset(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: colors.surface,
                        itemBuilder: (context) {
                          return feedState.channels.map((channel) {
                            final isSelected =
                                channel == feedState.selectedChannel;
                            final meta = resolvedChannelMeta[channel];
                            return PopupMenuItem<String>(
                              value: channel,
                              height: 48,
                              child: Row(
                                children: [
                                  Icon(
                                    meta?.icon ?? Icons.grid_view_rounded,
                                    size: 20,
                                    color: isSelected
                                        ? primaryColor
                                        : (meta?.color ?? colors.textSecondary),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      channel,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? primaryColor
                                            : colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check,
                                      size: 18,
                                      color: primaryColor,
                                    ),
                                ],
                              ),
                            );
                          }).toList();
                        },
                        onSelected: (channel) {
                          ref
                              .read(feedControllerProvider.notifier)
                              .switchChannel(channel);
                        },
                        child: Container(
                          width: 60,
                          height: 40,
                          decoration: BoxDecoration(
                            color: colors.background,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            selectedChannelIcon,
                            size: 22,
                            color: selectedChannelIconColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 排序切换
                      _CompactSortToggle(
                        sort: feedState.sort,
                        onSortChanged: (sort) => ref
                            .read(feedControllerProvider.notifier)
                            .switchSort(sort),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search, size: 24),
                      onPressed: () => context.push('/search'),
                    ),
                    IconButton(
                      icon: Badge(
                        isLabelVisible: notificationsState.unreadCount > 0,
                        label: Text(
                          notificationsState.unreadCount > 99
                              ? '99+'
                              : notificationsState.unreadCount.toString(),
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Icon(
                          Icons.notifications_outlined,
                          size: 24,
                        ),
                      ),
                      onPressed: () => context.push('/notifications'),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),

                // 帖子列表（全宽，无外层 margin）
                if (feedState.loading && visiblePosts.isEmpty)
                  const SliverFillRemaining(child: HomePageShimmer())
                else if (feedState.error != null && visiblePosts.isEmpty)
                  SliverFillRemaining(
                    child: _ErrorView(
                      message: feedState.error!,
                      onRetry: () {
                        ref.read(feedControllerProvider.notifier).loadInitial();
                      },
                    ),
                  )
                else if (visiblePosts.isEmpty)
                  const SliverFillRemaining(child: _EmptyView())
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index == visiblePosts.length) {
                            if (feedState.hasMore) {
                              return Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          }
                          final post = visiblePosts[index];
                          return PostCard(
                            key: ValueKey(post.id),
                            post: post,
                            onTap: () => context.push('/post/${post.id}'),
                            onLike: () => _handleLike(post),
                            showTopDivider: index != 0,
                          );
                        },
                        childCount:
                            visiblePosts.length + (feedState.hasMore ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IgnorePointer(
            ignoring: !_showRefreshSuccessFlash,
            child: AnimatedOpacity(
              opacity: _showRefreshSuccessFlash ? 1 : 0,
              duration: const Duration(milliseconds: 90),
              child: const ColoredBox(
                color: Colors.white,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),

      // FAB：右下角圆形 + 图标，无文字
      floatingActionButton: AnimatedSlide(
        offset: _fabVisible ? Offset.zero : const Offset(0, 2),
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOut,
        child: AnimatedOpacity(
          opacity: _fabVisible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 220),
          child: FloatingActionButton(
            onPressed: () => context.push('/post/create'),
            backgroundColor: primaryColor,
            elevation: 4,
            child: const Icon(Icons.edit, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 频道栏 Delegate（SliverPersistentHeader 实现固定 + 背景效果）
// ---------------------------------------------------------------------------
class _ChannelBarDelegate extends SliverPersistentHeaderDelegate {
  final List<String> channels;
  final String selectedChannel;
  final ScrollController scrollController;
  final void Function(String channel, int index) onChannelSelected;

  _ChannelBarDelegate({
    required this.channels,
    required this.selectedChannel,
    required this.scrollController,
    required this.onChannelSelected,
  });

  @override
  double get minExtent => 44;

  @override
  double get maxExtent => 44;

  @override
  bool shouldRebuild(covariant _ChannelBarDelegate old) =>
      channels != old.channels || selectedChannel != old.selectedChannel;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    final selectedIndex = channels.indexOf(selectedChannel);
    final resolvedChannelMeta = _resolveChannelMetaMap(channels);

    return Container(
      height: 44,
      color: colors.surface,
      child: Column(
        children: [
          Expanded(
            child: channels.isEmpty
                ? Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: primaryColor,
                      ),
                    ),
                  )
                : Stack(
                    children: [
                      ListView.builder(
                        controller: scrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        itemCount: channels.length,
                        itemBuilder: (context, index) {
                          final channel = channels[index];
                          final isSelected = channel == selectedChannel;
                          final meta = resolvedChannelMeta[channel];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: _ChannelChip(
                              label: channel,
                              icon: meta?.icon,
                              iconColor: meta?.color,
                              isSelected: isSelected,
                              isFirst: index == 0,
                              onTap: () => onChannelSelected(channel, index),
                            ),
                          );
                        },
                      ),

                      // 左侧渐变遮罩
                      if (selectedIndex > 1)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                  colors: [
                                    colors.surface,
                                    colors.surface.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                      // 右侧渐变遮罩
                      if (selectedIndex < channels.length - 2)
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 0,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.centerRight,
                                  end: Alignment.centerLeft,
                                  colors: [
                                    colors.surface,
                                    colors.surface.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
          Container(height: 0.5, color: colors.divider),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 频道 Chip 组件
// ---------------------------------------------------------------------------
class _ChannelChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool isSelected;
  final bool isFirst;
  final VoidCallback onTap;

  const _ChannelChip({
    required this.label,
    this.icon,
    this.iconColor,
    required this.isSelected,
    this.isFirst = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    final effectiveColor = isSelected ? primaryColor : colors.textSecondary;
    final effectiveIconColor = iconColor ?? effectiveColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : colors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? primaryColor : colors.divider,
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: effectiveIconColor.withValues(
                  alpha: isSelected ? 1.0 : 0.75,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: effectiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 紧凑型排序 Toggle（用于 AppBar）
// ---------------------------------------------------------------------------
class _CompactSortToggle extends StatelessWidget {
  final PostSort sort;
  final void Function(PostSort) onSortChanged;

  const _CompactSortToggle({required this.sort, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.divider, width: 0.5),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CompactSortOption(
            icon: Icons.access_time,
            isSelected: sort == PostSort.latest,
            onTap: sort == PostSort.latest
                ? null
                : () => onSortChanged(PostSort.latest),
          ),
          _CompactSortOption(
            icon: Icons.local_fire_department,
            isSelected: sort == PostSort.hot,
            onTap: sort == PostSort.hot
                ? null
                : () => onSortChanged(PostSort.hot),
          ),
        ],
      ),
    );
  }
}

class _CompactSortOption extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;

  const _CompactSortOption({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        splashColor: colors.divider.withValues(alpha: 0.85),
        highlightColor: colors.divider.withValues(alpha: 0.2),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? primaryColor : colors.textTertiary,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 排序栏（仅 Toggle，无发帖按钮）
// ---------------------------------------------------------------------------
class _SortBar extends StatelessWidget {
  final PostSort sort;
  final void Function(PostSort) onSortChanged;

  const _SortBar({required this.sort, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: _SortToggle(sort: sort, onSortChanged: onSortChanged),
    );
  }
}

// ---------------------------------------------------------------------------
// 排序 Toggle 胶囊
// ---------------------------------------------------------------------------
class _SortToggle extends StatelessWidget {
  final PostSort sort;
  final void Function(PostSort) onSortChanged;

  const _SortToggle({required this.sort, required this.onSortChanged});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colors.divider, width: 0.8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SortOption(
            label: '最新',
            isSelected: sort == PostSort.latest,
            onTap: () => onSortChanged(PostSort.latest),
          ),
          _SortOption(
            label: '热门',
            isSelected: sort == PostSort.hot,
            onTap: () => onSortChanged(PostSort.hot),
          ),
        ],
      ),
    );
  }
}

class _SortOption extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SortOption({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? colors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label == '热门')
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.local_fire_department,
                  size: 13,
                  color: isSelected ? MobileTheme.accent : colors.textTertiary,
                ),
              ),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? primaryColor : colors.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 错误视图
// ---------------------------------------------------------------------------
class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: colors.textTertiary),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: colors.textSecondary, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 空状态视图
// ---------------------------------------------------------------------------
class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final primaryColor = MobileTheme.primaryOf(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.forum_outlined, size: 40, color: primaryColor),
            ),
            const SizedBox(height: 20),
            Text(
              '暂无帖子',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '成为第一个发布内容的人吧',
              style: TextStyle(color: colors.textTertiary, fontSize: 14),
            ),
            const SizedBox(height: 28),
            OutlinedButton.icon(
              onPressed: () => context.push('/post/create'),
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('发布帖子'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
