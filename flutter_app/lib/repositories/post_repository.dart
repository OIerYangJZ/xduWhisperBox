import 'dart:math' as math;

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';
import '../core/utils/markdown_utils.dart';
import '../models/comment_item.dart';
import '../models/post_item.dart';
import '../models/uploaded_image_item.dart';

enum PostSort { latest, hot, likes }

enum CommentSort { latest, hot }

const List<String> _defaultChannels = <String>[
  '综合',
  '找对象',
  '找搭子',
  '交友扩列',
  '吐槽日常',
  '八卦吃瓜',
  '求助问答',
  '失物招领',
  '二手交易',
  '学习交流',
  '活动拼车',
  '其他',
];

extension PostSortCodec on PostSort {
  String get apiValue {
    switch (this) {
      case PostSort.latest:
        return 'latest';
      case PostSort.hot:
        return 'hot';
      case PostSort.likes:
        return 'likes';
    }
  }

  String get label {
    switch (this) {
      case PostSort.latest:
        return '按发布时间';
      case PostSort.hot:
        return '热度排序';
      case PostSort.likes:
        return '按点赞量';
    }
  }
}

extension CommentSortCodec on CommentSort {
  String get apiValue {
    switch (this) {
      case CommentSort.latest:
        return 'latest';
      case CommentSort.hot:
        return 'hot';
    }
  }
}

List<PostItem> sortPostsForView(
  Iterable<PostItem> posts, {
  PostSort sort = PostSort.latest,
  DateTime? now,
}) {
  final DateTime anchor = now ?? DateTime.now();
  final List<PostItem> activePinned = <PostItem>[];
  final List<PostItem> normalPosts = <PostItem>[];

  for (final PostItem post in posts) {
    if (_isActivePinned(post, anchor)) {
      activePinned.add(post);
    } else {
      normalPosts.add(post);
    }
  }

  activePinned.sort((PostItem a, PostItem b) {
    final int byPinStart = _safeDate(
      b.pinStartedAt ?? b.createdAt,
    ).compareTo(_safeDate(a.pinStartedAt ?? a.createdAt));
    if (byPinStart != 0) {
      return byPinStart;
    }
    return _compareByLatest(a, b);
  });

  switch (sort) {
    case PostSort.hot:
      normalPosts.sort((PostItem a, PostItem b) {
        final int byHot = _hotScore(b, anchor).compareTo(_hotScore(a, anchor));
        if (byHot != 0) {
          return byHot;
        }
        final int byEngagement = _engagementScore(
          b,
        ).compareTo(_engagementScore(a));
        if (byEngagement != 0) {
          return byEngagement;
        }
        return _compareByLatest(a, b);
      });
      break;
    case PostSort.likes:
      normalPosts.sort((PostItem a, PostItem b) {
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        return _compareByLatest(a, b);
      });
      break;
    case PostSort.latest:
      normalPosts.sort(_compareByLatest);
      break;
  }

  return <PostItem>[...activePinned, ...normalPosts];
}

bool _isActivePinned(PostItem post, DateTime now) {
  if (!post.isPinned) {
    return false;
  }
  if (post.pinStartedAt != null && post.pinStartedAt!.isAfter(now)) {
    return false;
  }
  if (post.pinExpiresAt != null && !post.pinExpiresAt!.isAfter(now)) {
    return false;
  }
  return true;
}

int _compareByLatest(PostItem a, PostItem b) {
  final int byCreated = b.createdAt.compareTo(a.createdAt);
  if (byCreated != 0) {
    return byCreated;
  }
  return b.id.compareTo(a.id);
}

int _engagementScore(PostItem post) {
  final int cappedViews = math.min(post.viewCount, 500);
  return (post.likeCount * 3) +
      (post.commentCount * 5) +
      (post.favoriteCount * 2) +
      cappedViews;
}

double _hotScore(PostItem post, DateTime now) {
  final double ageHours = math.max(
    1,
    now.difference(post.createdAt).inMinutes.abs() / 60.0,
  );
  final double engagement = _engagementScore(post).toDouble();
  final double decay = math.pow(ageHours + 2, 0.85).toDouble();
  final double recencyTieBreaker =
      post.createdAt.millisecondsSinceEpoch / 1000000000000000.0;
  return (engagement / decay) + recencyTieBreaker;
}

