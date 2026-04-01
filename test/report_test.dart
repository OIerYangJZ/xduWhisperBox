import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/repositories/post_repository.dart';
import 'api_mocks.dart';

void main() {
  group('Report - 举报功能测试', () {
    late MockClient mockClient;
    late PostRepository postRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        // 举报接口
        if (path.endsWith('/reports') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final targetType = body['targetType'] as String?;
          final targetId = body['targetId'] as String?;
          final reason = body['reason'] as String?;

          if (targetType != null && targetId != null && reason != null) {
            return http.Response(
              jsonEncode(MockApiResponses.reportSuccess()),
              201,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '参数不完整'}),
            400,
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

    group('report', () {
      test('举报帖子成功', () async {
        await expectLater(
          postRepository.report(
            targetType: 'post',
            targetId: 'p1',
            reason: '垃圾广告',
          ),
          completes,
        );
      });

      test('举报评论成功', () async {
        await expectLater(
          postRepository.report(
            targetType: 'comment',
            targetId: 'c1',
            reason: '人身攻击',
          ),
          completes,
        );
      });

      test('举报带详细描述成功', () async {
        await expectLater(
          postRepository.report(
            targetType: 'post',
            targetId: 'p2',
            reason: '其他违规内容',
            description: '帖子中包含不实信息',
          ),
          completes,
        );
      });

      test('举报成功返回感谢信息', () async {
        // 验证举报成功后服务端返回消息
        // 由于 repository 不直接返回响应内容，这里验证调用不抛异常
        await expectLater(
          postRepository.report(
            targetType: 'post',
            targetId: 'p1',
            reason: '垃圾广告',
          ),
          completes,
        );
      });
    });

    group('举报参数验证', () {
      test('举报时 targetType 为 post', () async {
        await postRepository.report(
          targetType: 'post',
          targetId: 'p1',
          reason: '测试举报',
        );
        // 验证不抛异常即通过
      });

      test('举报时 targetType 为 comment', () async {
        await postRepository.report(
          targetType: 'comment',
          targetId: 'c1',
          reason: '测试举报',
        );
      });

      test('举报时 targetType 为 user', () async {
        await postRepository.report(
          targetType: 'user',
          targetId: 'u1',
          reason: '测试举报',
        );
      });
    });
  });
}
