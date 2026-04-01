import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../post/create_post_page.dart';
import '../search/search_page.dart';
import 'feed_controller.dart';

class FeedPage extends ConsumerStatefulWidget {
  const FeedPage({super.key});

  @override
  ConsumerState<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends ConsumerState<FeedPage> {
  static const List<PostSort> _webSorts = <PostSort>[
    PostSort.latest,
    PostSort.hot,
  ];

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
      () => ref.read(feedControllerProvider.notifier).loadInitial(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final FeedState state = ref.watch(feedControllerProvider);
    return AsyncPageState(
      loading: state.loading,
      error: state.error,
      onRetry: () => ref.read(feedControllerProvider.notifier).loadInitial(),
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(feedControllerProvider.notifier).refreshPosts(),
        child: ListView(
          padding: const EdgeInsets.only(top: 4, bottom: 120),
          children: <Widget>[
            const SizedBox(height: 8),
            _buildHeroBanner(state),
            const SizedBox(height: 10),
            _buildSearchEntry(),
            const SizedBox(height: 10),
            _buildSortPanel(state),
            const SizedBox(height: 10),
            _buildChannelPanel(state),
            const SizedBox(height: 6),
            ...state.posts.map(
              (PostItem post) => PostCard(
                post: post,
                onTap: () async {
                  final PostItem? updated = await openPostDetailPage(
                    context,
                    post: post,
                  );
                  if (updated == null || !mounted) {
                    return;
                  }
                  ref
                      .read(feedControllerProvider.notifier)
                      .replacePost(updated);
                },
              ),
            ),
            if (state.posts.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('当前筛选条件下暂无帖子。')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroBanner(FeedState state) {
    final ThemeData theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0E7490), Color(0xFF155E75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF155E75).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '校园树洞广场',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '当前频道：${state.selectedChannel} · 已加载 ${state.posts.length} 条',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _heroTag('排序：${state.sort.label}'),
                    _heroTag('下拉可刷新'),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        foregroundColor: const Color(0xFF155E75),
                        backgroundColor: Colors.white,
                      ),
                      onPressed: () => _openCreatePost(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('发布新帖'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      onPressed: () => ref
                          .read(feedControllerProvider.notifier)
                          .refreshPosts(),
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('刷新'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.campaign_outlined,
              color: Colors.white,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSearchEntry() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: const Color(0xFF0C4A6E).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        readOnly: true,
        decoration: const InputDecoration(
          hintText: '搜索帖子内容，或按昵称搜索用户',
          prefixIcon: Icon(Icons.search_rounded),
          suffixIcon: Icon(Icons.tune_rounded),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const SearchPage(autofocus: true),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortPanel(FeedState state) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF155E75).withValues(alpha: 0.1),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: <Widget>[
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.sort_rounded, size: 16, color: Color(0xFF155E75)),
              SizedBox(width: 4),
              Text('排序', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          ..._webSorts.map(
            (PostSort sort) => ChoiceChip(
              avatar: Icon(
                sort == PostSort.latest
                    ? Icons.schedule_rounded
                    : Icons.local_fire_department_outlined,
                size: 16,
              ),
              label: Text(sort.label),
              selected: state.sort == sort,
              onSelected: (_) =>
                  ref.read(feedControllerProvider.notifier).switchSort(sort),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChannelPanel(FeedState state) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: state.channels
            .map(
              (String channel) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(_channelIcon(channel), size: 16),
                  label: Text(channel),
                  selected: channel == state.selectedChannel,
                  onSelected: (_) => ref
                      .read(feedControllerProvider.notifier)
                      .switchChannel(channel),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  IconData _channelIcon(String channel) {
    switch (channel) {
      case '全部':
        return Icons.apps_rounded;
      case '学习交流':
        return Icons.menu_book_outlined;
      case '二手交易':
        return Icons.shopping_bag_outlined;
      case '找搭子':
        return Icons.sports_basketball_outlined;
      case '失物招领':
        return Icons.search_rounded;
      case '吐槽日常':
        return Icons.mood_outlined;
      default:
        return Icons.tag_outlined;
    }
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
}