DateTime _safeDate(DateTime value) => value.toUtc();

List<CommentItem> sortCommentsForView(
  Iterable<CommentItem> comments, {
  CommentSort sort = CommentSort.latest,
}) {
  final List<CommentItem> rows = comments.toList();
  switch (sort) {
    case CommentSort.hot:
      rows.sort((CommentItem a, CommentItem b) {
        final int byLikes = b.likeCount.compareTo(a.likeCount);
        if (byLikes != 0) {
          return byLikes;
        }
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      });
      break;
    case CommentSort.latest:
      rows.sort((CommentItem a, CommentItem b) {
        final int byCreated = b.createdAt.compareTo(a.createdAt);
        if (byCreated != 0) {
          return byCreated;
        }
        return b.id.compareTo(a.id);
      });
      break;
  }
  return rows;
}

class CreatePostInput {
  CreatePostInput({
    required this.title,
    required this.content,
    this.contentFormat = 'plain',
    this.markdownSource,
    required this.channel,
    required this.tags,
    required this.allowComment,
    required this.allowDm,
    required this.privateOnly,
    required this.status,
    required this.hasImage,
    this.pinDurationMinutes,
    this.imageUploadIds = const <String>[],
    this.useAnonymousAlias = false,
    this.anonymousAlias,
  });

  final String title;
  final String content;
  final String contentFormat;
  final String? markdownSource;
  final String channel;
  final List<String> tags;
  final bool allowComment;
  final bool allowDm;
  final bool privateOnly;
  final PostStatus status;
  final bool hasImage;
  final int? pinDurationMinutes;
  final List<String> imageUploadIds;
  final bool useAnonymousAlias;
  final String? anonymousAlias;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'content': content,
      'contentFormat': contentFormat.trim().toLowerCase() == 'markdown'
          ? 'markdown'
          : 'plain',
      if ((markdownSource ?? '').trim().isNotEmpty)
        'markdownSource': markdownSource!.trim(),
      'channel': channel,
      'tags': tags,
      'allowComment': allowComment,
      'allowDm': allowDm,
      'visibility': privateOnly ? 'private' : 'public',
      'status': status.apiValue,
      'hasImage': hasImage || imageUploadIds.isNotEmpty,
      if (pinDurationMinutes != null && pinDurationMinutes! > 0)
        'pinDurationMinutes': pinDurationMinutes,
      'imageUploadIds': imageUploadIds,
      'useAnonymousAlias': useAnonymousAlias,
      if (anonymousAlias != null && anonymousAlias!.trim().isNotEmpty)
        'anonymousAlias': anonymousAlias!.trim(),
    };
  }
}

class FavoriteActionResult {
  FavoriteActionResult({required this.favorited, this.favoriteCount});

  final bool favorited;
  final int? favoriteCount;
}

class PinPostActionResult {
  PinPostActionResult({required this.mode, this.post});

  final String mode;
  final PostItem? post;

  bool get isDirect => mode == 'direct';
}

