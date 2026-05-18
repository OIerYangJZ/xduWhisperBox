import 'package:flutter/material.dart';

import '../../core/navigation/post_detail_nav.dart';
import '../../models/post_item.dart';
import '../../repositories/app_repositories.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';

enum FavoriteSortMode {
  latest,
  hot,
}

extension FavoriteSortModeLabel on FavoriteSortMode {
  String get label {
    switch (this) {
      case FavoriteSortMode.latest:
        return '按时间';
      case FavoriteSortMode.hot:
        return '按热度';
    }
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => FavoritesPageState();
}

class FavoritesPageState extends State<FavoritesPage> {
  final TextEditingController _keywordController = TextEditingController();

  String _selectedChannel = '全部';
  FavoriteSortMode _sortMode = FavoriteSortMode.latest;
  List<String> _channels = const <String>['全部'];
  List<PostItem> _favorites = const <PostItem>[];
  Set<String> _updatingPostIds = <String>{};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> refreshFavorites() => _loadFavorites();

  @override
  void dispose() {
    _keywordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final List<PostItem> filtered = _buildFilteredFavorites();

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8, bottom: 24),
        children: <Widget>[
          _buildHero(context, filtered.length),
          const SizedBox(height: 10),
          _buildToolbar(context),
          const SizedBox(height: 10),
          _buildChannelBar(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          const SizedBox(height: 4),
          ...filtered.map(_buildFavoriteCard),
          if (filtered.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: Text(
                  _favorites.isEmpty ? '你还没有收藏帖子。' : '暂无符合条件的收藏内容。',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context, int filteredCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF155E75), Color(0xFF0F766E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '我的收藏夹',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '总收藏 ${_favorites.length} 条 · 当前显示 $filteredCount 条',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF155E75),
            ),
            onPressed: _loadFavorites,
            icon: const Icon(Icons.refresh),
            label: const Text('刷新'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: '搜索收藏帖子（标题/正文/标签）',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _keywordController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _keywordController.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              const Icon(Icons.sort_rounded, size: 18),
              const SizedBox(width: 6),
              const Text('排序', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 10),
              ...FavoriteSortMode.values.map(
                (FavoriteSortMode mode) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(mode.label),
                    selected: _sortMode == mode,
                    onSelected: (_) {
                      setState(() {
                        _sortMode = mode;
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBar() {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: _channels
            .map(
              (String channel) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(channel),
                  selected: _selectedChannel == channel,
                  onSelected: (_) {
                    setState(() {
                      _selectedChannel = channel;
                    });
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildFavoriteCard(PostItem post) {
    final bool busy = _updatingPostIds.contains(post.id);
    return Column(
      children: <Widget>[
        PostCard(
          post: post,
          onTap: () async {
            final PostItem? updated =
                await openPostDetailPage(context, post: post);
            if (!mounted || updated == null) {
              return;
            }
            setState(() {
              if (!updated.isFavorited) {
                _favorites = _favorites
                    .where((PostItem item) => item.id != updated.id)
                    .toList(growable: false);
                return;
              }
              _favorites = _favorites
                  .map(
                    (PostItem item) => item.id == updated.id ? updated : item,
                  )
                  .toList(growable: false);
            });
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 6),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: busy ? null : () => _unfavorite(post),
              icon: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.bookmark_remove_outlined),
              label: Text(busy ? '处理中...' : '取消收藏'),
            ),
          ),
        ),
      ],
    );
  }

  List<PostItem> _buildFilteredFavorites() {
    final String keyword = _keywordController.text.trim().toLowerCase();

    final List<PostItem> rows = _favorites.where((PostItem post) {
      final bool matchChannel =
          _selectedChannel == '全部' || post.channel == _selectedChannel;
      if (!matchChannel) {
        return false;
      }
      if (keyword.isEmpty) {
        return true;
      }
      final String text =
          '${post.title} ${post.content} ${post.channel} ${post.tags.join(' ')}'
              .toLowerCase();
      return text.contains(keyword);
    }).toList();

    return sortPostsForView(
      rows,
      sort: _sortMode == FavoriteSortMode.hot ? PostSort.hot : PostSort.latest,
    );
  }

  Future<void> _unfavorite(PostItem post) async {
    setState(() {
      _updatingPostIds = <String>{..._updatingPostIds, post.id};
    });

    try {
      final FavoriteActionResult result =
          await AppRepositories.posts.unfavoritePost(post.id);
      if (!mounted) {
        return;
      }

      if (result.favorited) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('取消收藏失败，请稍后重试。')),
        );
        return;
      }

      setState(() {
        _favorites = _favorites
            .where((PostItem item) => item.id != post.id)
            .toList(growable: false);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('已取消收藏：${post.title}'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () {
              _restoreFavorite(post);
            },
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('取消收藏失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingPostIds = <String>{..._updatingPostIds}..remove(post.id);
        });
      }
    }
  }

  Future<void> _restoreFavorite(PostItem post) async {
    try {
      final FavoriteActionResult result =
          await AppRepositories.posts.favoritePost(post.id);
      if (!mounted) {
        return;
      }
      final bool exists = _favorites.any((PostItem item) => item.id == post.id);
      if (exists) {
        return;
      }

      final PostItem restored = post.copyWith(
        isFavorited: true,
        favoriteCount: result.favoriteCount ?? post.favoriteCount,
      );

      setState(() {
        _favorites = <PostItem>[restored, ..._favorites];
        if (!_channels.contains(restored.channel)) {
          _channels = <String>[..._channels, restored.channel];
        }
      });
    } catch (_) {
      // ignore undo failure
    }
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final List<String> channels = await AppRepositories.posts.fetchChannels();
      final List<PostItem> posts =
          await AppRepositories.posts.fetchFavoritePosts();

      if (!mounted) {
        return;
      }

      setState(() {
        _channels = <String>['全部', ...channels.toSet()];
        _favorites = posts;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '收藏加载失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}
