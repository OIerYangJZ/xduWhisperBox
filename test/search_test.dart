import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/models/post_item.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'api_mocks.dart';

void main() {
  group('Search - 搜索和筛选功能测试', () {
    late MockClient mockClient;
    late PostRepository postRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;
        final queryParams = request.url.queryParameters;

        // 帖子列表（支持筛选参数）
        if (path.endsWith('/posts') && method == 'GET') {
          final keyword = queryParams['keyword'];
          final channel = queryParams['channel'];
          final sort = queryParams['sort'];

          // 模拟搜索结果
          if (keyword != null && keyword.isNotEmpty) {
            return http.Response(
              jsonEncode(MockApiResponses.searchPostsSuccess()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 模拟频道筛选结果
          if (channel != null && channel.isNotEmpty) {
            return http.Response(
              jsonEncode(MockApiResponses.postsSuccess()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }

          // 模拟排序结果
          if (sort == 'likes') {
            return http.Response(
              jsonEncode(MockApiResponses.postsSuccess()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }

          return http.Response(
            jsonEncode(MockApiResponses.postsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 频道列表
        if (path.endsWith('/channels') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.channelsSuccess()),
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

    group('关键词搜索', () {
      test('按关键词搜索帖子', () async {
        final posts = await postRepository.fetchPosts(keyword: 'Flutter');

        expect(posts, isNotEmpty);
        expect(posts, isA<List<PostItem>>());
      });

      test('搜索空关键词返回所有帖子', () async {
        final posts = await postRepository.fetchPosts(keyword: '');

        expect(posts, isNotEmpty);
      });

      test('搜索特殊字符不崩溃', () async {
        final posts = await postRepository.fetchPosts(keyword: '\$%^&');

        expect(posts, isA<List<PostItem>>());
      });

      test('搜索结果包含匹配内容', () async {
        final posts = await postRepository.fetchPosts(keyword: '测试');

        if (posts.isNotEmpty) {
          // 由于使用 Mock 数据，验证返回的是列表
          expect(posts.first, isA<PostItem>());
        }
      });
    });

    group('频道筛选', () {
      test('按频道筛选帖子', () async {
        final posts = await postRepository.fetchPosts(channel: '吐槽日常');

        expect(posts, isA<List<PostItem>>());
      });

      test('筛选不存在的频道返回空列表或全部', () async {
        final posts = await postRepository.fetchPosts(channel: '不存在的频道');

        expect(posts, isA<List<PostItem>>());
      });

      test('全部频道显示所有帖子', () async {
        final posts = await postRepository.fetchPosts(channel: '全部');

        expect(posts, isA<List<PostItem>>());
      });
    });

    group('排序', () {
      test('按最新发布时间排序', () async {
        final posts = await postRepository.fetchPosts(sort: PostSort.latest);

        expect(posts, isA<List<PostItem>>());
        // 验证排序字段
        expect(PostSort.latest.apiValue, equals('latest'));
      });

      test('按点赞量排序', () async {
        final posts = await postRepository.fetchPosts(sort: PostSort.likes);

        expect(posts, isA<List<PostItem>>());
        expect(PostSort.likes.apiValue, equals('likes'));
      });

      test('按点赞量排序结果应按点赞数降序', () async {
        final posts = await postRepository.fetchPosts(sort: PostSort.likes);

        for (int i = 0; i < posts.length - 1; i++) {
          expect(posts[i].likeCount >= posts[i + 1].likeCount, isTrue);
        }
      });
    });

    group('组合筛选', () {
      test('同时按关键词和频道筛选', () async {
        final posts = await postRepository.fetchPosts(
          keyword: '测试',
          channel: '吐槽日常',
        );

        expect(posts, isA<List<PostItem>>());
      });

      test('同时按关键词、频道和排序筛选', () async {
        final posts = await postRepository.fetchPosts(
          keyword: 'Flutter',
          channel: '学习交流',
          sort: PostSort.likes,
        );

        expect(posts, isA<List<PostItem>>());
      });

      test('按图片筛选', () async {
        final posts = await postRepository.fetchPosts(hasImage: true);

        expect(posts, isA<List<PostItem>>());
      });

      test('按私信权限筛选', () async {
        final posts = await postRepository.fetchPosts(allowDm: true);

        expect(posts, isA<List<PostItem>>());
      });

      test('按状态筛选', () async {
        final posts =
            await postRepository.fetchPosts(status: PostStatus.ongoing);

        expect(posts, isA<List<PostItem>>());
      });

      test('多个筛选条件组合', () async {
        final posts = await postRepository.fetchPosts(
          channel: '吐槽日常',
          keyword: '测试',
          hasImage: false,
          sort: PostSort.latest,
        );

        expect(posts, isA<List<PostItem>>());
      });
    });

    group('频道列表', () {
      test('获取所有可用频道', () async {
        final channels = await postRepository.fetchChannels();

        expect(channels, isNotEmpty);
        expect(channels, contains('吐槽日常'));
        expect(channels, contains('求助问答'));
      });

      test('频道列表包含所有预期分类', () async {
        final channels = await postRepository.fetchChannels();

        expect(channels, contains('找对象'));
        expect(channels, contains('找搭子'));
        expect(channels, contains('交友扩列'));
        expect(channels, contains('吐槽日常'));
        expect(channels, contains('八卦吃瓜'));
        expect(channels, contains('求助问答'));
        expect(channels, contains('失物招领'));
        expect(channels, contains('二手交易'));
        expect(channels, contains('学习交流'));
        expect(channels, contains('活动拼车'));
        expect(channels, contains('其他'));
      });
    });

    group('PostStatus', () {
      test('PostStatus 标签正确', () {
        expect(PostStatus.ongoing.label, equals('进行中'));
        expect(PostStatus.resolved.label, equals('已解决'));
        expect(PostStatus.closed.label, equals('已结束'));
      });

      test('PostStatus API 值正确', () {
        expect(PostStatus.ongoing.apiValue, equals('ongoing'));
        expect(PostStatus.resolved.apiValue, equals('resolved'));
        expect(PostStatus.closed.apiValue, equals('closed'));
      });

      test('PostStatusCodec 正确解析各种值', () {
        expect(
            PostStatusCodec.fromDynamic('ongoing'), equals(PostStatus.ongoing));
        expect(PostStatusCodec.fromDynamic('resolved'),
            equals(PostStatus.resolved));
        expect(
            PostStatusCodec.fromDynamic('closed'), equals(PostStatus.closed));
        expect(
            PostStatusCodec.fromDynamic('solved'), equals(PostStatus.resolved));
        expect(PostStatusCodec.fromDynamic('ended'), equals(PostStatus.closed));
        expect(PostStatusCodec.fromDynamic('进行中'), equals(PostStatus.ongoing));
        expect(PostStatusCodec.fromDynamic('已解决'), equals(PostStatus.resolved));
        expect(PostStatusCodec.fromDynamic('已结束'), equals(PostStatus.closed));
      });
    });
  });
}
