import 'dart:convert';

/// Mock HTTP 响应，用于测试时模拟 API 返回。
class MockHttpResponse {
  MockHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final dynamic body;

  String get bodyString {
    if (body is String) {
      return body as String;
    }
    return jsonEncode(body);
  }

  factory MockHttpResponse.success(dynamic data) {
    return MockHttpResponse(
      statusCode: 200,
      body: data,
    );
  }

  factory MockHttpResponse.created(dynamic data) {
    return MockHttpResponse(
      statusCode: 201,
      body: data,
    );
  }

  factory MockHttpResponse.badRequest(String message) {
    return MockHttpResponse(
      statusCode: 400,
      body: <String, dynamic>{'message': message},
    );
  }

  factory MockHttpResponse.unauthorized() {
    return MockHttpResponse(
      statusCode: 401,
      body: <String, dynamic>{'message': '未授权'},
    );
  }

  factory MockHttpResponse.notFound() {
    return MockHttpResponse(
      statusCode: 404,
      body: <String, dynamic>{'message': '资源不存在'},
    );
  }

  factory MockHttpResponse.serverError() {
    return MockHttpResponse(
      statusCode: 500,
      body: <String, dynamic>{'message': '服务器内部错误'},
    );
  }
}

/// Mock API 响应数据工厂。
class MockApiResponses {
  // region 认证相关

  static Map<String, dynamic> loginSuccess({
    String token = 'mock_token_123',
    String email = 'test@example.com',
    String studentId = '2111111',
    bool verified = true,
  }) {
    return <String, dynamic>{
      'token': token,
      'email': email,
      'studentId': studentId,
      'verified': verified,
      'accessToken': token,
    };
  }

  static Map<String, dynamic> loginNeedsVerification() {
    return <String, dynamic>{
      'needVerify': true,
      'email': 'test@example.com',
    };
  }

  static Map<String, dynamic> registerSuccess() {
    return <String, dynamic>{
      'message': '注册成功',
    };
  }

  static Map<String, dynamic> sendEmailCodeSuccess() {
    return <String, dynamic>{
      'message': '验证码已发送',
      'debugCode': '123456',
    };
  }

  static Map<String, dynamic> badRequest(String message) {
    return <String, dynamic>{
      'message': message,
    };
  }

  static Map<String, dynamic> notFound([String message = '资源不存在']) {
    return <String, dynamic>{
      'message': message,
    };
  }

  static Map<String, dynamic> verifyEmailSuccess({
    String token = 'verified_token_456',
    String email = 'test@example.com',
  }) {
    return <String, dynamic>{
      'token': token,
      'email': email,
      'verified': true,
      'accessToken': token,
    };
  }

  // endregion

  // region 帖子相关

  static Map<String, dynamic> postsSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p1',
          'title': '测试帖子标题',
          'content': '测试帖子内容',
          'channel': '吐槽日常',
          'tags': <String>['测试', 'Flutter'],
          'authorAlias': '测试用户',
          'createdAt': DateTime.now().toIso8601String(),
          'hasImage': false,
          'commentCount': 5,
          'likeCount': 10,
          'favoriteCount': 3,
          'status': 'ongoing',
          'allowComment': true,
          'allowDm': true,
        },
        <String, dynamic>{
          'id': 'p2',
          'title': '第二个帖子',
          'content': '内容二',
          'channel': '求助问答',
          'tags': <String>['求助'],
          'authorAlias': '匿名同学',
          'createdAt': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'hasImage': true,
          'commentCount': 3,
          'likeCount': 7,
          'favoriteCount': 1,
          'status': 'ongoing',
          'allowComment': true,
          'allowDm': false,
        },
      ],
    };
  }

  static Map<String, dynamic> postDetailSuccess() {
    return <String, dynamic>{
      'id': 'p1',
      'title': '测试帖子标题',
      'content': '这是帖子的详细内容。',
      'channel': '吐槽日常',
      'tags': <String>['测试'],
      'authorAlias': '测试用户',
      'createdAt': DateTime.now().toIso8601String(),
      'hasImage': false,
      'commentCount': 5,
      'likeCount': 10,
      'favoriteCount': 3,
      'status': 'ongoing',
      'allowComment': true,
      'allowDm': true,
    };
  }

  static Map<String, dynamic> createPostSuccess() {
    return <String, dynamic>{
      'id': 'new_post_id',
      'title': '新帖子标题',
      'content': '新帖子内容',
      'channel': '吐槽日常',
      'tags': <String>[],
      'authorAlias': '我的昵称',
      'createdAt': DateTime.now().toIso8601String(),
      'hasImage': false,
      'commentCount': 0,
      'likeCount': 0,
      'favoriteCount': 0,
      'status': 'ongoing',
      'allowComment': true,
      'allowDm': false,
    };
  }

  static Map<String, dynamic> channelsSuccess() {
    return <String, dynamic>{
      'data': <String>[
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
      ],
    };
  }

  static Map<String, dynamic> commentsSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'c1',
          'authorAlias': '匿名同学-1',
          'content': '这是第一条评论',
          'createdAt': DateTime.now().toIso8601String(),
          'likeCount': 2,
        },
        <String, dynamic>{
          'id': 'c2',
          'authorAlias': '匿名同学-2',
          'content': '这是第二条评论',
          'createdAt': DateTime.now()
              .subtract(const Duration(minutes: 10))
              .toIso8601String(),
          'likeCount': 0,
        },
      ],
    };
  }

  static Map<String, dynamic> favoriteSuccess() {
    return <String, dynamic>{
      'favorited': true,
      'favoriteCount': 4,
    };
  }

  // endregion

  // region 私信相关

  static Map<String, dynamic> dmRequestsSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'req1',
          'fromAlias': '同学-海盐',
          'fromAvatarUrl': '',
          'reason': '想咨询问题',
          'timeText': '10 分钟前',
          'status': 'pending',
          'statusLabel': '待处理',
        },
      ],
    };
  }

  static Map<String, dynamic> conversationsSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'conv1',
          'peerUserId': 'user2',
          'name': '同学-海盐',
          'avatarUrl': '',
          'lastMessage': '你好！',
          'timeText': '14:23',
        },
      ],
    };
  }

  static Map<String, dynamic> messagesSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'm1',
          'senderId': 'user1',
          'content': '你好',
          'createdAt': DateTime.now().toIso8601String(),
        },
        <String, dynamic>{
          'id': 'm2',
          'senderId': 'user2',
          'content': '你好，有什么可以帮你的？',
          'createdAt': DateTime.now()
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
        },
      ],
    };
  }

  // endregion

  // region 举报相关

  static Map<String, dynamic> reportSuccess() {
    return <String, dynamic>{
      'message': '举报已提交，感谢您的反馈',
    };
  }

  // endregion

  // region 搜索相关

  static Map<String, dynamic> searchPostsSuccess() {
    return <String, dynamic>{
      'data': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 'p1',
          'title': '搜索结果帖子',
          'content': '这是搜索到的内容',
          'channel': '吐槽日常',
          'tags': <String>['Flutter', '测试'],
          'authorAlias': '测试用户',
          'createdAt': DateTime.now().toIso8601String(),
          'hasImage': false,
          'commentCount': 2,
          'likeCount': 5,
          'favoriteCount': 1,
          'status': 'ongoing',
          'allowComment': true,
          'allowDm': true,
        },
      ],
    };
  }

  // endregion
}
