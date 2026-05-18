import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:xdu_treehole_web/core/network/api_client.dart';
import 'package:xdu_treehole_web/core/network/api_exception.dart';
import 'package:xdu_treehole_web/repositories/auth_repository.dart';
import 'api_mocks.dart';

void main() {
  group('AuthRepository', () {
    late MockClient mockClient;
    late AuthRepository authRepository;

    setUp(() {
      mockClient = MockClient((http.Request request) async {
        final String path = request.url.path;
        final String method = request.method;

        if (path.endsWith('/auth/login') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final identifier = body['identifier'] as String?;
          final password = body['password'] as String?;

          if (identifier == 'test@example.com' &&
              password == 'correct_password') {
            return http.Response(
              jsonEncode(MockApiResponses.loginSuccess()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }
          if (identifier == 'unverified@example.com') {
            return http.Response(
              jsonEncode(MockApiResponses.loginNeedsVerification()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(MockApiResponses.badRequest('用户名或密码错误')),
            400,
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/register') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final email = body['email'] as String?;

          if (email != null && email.contains('@')) {
            return http.Response(
              jsonEncode(MockApiResponses.registerSuccess()),
              201,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(MockApiResponses.badRequest('邮箱格式不正确')),
            400,
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/send-code') && method == 'POST') {
          return http.Response(
            jsonEncode(MockApiResponses.sendEmailCodeSuccess()),
            200,
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/verify') && method == 'POST') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final code = body['code'] as String?;

          if (code == '123456') {
            return http.Response(
              jsonEncode(MockApiResponses.verifyEmailSuccess()),
              200,
              headers: {'Content-Type': 'application/json'},
            );
          }
          return http.Response(
            jsonEncode(MockApiResponses.badRequest('验证码错误')),
            400,
            headers: {'Content-Type': 'application/json'},
          );
        }

        if (path.endsWith('/auth/logout') && method == 'POST') {
          return http.Response(
            jsonEncode(<String, dynamic>{'message': '已退出登录'}),
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
    });

    group('login', () {
      test('使用正确凭据登录成功', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        final result = await authRepository.login(
          identifier: 'test@example.com',
          password: 'correct_password',
        );

        expect(result.verified, isTrue);
        expect(result.token, equals('mock_token_123'));
        expect(result.email, equals('test@example.com'));
        expect(result.studentId, equals('2111111'));
      });

      test('未验证用户返回需要验证标志', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        final result = await authRepository.login(
          identifier: 'unverified@example.com',
          password: 'any_password',
        );

        expect(result.verified, isFalse);
        expect(result.token, isNull);
      });

      test('错误凭据抛出异常', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        expect(
          () => authRepository.login(
            identifier: 'wrong@example.com',
            password: 'wrong_password',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('register', () {
      test('注册成功不抛出异常', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        await expectLater(
          authRepository.register(
            email: 'new@example.com',
            password: 'password123',
            nickname: '新用户',
          ),
          completes,
        );
      });

      test('无效邮箱抛出异常', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        expect(
          () => authRepository.register(
            email: 'invalid-email',
            password: 'password123',
            nickname: '新用户',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('sendEmailCode', () {
      test('发送验证码成功返回 debug code', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        final debugCode =
            await authRepository.sendEmailCode('test@example.com');

        expect(debugCode, equals('123456'));
      });
    });

    group('verifyEmail', () {
      test('正确验证码验证成功', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        final result = await authRepository.verifyEmail(
          email: 'test@example.com',
          code: '123456',
        );

        expect(result.verified, isTrue);
        expect(result.token, equals('verified_token_456'));
      });

      test('错误验证码抛出异常', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        expect(
          () => authRepository.verifyEmail(
            email: 'test@example.com',
            code: 'wrong_code',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('logout', () {
      test('登出成功', () async {
        authRepository = AuthRepository(ApiClient(httpClient: mockClient));

        await expectLater(
          authRepository.logout(),
          completes,
        );
      });
    });
  });

  group('AuthLoginResult', () {
    test('正确解析登录响应中的 token', () {
      final mockResponse = MockApiResponses.loginSuccess(
        token: 'test_token',
        email: 'user@test.com',
        studentId: '1234567',
        verified: true,
      );

      expect(mockResponse['token'], equals('test_token'));
      expect(mockResponse['email'], equals('user@test.com'));
      expect(mockResponse['studentId'], equals('1234567'));
      expect(mockResponse['verified'], isTrue);
    });

    test('处理 accessToken 别名字段', () {
      final responseWithAccessToken = <String, dynamic>{
        'accessToken': 'alt_token',
        'email': 'user@test.com',
        'verified': true,
      };

      expect(responseWithAccessToken['accessToken'], equals('alt_token'));
    });

    test('处理 needVerify 标志', () {
      final needsVerification = MockApiResponses.loginNeedsVerification();

      expect(needsVerification['needVerify'], isTrue);
      expect(needsVerification['email'], equals('test@example.com'));
    });
  });
}
