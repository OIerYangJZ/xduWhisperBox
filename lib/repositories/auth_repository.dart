import '../core/auth/auth_store.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/json_utils.dart';

class AuthLoginResult {
  AuthLoginResult({
    required this.verified,
    this.token,
    this.email,
    this.studentId,
    this.raw = const <String, dynamic>{},
  });

  final bool verified;
  final String? token;
  final String? email;
  final String? studentId;
  final Map<String, dynamic> raw;
}

class XidianAuthSessionResult {
  XidianAuthSessionResult({
    required this.attemptId,
    required this.status,
    this.platform,
    this.authorizeUrl,
    this.message,
    this.token,
    this.email,
    this.studentId,
  });

  final String attemptId;
  final String status;
  final String? platform;
  final String? authorizeUrl;
  final String? message;
  final String? token;
  final String? email;
  final String? studentId;

  bool get isPending => status == 'pending';
  bool get isAuthenticated => status == 'authenticated';
  bool get isFailed => status == 'failed';
}

class AuthRepository {
  AuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<void> register({
    required String email,
    required String password,
    required String nickname,
    String? avatarUrl,
    String? avatarFileName,
    String? avatarContentType,
    String? avatarDataBase64,
  }) async {
    await _apiClient.post(
      ApiEndpoints.register,
      auth: false,
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'nickname': nickname,
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          'avatarUrl': avatarUrl.trim(),
        if (avatarFileName != null && avatarFileName.trim().isNotEmpty)
          'avatarFileName': avatarFileName.trim(),
        if (avatarContentType != null && avatarContentType.trim().isNotEmpty)
          'avatarContentType': avatarContentType.trim(),
        if (avatarDataBase64 != null && avatarDataBase64.trim().isNotEmpty)
          'avatarDataBase64': avatarDataBase64.trim(),
      },
    );
  }

  Future<String?> sendEmailCode(String email) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.sendEmailCode,
      auth: false,
      body: <String, dynamic>{'email': email},
    );
    final Map<String, dynamic> data = extractMap(response);
    return readString(data, <String>['debugCode']);
  }

  Future<AuthLoginResult> login({
    required String identifier,
    required String password,
  }) async {
    throw UnsupportedError('普通用户已改为浏览器统一认证登录');
  }

  Future<XidianAuthSessionResult> createXidianAuthSession({
    required String platform,
    String nextPath = '/',
  }) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.xidianAuthSession,
      auth: false,
      body: <String, dynamic>{
        'platform': platform,
        'nextPath': nextPath,
      },
    );
    return _parseXidianAuthSession(response);
  }

  Future<XidianAuthSessionResult> fetchXidianAuthSession(String attemptId) async {
    final dynamic response = await _apiClient.get(
      ApiEndpoints.xidianAuthSessionById(attemptId),
      auth: false,
    );
    final XidianAuthSessionResult result = _parseXidianAuthSession(response);
    if (result.token != null && result.token!.isNotEmpty) {
      await AuthStore.instance.saveToken(result.token!);
    }
    return result;
  }

  Future<AuthLoginResult> consumeMobileCallbackUrl(String callbackUrl) async {
    final dynamic response = await _apiClient.get(
      callbackUrl,
      auth: false,
    );
    final AuthLoginResult result = _parseAuthResult(response);
    if (result.token != null && result.token!.isNotEmpty) {
      await AuthStore.instance.saveToken(result.token!);
    }
    return result;
  }

  Future<AuthLoginResult> verifyEmail({
    required String email,
    required String code,
    String? password,
  }) async {
    final Map<String, dynamic> body = <String, dynamic>{
      'email': email,
      'code': code,
    };
    if (password != null && password.trim().isNotEmpty) {
      body['password'] = password.trim();
    }

    final dynamic response = await _apiClient.post(
      ApiEndpoints.verifyEmail,
      auth: false,
      body: body,
    );

    final AuthLoginResult result =
        _parseAuthResult(response, forceVerified: true);
    if (result.token != null && result.token!.isNotEmpty) {
      await AuthStore.instance.saveToken(result.token!);
    }
    return result;
  }

  Future<String?> resendCode(String email) async {
    final dynamic response = await _apiClient.post(
      ApiEndpoints.resendCode,
      auth: false,
      body: <String, dynamic>{'email': email},
    );
    final Map<String, dynamic> data = extractMap(response);
    return readString(data, <String>['debugCode']);
  }

  Future<void> sendPasswordResetCode(String email) async {
    await _apiClient.post(
      ApiEndpoints.passwordResetSendCode,
      auth: false,
      body: <String, dynamic>{'email': email},
    );
  }

  Future<void> resetPasswordByEmail({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _apiClient.post(
      ApiEndpoints.passwordReset,
      auth: false,
      body: <String, dynamic>{
        'email': email,
        'code': code,
        'newPassword': newPassword,
      },
    );
  }

  Future<void> logout() async {
    try {
      await _apiClient
          .post(ApiEndpoints.logout, body: const <String, dynamic>{});
    } catch (_) {
      // 后端不可达时也允许本地退出。
    }
    await AuthStore.instance.clear();
  }

  Future<void> clearLocalAuth() {
    return AuthStore.instance.clear();
  }

  Future<void> saveToken(String token) {
    return AuthStore.instance.saveToken(token);
  }

  AuthLoginResult _parseAuthResult(
    dynamic response, {
    bool forceVerified = false,
  }) {
    final Map<String, dynamic> root = asMap(response);
    final Map<String, dynamic> data = extractMap(response);

    final String? token =
        readString(data, <String>['token', 'accessToken', 'jwt']) ??
            readString(root, <String>['token', 'accessToken', 'jwt']);
    final String? email =
        readString(data, <String>['email']) ??
            readString(root, <String>['email']);
    final String? studentId =
        readString(data, <String>['studentId', 'userId']) ??
            readString(root, <String>['studentId', 'userId']);

    final bool needsVerify = readBool(data,
            <String>['needVerify', 'needVerification', 'requireVerify']) ??
        readBool(root,
            <String>['needVerify', 'needVerification', 'requireVerify']) ??
        false;

    bool verified = readBool(data, <String>['verified', 'isVerified']) ??
        readBool(root, <String>['verified', 'isVerified']) ??
        false;

    if (forceVerified) {
      verified = true;
    }
    if (needsVerify) {
      verified = false;
    }
    if (!verified && token != null && token.isNotEmpty && !needsVerify) {
      verified = true;
    }

    return AuthLoginResult(
      verified: verified,
      token: token,
      email: email,
      studentId: studentId,
      raw: data,
    );
  }

  XidianAuthSessionResult _parseXidianAuthSession(dynamic response) {
    final Map<String, dynamic> root = asMap(response);
    final Map<String, dynamic> data = extractMap(response);
    return XidianAuthSessionResult(
      attemptId:
          readString(data, <String>['attemptId']) ??
          readString(root, <String>['attemptId']) ??
          '',
      status:
          readString(data, <String>['status']) ??
          readString(root, <String>['status']) ??
          'pending',
      platform:
          readString(data, <String>['platform']) ??
          readString(root, <String>['platform']),
      authorizeUrl:
          readString(data, <String>['authorizeUrl']) ??
          readString(root, <String>['authorizeUrl']),
      message:
          readString(data, <String>['message']) ??
          readString(root, <String>['message']),
      token:
          readString(data, <String>['token']) ??
          readString(root, <String>['token']),
      email:
          readString(data, <String>['email']) ??
          readString(root, <String>['email']),
      studentId:
          readString(data, <String>['studentId']) ??
          readString(root, <String>['studentId']),
    );
  }
}
