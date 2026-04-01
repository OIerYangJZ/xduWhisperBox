import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import 'package:xdu_treehole_web/core/state/app_providers.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/models/public_user_profile.dart';
import '../home/post_card.dart';
import '../widgets/avatar_widget.dart';

/// 搜索页
/// 支持搜索帖子和用户
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

enum SearchTab { posts, users }

class _SearchPageState extends ConsumerState<SearchPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;

  SearchTab _currentTab = SearchTab.posts;
  bool _isSearching = false;
  bool _hasSearched = false;
  List<PostItem> _postResults = <PostItem>[];
  List<PublicUserProfile> _userResults = <PublicUserProfile>[];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTab = _tabController.index == 0
              ? SearchTab.posts
              : SearchTab.users;
          _hasSearched = false;
          _postResults = <PostItem>[];
          _userResults = <PublicUserProfile>[];
          _searchController.clear();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleSearch() async {
    final String keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      if (_currentTab == SearchTab.posts) {
        final List<PostItem> results = await ref
            .read(postRepositoryProvider)
            .fetchPosts(keyword: keyword);
        if (mounted) {
          setState(() {
            _postResults = results;
          });
        }
      } else {
        final List<PublicUserProfile> users = await ref
            .read(userRepositoryProvider)
            .searchUsers(keyword);
        if (mounted) {
          setState(() {
            _userResults = users;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('搜索失败，请稍后重试')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            TabBar(
              controller: _tabController,
              labelColor: MobileTheme.primaryOf(context),
              unselectedLabelColor: colors.textSecondary,
              indicatorColor: MobileTheme.primaryOf(context),
              tabs: const [
                Tab(text: '搜索帖子'),
                Tab(text: '搜索用户'),
              ],
            ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : _currentTab == SearchTab.posts
                  ? _buildPostResults()
                  : _buildUserResult(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final colors = MobileColors.of(context);
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _handleSearch(),
              decoration: InputDecoration(
                hintText: _currentTab == SearchTab.posts
                    ? '搜索帖子...'
                    : '输入昵称关键词...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _hasSearched = false;
                            _postResults = <PostItem>[];
                            _userResults = <PublicUserProfile>[];
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: colors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 40,
            child: ElevatedButton(
              onPressed: _isSearching ? null : _handleSearch,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('搜索'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostResults() {
    if (!_hasSearched && _searchController.text.trim().isEmpty) {
      return Center(
        child: Text(
          '输入关键词搜索帖子',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    if (_postResults.isEmpty) {
      return Center(
        child: Text(
          '没有找到匹配帖子',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    return ListView.separated(
      itemCount: _postResults.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return PostCard(
          post: post,
          onTap: () => context.push('/post/${post.id}'),
        );
      },
    );
  }

  Widget _buildUserResult() {
    if (!_hasSearched && _searchController.text.trim().isEmpty) {
      return Center(
        child: Text(
          '输入昵称后可模糊搜索用户',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    if (_userResults.isEmpty) {
      return Center(
        child: Text(
          '没有找到匹配用户',
          style: TextStyle(color: MobileColors.of(context).textSecondary),
        ),
      );
    }
    final colors = MobileColors.of(context);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _userResults.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _userResults[index];
        return GestureDetector(
          onTap: () => context.push('/user/${user.userId}'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                AvatarWidget(
                  avatarUrl: user.avatarUrl,
                  nickname: user.nickname,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.nickname,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (user.bio.isNotEmpty)
                        Text(
                          user.bio,
                          style: TextStyle(
                            fontSize: 13,
                            color: colors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textTertiary),
              ],
            ),
          ),
        );
      },
    );
  }
}
