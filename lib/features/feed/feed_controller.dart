import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../repositories/post_repository.dart';

class FeedState {
  const FeedState({
    this.selectedChannel = '全部',
    this.sort = PostSort.hot,
    this.channels = const <String>['全部'],
    this.posts = const <PostItem>[],
    this.loading = true,
    this.loadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = false,
    this.orderVersion = 0,
  });

  final String selectedChannel;
  final PostSort sort;
  final List<String> channels;
  final List<PostItem> posts;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final int page;
  final bool hasMore;
  final int orderVersion;

  FeedState copyWith({
    String? selectedChannel,
    PostSort? sort,
    List<String>? channels,
    List<PostItem>? posts,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool clearError = false,
    int? page,
    bool? hasMore,
    int? orderVersion,
  }) {
    return FeedState(
      selectedChannel: selectedChannel ?? this.selectedChannel,
      sort: sort ?? this.sort,
      channels: channels ?? this.channels,
      posts: posts ?? this.posts,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      orderVersion: orderVersion ?? this.orderVersion,
    );
  }
}

class FeedController extends StateNotifier<FeedState> {
  FeedController(this._ref) : super(const FeedState());

  final Ref _ref;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final List<String> channels = await _ref
          .read(postRepositoryProvider)
          .fetchChannels();
      final List<PostItem> posts = await _ref
          .read(postRepositoryProvider)
          .fetchPosts(sort: state.sort);
      state = state.copyWith(
        channels: <String>['全部', ...channels.toSet().where((c) => c != '其他')],
        posts: sortPostsForView(posts, sort: state.sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> refreshPosts() async {
    try {
      final List<PostItem> posts = await _ref
          .read(postRepositoryProvider)
          .fetchPosts(
            channel: state.selectedChannel == '全部'
                ? null
                : state.selectedChannel,
            sort: state.sort,
          );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: state.sort),
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(error: '刷新失败：$error');
    }
  }

  Future<void> switchChannel(String channel) async {
    state = state.copyWith(
      selectedChannel: channel,
      loading: true,
      clearError: true,
    );
    try {
      final List<PostItem> posts = await _ref
          .read(postRepositoryProvider)
          .fetchPosts(
            channel: channel == '全部' ? null : channel,
            sort: state.sort,
          );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: state.sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '加载失败：$error');
    }
  }

  Future<void> switchSort(PostSort sort) async {
    state = state.copyWith(sort: sort, loading: true, clearError: true);
    try {
      final List<PostItem> posts = await _ref
          .read(postRepositoryProvider)
          .fetchPosts(
            channel: state.selectedChannel == '全部'
                ? null
                : state.selectedChannel,
            sort: sort,
          );
      state = state.copyWith(
        posts: sortPostsForView(posts, sort: sort),
        loading: false,
        clearError: true,
        page: 1,
        hasMore: posts.length >= 20,
        orderVersion: state.orderVersion + 1,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '排序切换失败：$error');
    }
  }

  Future<void> loadMoreIfNeeded() async {
    if (state.loadingMore || !state.hasMore || state.loading) return;
    state = state.copyWith(loadingMore: true);
    try {
      final nextPage = state.page + 1;
      final List<PostItem> morePosts = await _ref
          .read(postRepositoryProvider)
          .fetchPosts(
            channel: state.selectedChannel == '全部'
                ? null
                : state.selectedChannel,
            sort: state.sort,
          );
      final Set<String> existingIds = state.posts
          .map((PostItem item) => item.id)
          .toSet();
      final List<PostItem> uniqueMorePosts = morePosts
          .where((PostItem item) => existingIds.add(item.id))
          .toList(growable: false);
      state = state.copyWith(
        posts: sortPostsForView(<PostItem>[
          ...state.posts,
          ...uniqueMorePosts,
        ], sort: state.sort),
        loadingMore: false,
        page: nextPage,
        hasMore: morePosts.length >= 20 && uniqueMorePosts.isNotEmpty,
      );
    } catch (_) {
      state = state.copyWith(loadingMore: false);
    }
  }

  void replacePost(PostItem updated) {
    final int index = state.posts.indexWhere(
      (PostItem item) => item.id == updated.id,
    );
    if (index < 0) {
      return;
    }
    final List<PostItem> posts = List<PostItem>.from(state.posts);
    posts[index] = updated;
    state = state.copyWith(
      // Keep the current visual order stable for optimistic updates such as
      // like/favorite toggles. We only recompute sort order on explicit loads.
      posts: posts,
      clearError: true,
    );
  }
}

final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>(
  (Ref ref) => FeedController(ref),
);
