import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/state/app_providers.dart';
import '../../models/post_item.dart';
import '../../models/public_user_profile.dart';
import '../../repositories/post_repository.dart';

const Object _statusUnchanged = Object();

enum SearchResultTab { posts, users }

class SearchState {
  const SearchState({
    this.channels = const <String>['全部'],
    this.selectedChannel = '全部',
    this.keyword = '',
    this.imageOnly = false,
    this.dmOnly = false,
    this.sort = PostSort.latest,
    this.status,
    this.results = const <PostItem>[],
    this.userResults = const <PublicUserProfile>[],
    this.selectedTab = SearchResultTab.posts,
    this.loading = true,
    this.searching = false,
    this.error,
  });

  final List<String> channels;
  final String selectedChannel;
  final String keyword;
  final bool imageOnly;
  final bool dmOnly;
  final PostSort sort;
  final PostStatus? status;
  final List<PostItem> results;
  final List<PublicUserProfile> userResults;
  final SearchResultTab selectedTab;
  final bool loading;
  final bool searching;
  final String? error;

  SearchState copyWith({
    List<String>? channels,
    String? selectedChannel,
    String? keyword,
    bool? imageOnly,
    bool? dmOnly,
    PostSort? sort,
    Object? status = _statusUnchanged,
    List<PostItem>? results,
    List<PublicUserProfile>? userResults,
    SearchResultTab? selectedTab,
    bool? loading,
    bool? searching,
    String? error,
    bool clearError = false,
  }) {
    return SearchState(
      channels: channels ?? this.channels,
      selectedChannel: selectedChannel ?? this.selectedChannel,
      keyword: keyword ?? this.keyword,
      imageOnly: imageOnly ?? this.imageOnly,
      dmOnly: dmOnly ?? this.dmOnly,
      sort: sort ?? this.sort,
      status: status == _statusUnchanged ? this.status : status as PostStatus?,
      results: results ?? this.results,
      userResults: userResults ?? this.userResults,
      selectedTab: selectedTab ?? this.selectedTab,
      loading: loading ?? this.loading,
      searching: searching ?? this.searching,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class SearchController extends StateNotifier<SearchState> {
  SearchController(this._ref) : super(const SearchState());

  final Ref _ref;
  int _requestSequence = 0;

  Future<void> loadInitial() async {
    state = state.copyWith(loading: true, searching: false, clearError: true);
    final int requestId = ++_requestSequence;
    try {
      final List<String> channels = await _ref
          .read(postRepositoryProvider)
          .fetchChannels();
      if (requestId != _requestSequence) {
        return;
      }
      final List<String> deduplicated = <String>['全部', ...channels.toSet()];
      state = state.copyWith(
        channels: deduplicated,
        selectedChannel: deduplicated.contains(state.selectedChannel)
            ? state.selectedChannel
            : deduplicated.first,
        loading: false,
        clearError: true,
      );
      await search();
    } catch (error) {
      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        loading: false,
        searching: false,
        error: '频道加载失败：$error',
      );
    }
  }

  void setKeyword(String keyword) {
    state = state.copyWith(keyword: keyword);
  }

  Future<void> updateChannel(String value) async {
    state = state.copyWith(selectedChannel: value);
    await search();
  }

  Future<void> updateImageOnly(bool value) async {
    state = state.copyWith(imageOnly: value);
    await search();
  }

  Future<void> updateDmOnly(bool value) async {
    state = state.copyWith(dmOnly: value);
    await search();
  }

  Future<void> updateStatus(PostStatus? value) async {
    state = state.copyWith(status: value);
    await search();
  }

  Future<void> updateSort(PostSort value) async {
    state = state.copyWith(sort: value);
    await search();
  }

  void updateTab(SearchResultTab value) {
    state = state.copyWith(selectedTab: value, clearError: true);
  }

  Future<void> search() async {
    state = state.copyWith(searching: true, clearError: true);
    final int requestId = ++_requestSequence;
    try {
      final String normalizedKeyword = state.keyword.trim();
      final List<dynamic>
      results = await Future.wait<dynamic>(<Future<dynamic>>[
        _ref
            .read(postRepositoryProvider)
            .fetchPosts(
              channel: state.selectedChannel == '全部'
                  ? null
                  : state.selectedChannel,
              keyword: normalizedKeyword.isEmpty ? null : normalizedKeyword,
              hasImage: state.imageOnly ? true : null,
              allowDm: state.dmOnly ? true : null,
              status: state.status,
              sort: state.sort,
            ),
        normalizedKeyword.isEmpty
            ? Future<List<PublicUserProfile>>.value(const <PublicUserProfile>[])
            : _ref.read(userRepositoryProvider).searchUsers(normalizedKeyword),
      ]);

      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        results: results[0] as List<PostItem>,
        userResults: results[1] as List<PublicUserProfile>,
        loading: false,
        searching: false,
        clearError: true,
      );
    } catch (error) {
      if (requestId != _requestSequence) {
        return;
      }
      state = state.copyWith(
        loading: false,
        searching: false,
        error: '搜索失败：$error',
      );
    }
  }

  void replaceResult(PostItem updated) {
    final int index = state.results.indexWhere(
      (PostItem item) => item.id == updated.id,
    );
    if (index < 0) {
      return;
    }
    final List<PostItem> results = List<PostItem>.from(state.results);
    results[index] = updated;
    state = state.copyWith(
      results: sortPostsForView(results, sort: state.sort),
      clearError: true,
    );
  }
}

final searchControllerProvider =
    StateNotifierProvider.autoDispose<SearchController, SearchState>(
      (Ref ref) => SearchController(ref),
    );