class PostRepository {
  PostRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<List<String>> fetchChannels() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.channels);
      final List<dynamic> list = extractList(response);
      final List<String> channels = list
          .map((dynamic item) {
            if (item is String) {
              return item.trim();
            }
            final Map<String, dynamic> map = asMap(item);
            return readString(map, <String>['name', 'title', 'channelName']) ??
                '';
          })
          .where((String name) => name.isNotEmpty)
          .toSet()
          .toList();

      if (channels.isNotEmpty) {
        return channels;
      }
    } catch (_) {
      // ignore and fallback
    }

    return _defaultChannels;
  }

  Future<List<PostItem>> fetchPosts({
    String? channel,
    String? keyword,
    bool? hasImage,
    bool? allowDm,
    PostStatus? status,
    PostSort sort = PostSort.latest,
  }) async {
    final Map<String, dynamic> query = <String, dynamic>{
      if (channel != null && channel != '全部') 'channel': channel,
      if (keyword != null && keyword.trim().isNotEmpty)
        'keyword': keyword.trim(),
      if (hasImage != null) 'hasImage': hasImage,
      if (allowDm != null) 'allowDm': allowDm,
      if (status != null) 'status': status.apiValue,
      'sort': sort.apiValue,
    };

    try {
      final dynamic response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: query,
      );
      final List<dynamic> list = extractList(response);
      final List<PostItem> posts = list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
      if (posts.isNotEmpty || !AppConfig.enableMockFallback) {
        return sortPostsForView(posts, sort: sort);
      }
    } catch (_) {
      return <PostItem>[];
    }

    return <PostItem>[];
  }

  Future<PostItem> fetchPostDetail(String postId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.postById(postId),
    );
    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return PostItem.fromJson(map);
    }
    throw Exception('帖子详情加载失败：服务端未返回有效数据');
  }

  Future<PostItem> createPost(CreatePostInput input) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.posts,
      body: input.toJson(),
    );

    final Map<String, dynamic> map = extractMap(response);
    if (map.isNotEmpty) {
      return PostItem.fromJson(map);
    }

    return PostItem(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      title: input.title,
      content: input.contentFormat.trim().toLowerCase() == 'markdown'
          ? (markdownToPlainText(
                  input.markdownSource ?? input.content,
                ).trim().isEmpty
                ? input.content
                : markdownToPlainText(input.markdownSource ?? input.content))
          : input.content,
      contentFormat: input.contentFormat,
      markdownSource: input.markdownSource ?? '',
      channel: input.channel,
      tags: input.tags,
      authorAlias: input.useAnonymousAlias
          ? ((input.anonymousAlias ?? '').trim().isNotEmpty
                ? input.anonymousAlias!.trim()
                : '匿名同学')
          : '我的昵称',
      isAnonymous: input.useAnonymousAlias,
      createdAt: DateTime.now(),
      hasImage: input.hasImage || input.imageUploadIds.isNotEmpty,
      commentCount: 0,
      likeCount: 0,
      favoriteCount: 0,
      status: input.status,
      allowComment: input.allowComment,
      allowDm: input.useAnonymousAlias ? false : input.allowDm,
      isPrivate: input.privateOnly,
      isPinned: (input.pinDurationMinutes ?? 0) > 0,
      pinDurationMinutes: input.pinDurationMinutes ?? 0,
    );
  }

  Future<UploadedImageItem> uploadImage({
    required String fileName,
    required String contentType,
    required String dataBase64,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.uploadImages,
      body: <String, dynamic>{
        'fileName': fileName,
        'contentType': contentType,
        'dataBase64': dataBase64,
      },
    );
    final Map<String, dynamic> data = extractMap(response);
    if (data.isNotEmpty) {
      return UploadedImageItem.fromJson(data);
    }
    throw Exception('图片上传失败：服务端未返回有效数据');
  }

  Future<List<UploadedImageItem>> fetchMyUploads() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.myUploads);
    final List<dynamic> rows = extractList(response);
    return rows
        .map((dynamic item) => UploadedImageItem.fromJson(asMap(item)))
        .where((UploadedImageItem item) => item.id.isNotEmpty)
        .toList();
  }

  Future<List<CommentItem>> fetchComments(
    String postId, {
    CommentSort sort = CommentSort.latest,
  }) async {
    try {
      final dynamic response = await _apiClient.get(
        ApiEndpoints.postComments(postId),
        queryParameters: <String, dynamic>{'sort': sort.apiValue},
      );
      final List<dynamic> list = extractList(response);
      final List<CommentItem> comments = <CommentItem>[];
      for (final dynamic item in list) {
        final Map<String, dynamic> row = asMap(item);
        if (row.isEmpty) {
          continue;
        }
        try {
          final CommentItem comment = CommentItem.fromJson(row);
          if (comment.id.isEmpty || comment.content.isEmpty) {
            continue;
          }
          comments.add(comment);
        } catch (_) {
          continue;
        }
      }
      if (comments.isNotEmpty || !AppConfig.enableMockFallback) {
        return sortCommentsForView(comments, sort: sort);
      }
    } catch (_) {
      return <CommentItem>[];
    }

    return <CommentItem>[];
  }

  Future<void> createComment({
    required String postId,
    required String content,
    String? parentId,
  }) async {
    await _apiClient.post(
      ApiEndpoints.postComments(postId),
      body: <String, dynamic>{
        'content': content,
        if (parentId != null) 'parentId': parentId,
      },
    );
  }

  Future<void> likePost(String postId) {
    return _apiClient.post(
      ApiEndpoints.postLike(postId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unlikePost(String postId) {
    return _apiClient.post(
      ApiEndpoints.postLike(postId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> likeComment(String commentId) {
    return _apiClient.post(
      ApiEndpoints.commentLike(commentId),
      body: const <String, dynamic>{},
    );
  }

  Future<void> unlikeComment(String commentId) {
    return _apiClient.delete(
      ApiEndpoints.commentLike(commentId),
      body: const <String, dynamic>{},
    );
  }

  Future<FavoriteActionResult> favoritePost(String postId) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postFavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response, fallbackFavorited: true);
  }

  Future<FavoriteActionResult> unfavoritePost(String postId) async {
    final dynamic response = await _apiClient.delete(
      ApiEndpoints.postUnfavorite(postId),
      body: const <String, dynamic>{},
    );
    return _parseFavoriteActionResult(response, fallbackFavorited: false);
  }

  Future<void> report({
    required String targetType,
    required String targetId,
    required String reason,
    String? description,
  }) {
    return _apiClient.post(
      ApiEndpoints.reports,
      body: <String, dynamic>{
        'targetType': targetType,
        'targetId': targetId,
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
    );
  }

  Future<List<PostItem>> fetchFavoritePosts() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.favoritePosts);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
    } catch (_) {
      return const <PostItem>[];
    }
  }

  Future<List<PostItem>> fetchUserPosts(String userId) async {
    try {
      final Map<String, dynamic> query = {'authorId': userId};
      final dynamic response = await _apiClient.get(
        ApiEndpoints.posts,
        queryParameters: query,
      );
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const <PostItem>[];
    }
  }

  Future<List<PostItem>> fetchMyPosts() async {
    try {
      final dynamic response = await _apiClient.get(ApiEndpoints.myPosts);
      final List<dynamic> list = extractList(response);
      return list
          .map((dynamic item) => PostItem.fromJson(asMap(item)))
          .where((PostItem post) => post.id.isNotEmpty || post.title.isNotEmpty)
          .toList();
    } catch (_) {
      return const <PostItem>[];
    }
  }

  Future<void> updateMyPostStatus({
    required String postId,
    required PostStatus status,
  }) {
    return _apiClient.patch(
      ApiEndpoints.postById(postId),
      body: <String, dynamic>{'status': status.apiValue},
    );
  }

  Future<void> deleteMyPost(String postId) {
    return _apiClient.delete(ApiEndpoints.postById(postId));
  }

  Future<int?> incrementView(String postId) async {
    try {
      final dynamic response = await _apiClient.post(
        ApiEndpoints.postView(postId),
        body: const <String, dynamic>{},
      );
      final Map<String, dynamic> map = extractMap(response);
      return readInt(map, <String>['viewCount']);
    } catch (_) {
      // 阅读量计数失败不影响主流程，静默忽略
      return null;
    }
  }

  Future<PinPostActionResult> submitPinRequest({
    required String postId,
    required int durationMinutes,
    String? reason,
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.postPinRequest(postId),
      body: <String, dynamic>{
        'durationMinutes': durationMinutes,
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final Map<String, dynamic> map = extractMap(response);
    final String mode = (readString(map, <String>['mode']) ?? 'pending').trim();
    final Map<String, dynamic> postMap = asMap(map['post']);
    return PinPostActionResult(
      mode: mode.isEmpty ? 'pending' : mode,
      post: postMap.isEmpty ? null : PostItem.fromJson(postMap),
    );
  }

  FavoriteActionResult _parseFavoriteActionResult(
    dynamic response, {
    required bool fallbackFavorited,
  }) {
    final Map<String, dynamic> map = extractMap(response);
    if (map.isEmpty) {
      return FavoriteActionResult(favorited: fallbackFavorited);
    }
    return FavoriteActionResult(
      favorited:
          readBool(map, <String>['favorited', 'isFavorited']) ??
          fallbackFavorited,
      favoriteCount: readInt(map, <String>['favoriteCount', 'collectCount']),
    );
  }
}
