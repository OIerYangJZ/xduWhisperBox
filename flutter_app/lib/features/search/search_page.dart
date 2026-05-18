import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/navigation/post_detail_nav.dart';
import '../../core/widgets/async_page_state.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/post_repository.dart';
import '../../widgets/post_card.dart';
import '../profile/public_user_profile_page.dart';
import 'search_controller.dart';

class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({
    super.key,
    this.initialKeyword = '',
    this.autofocus = false,
  });

  final String initialKeyword;
  final bool autofocus;

  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const List<PostSort> _webSorts = <PostSort>[
    PostSort.latest,
    PostSort.hot,
  ];

  final TextEditingController _queryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _queryController.text = widget.initialKeyword.trim();
    Future<void>.microtask(() async {
      final notifier = ref.read(searchControllerProvider.notifier);
      if (_queryController.text.trim().isNotEmpty) {
        notifier.setKeyword(_queryController.text.trim());
      }
      await notifier.loadInitial();
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SearchState state = ref.watch(searchControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('搜索')),
      body: AsyncPageState(
        loading: state.loading,
        error: state.error,
        onRetry: () =>
            ref.read(searchControllerProvider.notifier).loadInitial(),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: <Widget>[
            TextField(
              controller: _queryController,
              autofocus: widget.autofocus,
              decoration: const InputDecoration(
                hintText: '输入关键词搜索帖子，或按昵称搜索用户',
                prefixIcon: Icon(Icons.search),
              ),
              onSubmitted: (_) => _submitSearch(),
            ),
            const SizedBox(height: 10),
            SegmentedButton<SearchResultTab>(
              segments: <ButtonSegment<SearchResultTab>>[
                ButtonSegment<SearchResultTab>(
                  value: SearchResultTab.posts,
                  label: Text('帖子 ${state.results.length}'),
                  icon: const Icon(Icons.article_outlined),
                ),
                ButtonSegment<SearchResultTab>(
                  value: SearchResultTab.users,
                  label: Text('用户 ${state.userResults.length}'),
                  icon: const Icon(Icons.person_search_outlined),
                ),
              ],
              selected: <SearchResultTab>{state.selectedTab},
              onSelectionChanged: (Set<SearchResultTab> value) {
                ref
                    .read(searchControllerProvider.notifier)
                    .updateTab(value.first);
              },
            ),
            const SizedBox(height: 10),
            if (state.selectedTab == SearchResultTab.posts) ...<Widget>[
              _buildPostFilters(state),
              const SizedBox(height: 10),
              if (state.searching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Text('共找到 ${state.results.length} 条帖子'),
              const SizedBox(height: 6),
              ...state.results.map(
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
                        .read(searchControllerProvider.notifier)
                        .replaceResult(updated);
                  },
                ),
              ),
              if (state.results.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('没有匹配帖子，换个关键词试试。')),
                ),
            ] else ...<Widget>[
              _buildUserSearchActions(state),
              const SizedBox(height: 10),
              if (state.searching)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              Text('共找到 ${state.userResults.length} 位用户'),
              const SizedBox(height: 6),
              if (state.keyword.trim().isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('输入昵称后即可搜索用户。')),
                )
              else ...<Widget>[
                ...state.userResults.map(_buildUserCard),
                if (state.userResults.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('没有找到匹配昵称的用户。')),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPostFilters(SearchState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<String>(
            initialValue: state.selectedChannel,
            decoration: const InputDecoration(
              labelText: '频道',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: state.channels
                .map(
                  (String c) =>
                      DropdownMenuItem<String>(value: c, child: Text(c)),
                )
                .toList(),
            onChanged: state.searching
                ? null
                : (String? value) {
                    if (value == null) {
                      return;
                    }
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateChannel(value);
                  },
          ),
        ),
        SizedBox(
          width: 150,
          child: DropdownButtonFormField<PostStatus?>(
            initialValue: state.status,
            decoration: const InputDecoration(
              labelText: '状态',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: <DropdownMenuItem<PostStatus?>>[
              const DropdownMenuItem<PostStatus?>(
                value: null,
                child: Text('全部状态'),
              ),
              ...PostStatus.values.map(
                (PostStatus status) => DropdownMenuItem<PostStatus?>(
                  value: status,
                  child: Text(status.label),
                ),
              ),
            ],
            onChanged: state.searching
                ? null
                : (PostStatus? value) {
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateStatus(value);
                  },
          ),
        ),
        SizedBox(
          width: 180,
          child: DropdownButtonFormField<PostSort>(
            initialValue: state.sort,
            decoration: const InputDecoration(
              labelText: '排序',
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            items: _webSorts
                .map(
                  (PostSort value) => DropdownMenuItem<PostSort>(
                    value: value,
                    child: Text(value.label),
                  ),
                )
                .toList(),
            onChanged: state.searching
                ? null
                : (PostSort? value) {
                    if (value == null) {
                      return;
                    }
                    ref
                        .read(searchControllerProvider.notifier)
                        .updateSort(value);
                  },
          ),
        ),
        FilterChip(
          label: const Text('仅看有图'),
          selected: state.imageOnly,
          onSelected: state.searching
              ? null
              : (bool selected) {
                  ref
                      .read(searchControllerProvider.notifier)
                      .updateImageOnly(selected);
                },
        ),
        FilterChip(
          label: const Text('仅看可私信'),
          selected: state.dmOnly,
          onSelected: state.searching
              ? null
              : (bool selected) {
                  ref
                      .read(searchControllerProvider.notifier)
                      .updateDmOnly(selected);
                },
        ),
        FilledButton.icon(
          onPressed: state.searching ? null : _submitSearch,
          icon: const Icon(Icons.search),
          label: const Text('搜索'),
        ),
      ],
    );
  }

  Widget _buildUserSearchActions(SearchState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        const Chip(
          avatar: Icon(Icons.person_search_outlined, size: 16),
          label: Text('按昵称搜索用户'),
        ),
        FilledButton.icon(
          onPressed: state.searching ? null : _submitSearch,
          icon: const Icon(Icons.search),
          label: const Text('搜索用户'),
        ),
      ],
    );
  }

  Widget _buildUserCard(PublicUserProfile profile) {
    final String resolvedAvatar = AppConfig.resolveUrl(profile.avatarUrl);
    final String fallback = profile.nickname.trim().isEmpty
        ? '?'
        : profile.nickname.trim().substring(0, 1);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE5EAF3),
          backgroundImage: resolvedAvatar.isNotEmpty
              ? NetworkImage(resolvedAvatar)
              : null,
          child: resolvedAvatar.isEmpty ? Text(fallback) : null,
        ),
        title: Text(profile.nickname),
        subtitle: Text(
          '${profile.userLevelLabel} · 帖子 ${profile.postCount} · 粉丝 ${profile.followerCount}',
        ),
        trailing: profile.isFollowing
            ? const Chip(
                label: Text('已关注'),
                visualDensity: VisualDensity.compact,
              )
            : null,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => PublicUserProfilePage(userId: profile.id),
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitSearch() {
    ref
        .read(searchControllerProvider.notifier)
        .setKeyword(_queryController.text.trim());
    return ref.read(searchControllerProvider.notifier).search();
  }
}
