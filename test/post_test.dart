import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'api_mocks.dart';

void main() {
  group('PostRepository', () {
    late MockClient mockClient;
    late PostRepository postRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        // 获取帖子列表
        if (path.endsWith('/posts') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.postsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 获取单个帖子详情
        final postDetailPattern = RegExp(r'/posts/(p\d+|new_post_id)');
        if (postDetailPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.postDetailSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 创建帖子
        if (path.endsWith('/posts') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final title = body['title'] as String?;

          if (title != null && title.isNotEmpty) {
            return http.Response(
              jsonEncode(MockApiResponses.createPostSuccess()),
              201,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '标题不能为空'}),
            400,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 获取评论
        final commentsPattern = RegExp(r'/posts/.+/comments');
        if (commentsPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.commentsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 点赞帖子
        final likePattern = RegExp(r'/posts/.+/like');
        if (likePattern.hasMatch(path) && method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '已点赞'}),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 收藏帖子
        final favoritePattern = RegExp(r'/posts/.+/favorite');
        if (favoritePattern.hasMatch(path) && method == 'POST') {
          return http.Response(
            jsonEncode(MockApiResponses.favoriteSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 获取频道列表
        if (path.endsWith('/channels') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.channelsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 搜索帖子
        if (path.endsWith('/posts/search') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.searchPostsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        return http.Response(
          jsonEncode(MockApiResponses.notFound()),
          404,
          headers: {'Content-Type': 'application/json'},
        );
      });

      postRepository = PostRepository(ApiClient(httpClient: mockClient));
    });

    group('fetchChannels', () {
      test('获取频道列表成功', () async {
        final channels = await postRepository.fetchChannels();

        expect(channels, isNotEmpty);
        expect(channels, contains('吐槽日常'));
        expect(channels, contains('求助问答'));
      });
    });

    group('fetchPosts', () {
      test('获取帖子列表成功', () async {
        final posts = await postRepository.fetchPosts();

        expect(posts, isNotEmpty);
        expect(posts.first, isA<PostItem>());
      });

      test('按频道筛选帖子', () async {
        final posts = await postRepository.fetchPosts(channel: '吐槽日常');

        expect(posts, isA<List<PostItem>>());
      });

      test('按关键词搜索帖子', () async {
        final posts = await postRepository.fetchPosts(keyword: '测试');

        expect(posts, isA<List<PostItem>>());
      });

      test('按点赞量排序', () async {
        final posts = await postRepository.fetchPosts(sort: PostSort.likes);

        expect(posts, isA<List<PostItem>>());
      });
    });

    group('fetchPostDetail', () {
      test('获取帖子详情成功', () async {
        final post = await postRepository.fetchPostDetail('p1');

        expect(post.id, equals('p1'));
        expect(post.title, isNotEmpty);
        expect(post.content, isNotEmpty);
      });
    });

    group('createPost', () {
      test('创建帖子成功', () async {
        final input = CreatePostInput(
          title: '新帖子标题',
          content: '新帖子内容',
          channel: '吐槽日常',
          tags: <String>['测试'],
          allowComment: true,
          allowDm: false,
          privateOnly: false,
          status: PostStatus.ongoing,
          hasImage: false,
        );

        final post = await postRepository.createPost(input);

        expect(post.title, equals('新帖子标题'));
        expect(post.content, equals('新帖子内容'));
      });

      test('创建帖子时 hasImage 由 imageUploadIds 决定', () async {
        final inputWithImages = CreatePostInput(
          title: '带图帖子',
          content: '内容',
          channel: '吐槽日常',
          tags: <String>[],
          allowComment: true,
          allowDm: false,
          privateOnly: false,
          status: PostStatus.ongoing,
          hasImage: false,
          imageUploadIds: <String>['img1', 'img2'],
        );

        expect(inputWithImages.toJson()['hasImage'], isTrue);
        expect(inputWithImages.toJson()['imageUploadIds'], hasLength(2));
      });

      test('CreatePostInput.toJson 正确序列化', () {
        final input = CreatePostInput(
          title: '测试标题',
          content: '测试内容',
          channel: '吐槽日常',
          tags: <String>['标签1', '标签2'],
          allowComment: true,
          allowDm: true,
          privateOnly: false,
          status: PostStatus.resolved,
          hasImage: true,
          useAnonymousAlias: true,
          anonymousAlias: '匿名用户',
        );

        final json = input.toJson();

        expect(json['title'], equals('测试标题'));
        expect(json['content'], equals('测试内容'));
        expect(json['channel'], equals('吐槽日常'));
        expect(json['tags'], equals(<String>['标签1', '标签2']));
        expect(json['allowComment'], isTrue);
        expect(json['allowDm'], isTrue);
        expect(json['status'], equals('resolved'));
        expect(json['hasImage'], isTrue);
        expect(json['useAnonymousAlias'], isTrue);
        expect(json['anonymousAlias'], equals('匿名用户'));
      });
    });

    group('fetchComments', () {
      test('获取评论列表成功', () async {
        final comments = await postRepository.fetchComments('p1');

        expect(comments, isNotEmpty);
        expect(comments.first.content, isNotEmpty);
      });
    });

    group('createComment', () {
      test('创建评论成功不抛出异常', () async {
        await expectLater(
          postRepository.createComment(
            postId: 'p1',
            content: '这是一条测试评论',
          ),
          completes,
        );
      });

      test('创建带父评论的回复成功', () async {
        await expectLater(
          postRepository.createComment(
            postId: 'p1',
            content: '这是回复',
            parentId: 'c1',
          ),
          completes,
        );
      });
    });

    group('likePost', () {
      test('点赞帖子成功', () async {
        await expectLater(
          postRepository.likePost('p1'),
          completes,
        );
      });
    });

    group('favoritePost', () {
      test('收藏帖子成功返回结果', () async {
        final result = await postRepository.favoritePost('p1');

        expect(result.favorited, isTrue);
        expect(result.favoriteCount, equals(4));
      });
    });

    group('report', () {
      test('举报帖子成功', () async {
        await expectLater(
          postRepository.report(
            targetType: 'post',
            targetId: 'p1',
            reason: '垃圾广告',
            description: '包含营销信息',
          ),
          completes,
        );
      });
    });

    group('PostItem', () {
      test('fromJson 正确解析 JSON', () {
        final json = <String, dynamic>{
          'id': 'test_post',
          'title': '测试标题',
          'content': '测试内容',
          'channel': '吐槽日常',
          'tags': <String>['Flutter', '测试'],
          'authorAlias': '测试用户',
          'createdAt': '2024-01-15T10:30:00Z',
          'hasImage': true,
          'commentCount': 10,
          'likeCount': 25,
          'favoriteCount': 5,
          'status': 'ongoing',
          'allowComment': true,
          'allowDm': false,
        };

        final post = PostItem.fromJson(json);

        expect(post.id, equals('test_post'));
        expect(post.title, equals('测试标题'));
        expect(post.content, equals('测试内容'));
        expect(post.channel, equals('吐槽日常'));
        expect(post.tags, equals(<String>['Flutter', '测试']));
        expect(post.authorAlias, equals('测试用户'));
        expect(post.hasImage, isTrue);
        expect(post.commentCount, equals(10));
        expect(post.likeCount, equals(25));
        expect(post.favoriteCount, equals(5));
        expect(post.status, equals(PostStatus.ongoing));
        expect(post.allowComment, isTrue);
        expect(post.allowDm, isFalse);
      });

      test('fromJson 处理不同状态值', () {
        expect(
            PostStatusCodec.fromDynamic('ongoing'), equals(PostStatus.ongoing));
        expect(PostStatusCodec.fromDynamic('resolved'),
            equals(PostStatus.resolved));
        expect(
            PostStatusCodec.fromDynamic('closed'), equals(PostStatus.closed));
        expect(
            PostStatusCodec.fromDynamic('solved'), equals(PostStatus.resolved));
        expect(
            PostStatusCodec.fromDynamic('unknown'), equals(PostStatus.ongoing));
      });

      test('fromJson 处理空数据', () {
        final post = PostItem.fromJson(<String, dynamic>{});

        expect(post.id, isEmpty);
        expect(post.title, isEmpty);
        expect(post.status, equals(PostStatus.ongoing));
      });

      test('copyWith 创建新实例保留原值', () {
        final original = PostItem(
          id: 'p1',
          title: '原始标题',
          content: '原始内容',
          channel: '吐槽日常',
          tags: <String>['标签'],
          authorAlias: '作者',
          createdAt: DateTime(2024, 1, 1),
          hasImage: false,
          commentCount: 5,
          likeCount: 10,
          favoriteCount: 2,
          status: PostStatus.ongoing,
          allowComment: true,
          allowDm: false,
        );

        final modified = original.copyWith(
          title: '修改后的标题',
          likeCount: 15,
        );

        expect(modified.id, equals('p1'));
        expect(modified.title, equals('修改后的标题'));
        expect(modified.likeCount, equals(15));
        expect(modified.content, equals('原始内容'));
        expect(modified.commentCount, equals(5));
      });

      test('toCreateJson 生成创建帖子所需的 JSON', () {
        final post = PostItem(
          id: 'p1',
          title: '标题',
          content: '内容',
          channel: '吐槽日常',
          tags: <String>[],
          authorAlias: '作者',
          createdAt: DateTime.now(),
          hasImage: true,
          commentCount: 0,
          likeCount: 0,
          favoriteCount: 0,
          status: PostStatus.ongoing,
          allowComment: true,
          allowDm: true,
        );

        final json = post.toCreateJson();

        expect(json['title'], equals('标题'));
        expect(json['content'], equals('内容'));
        expect(json['channel'], equals('吐槽日常'));
        expect(json['status'], equals('ongoing'));
        expect(json['allowComment'], isTrue);
        expect(json['allowDm'], isTrue);
        expect(json['hasImage'], isTrue);
      });
    });

    group('PostSort', () {
      test('PostSort 枚举的 apiValue 正确', () {
        expect(PostSort.latest.apiValue, equals('latest'));
        expect(PostSort.likes.apiValue, equals('likes'));
      });

      test('PostSort 枚举的 label 正确', () {
        expect(PostSort.latest.label, equals('按发布时间'));
        expect(PostSort.likes.label, equals('按点赞量'));
      });
    });
  });
}
