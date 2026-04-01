import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/models/dm_request_item.dart';
import 'package:xdu_treehole_web/models/conversation_item.dart';
import 'package:xdu_treehole_web/models/direct_message_item.dart';
import 'package:xdu_treehole_web/repositories/message_repository.dart';
import 'api_mocks.dart';

void main() {
  group('MessageRepository', () {
    late MockClient mockClient;
    late MessageRepository messageRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        // 获取私信请求列表
        if (path.endsWith('/messages/requests') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.dmRequestsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 处理私信请求（接受/拒绝）
        final dmRequestActionPattern =
            RegExp(r'/messages/requests/.+/(accept|reject)');
        if (dmRequestActionPattern.hasMatch(path) && method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '处理成功'}),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 创建私信请求
        if (path.endsWith('/messages/requests') && method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '请求已发送'}),
            201,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 获取会话列表
        if (path.endsWith('/messages/conversations') && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.conversationsSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 获取会话消息
        final messagesPattern = RegExp(r'/messages/conversations/.+/messages');
        if (messagesPattern.hasMatch(path) && method == 'GET') {
          return http.Response(
            jsonEncode(MockApiResponses.messagesSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 发送消息
        if (messagesPattern.hasMatch(path) && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode(<String, dynamic>{
              'id': 'new_msg_${DateTime.now().millisecondsSinceEpoch}',
              'content': body['content'] ?? '',
              'createdAt': DateTime.now().toIso8601String(),
              'timeText': '刚刚',
              'fromMe': true,
              'senderAlias': '我',
            }),
            201,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 删除会话
        final deleteConversationPattern =
            RegExp(r'/messages/conversations/[^/]+$');
        if (deleteConversationPattern.hasMatch(path) && method == 'DELETE') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '会话已删除'}),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        // 拉黑/取消拉黑
        final blockPattern = RegExp(r'/messages/conversations/.+/block');
        final unblockPattern = RegExp(r'/messages/conversations/.+/unblock');
        if ((blockPattern.hasMatch(path) || unblockPattern.hasMatch(path)) &&
            method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'message': '操作成功',
              'blockedByMe': path.contains('/block'),
            }),
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

      messageRepository = MessageRepository(ApiClient(httpClient: mockClient));
    });

    group('fetchDmRequests', () {
      test('获取私信请求列表成功', () async {
        final requests = await messageRepository.fetchDmRequests();

        expect(requests, isNotEmpty);
        expect(requests.first, isA<DmRequestItem>());
        expect(requests.first.fromAlias, equals('同学-海盐'));
      });

      test('返回的请求包含必要字段', () async {
        final requests = await messageRepository.fetchDmRequests();
        final first = requests.first;

        expect(first.id, isNotEmpty);
        expect(first.fromAlias, isNotEmpty);
        expect(first.reason, isNotEmpty);
        expect(first.status, isNotEmpty);
      });
    });

    group('handleDmRequest', () {
      test('接受私信请求成功', () async {
        await expectLater(
          messageRepository.handleDmRequest(
            requestId: 'req1',
            accept: true,
          ),
          completes,
        );
      });

      test('拒绝私信请求成功', () async {
        await expectLater(
          messageRepository.handleDmRequest(
            requestId: 'req1',
            accept: false,
          ),
          completes,
        );
      });
    });

    group('createDmRequest', () {
      test('创建私信请求成功', () async {
        await expectLater(
          messageRepository.createDmRequest(
            postId: 'p1',
            reason: '想咨询问题',
          ),
          completes,
        );
      });

      test('无理由创建私信请求成功', () async {
        await expectLater(
          messageRepository.createDmRequest(
            postId: 'p1',
          ),
          completes,
        );
      });
    });

    group('fetchConversations', () {
      test('获取会话列表成功', () async {
        final conversations = await messageRepository.fetchConversations();

        expect(conversations, isNotEmpty);
        expect(conversations.first, isA<ConversationItem>());
        expect(conversations.first.name, equals('同学-海盐'));
      });

      test('返回的会话包含必要字段', () async {
        final conversations = await messageRepository.fetchConversations();
        final first = conversations.first;

        expect(first.id, isNotEmpty);
        expect(first.name, isNotEmpty);
        expect(first.lastMessage, isNotEmpty);
      });
    });

    group('fetchConversationMessages', () {
      test('获取会话消息列表成功', () async {
        final messages =
            await messageRepository.fetchConversationMessages('conv1');

        expect(messages, isNotEmpty);
        expect(messages.first, isA<DirectMessageItem>());
        expect(messages.first.content, isNotEmpty);
      });
    });

    group('sendConversationMessage', () {
      test('发送消息成功返回消息对象', () async {
        final message = await messageRepository.sendConversationMessage(
          conversationId: 'conv1',
          content: '你好，这是测试消息',
        );

        expect(message, isA<DirectMessageItem>());
        expect(message.content, equals('你好，这是测试消息'));
      });
    });

    group('deleteConversation', () {
      test('删除会话成功', () async {
        await expectLater(
          messageRepository.deleteConversation('conv1'),
          completes,
        );
      });
    });

    group('updateConversationBlock', () {
      test('拉黑会话成功', () async {
        final result = await messageRepository.updateConversationBlock(
          conversationId: 'conv1',
          block: true,
        );

        expect(result, isA<ConversationItem>());
      });

      test('取消拉黑成功', () async {
        final result = await messageRepository.updateConversationBlock(
          conversationId: 'conv1',
          block: false,
        );

        expect(result, isA<ConversationItem>());
      });
    });

    group('DmRequestItem', () {
      test('fromJson 正确解析', () {
        final json = <String, dynamic>{
          'id': 'req123',
          'fromAlias': '同学-测试',
          'fromAvatarUrl': 'https://example.com/avatar.png',
          'reason': '想咨询问题',
          'timeText': '5 分钟前',
          'status': 'pending',
          'statusLabel': '待处理',
        };

        final item = DmRequestItem.fromJson(json);

        expect(item.id, equals('req123'));
        expect(item.fromAlias, equals('同学-测试'));
        expect(item.fromAvatarUrl, equals('https://example.com/avatar.png'));
        expect(item.reason, equals('想咨询问题'));
        expect(item.timeText, equals('5 分钟前'));
        expect(item.status, equals('pending'));
        expect(item.statusLabel, equals('待处理'));
      });

      test('fromJson 处理空数据', () {
        final item = DmRequestItem.fromJson(<String, dynamic>{});

        expect(item.id, isEmpty);
        expect(item.fromAlias, equals('匿名同学'));
      });

      test('fromJson 使用备用字段名', () {
        final json = <String, dynamic>{
          'requestId': 'req456',
          'from': '备用名称',
          'message': '备用原因',
        };

        final item = DmRequestItem.fromJson(json);

        expect(item.id, equals('req456'));
        expect(item.fromAlias, equals('备用名称'));
        expect(item.reason, equals('备用原因'));
      });
    });

    group('ConversationItem', () {
      test('fromJson 正确解析', () {
        final json = <String, dynamic>{
          'id': 'conv123',
          'peerUserId': 'user456',
          'name': '同学-对话',
          'avatarUrl': '',
          'lastMessage': '最后一条消息',
          'timeText': '14:30',
        };

        final item = ConversationItem.fromJson(json);

        expect(item.id, equals('conv123'));
        expect(item.peerUserId, equals('user456'));
        expect(item.name, equals('同学-对话'));
        expect(item.lastMessage, equals('最后一条消息'));
        expect(item.timeText, equals('14:30'));
      });

      test('fromJson 处理空数据', () {
        final item = ConversationItem.fromJson(<String, dynamic>{});

        expect(item.id, isEmpty);
        expect(item.name, equals('匿名同学'));
      });

      test('isBlocked 属性正确计算', () {
        final blocked = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv1',
          'blockedByMe': true,
        });
        expect(blocked.isBlocked, isTrue);

        final notBlocked = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv2',
          'blockedByMe': false,
          'blockedByPeer': false,
        });
        expect(notBlocked.isBlocked, isFalse);
      });

      test('copyWith 创建新实例', () {
        final original = ConversationItem.fromJson(<String, dynamic>{
          'id': 'conv1',
          'name': '原名称',
          'lastMessage': '原消息',
        });

        final modified = original.copyWith(name: '新名称');

        expect(modified.id, equals('conv1'));
        expect(modified.name, equals('新名称'));
        expect(modified.lastMessage, equals('原消息'));
      });
    });

    group('DirectMessageItem', () {
      test('fromJson 正确解析', () {
        final json = <String, dynamic>{
          'id': 'msg123',
          'content': '消息内容',
          'createdAt': '2024-01-15T10:30:00Z',
          'timeText': '10:30',
          'fromMe': true,
          'senderAlias': '我',
        };

        final item = DirectMessageItem.fromJson(json);

        expect(item.id, equals('msg123'));
        expect(item.content, equals('消息内容'));
        expect(item.createdAt, equals('2024-01-15T10:30:00Z'));
        expect(item.fromMe, isTrue);
        expect(item.senderAlias, equals('我'));
      });

      test('fromJson 处理空数据', () {
        final item = DirectMessageItem.fromJson(<String, dynamic>{});

        expect(item.id, isEmpty);
        expect(item.content, isEmpty);
        expect(item.fromMe, isFalse);
        expect(item.senderAlias, equals('匿名同学'));
      });

      test('isRead 根据 readAt 判断', () {
        final readMessage = DirectMessageItem.fromJson(<String, dynamic>{
          'id': 'msg1',
          'content': '已读消息',
          'readAt': '2024-01-15T10:35:00Z',
        });
        expect(readMessage.isRead, isTrue);

        final unreadMessage = DirectMessageItem.fromJson(<String, dynamic>{
          'id': 'msg2',
          'content': '未读消息',
        });
        expect(unreadMessage.isRead, isFalse);
      });
    });
  });
}
