import '../core/auth/admin_auth_store.dart';
import '../core/network/api_client.dart';
import '../core/network/api_endpoints.dart';
import '../core/network/api_exception.dart';
import '../core/network/json_utils.dart';

class AdminAuthRepository {
  AdminAuthRepository(this._apiClient);

  final ApiClient _apiClient;

  Future<String> login({
    required String username,
    required String password,
  }) async {
    dynamic response;
    try {
      response = await _apiClient.post(
        ApiEndpoints.adminLogin,
        auth: false,
        body: <String, dynamic>{
          'username': username,
          'password': password,
        },
      );
    } on ApiException catch (error) {
      if (error.statusCode == 404) {
        throw Exception(
          '管理员登录接口不存在（404）。请重启后端并确认使用最新 backend/server.py。',
        );
      }
      rethrow;
    }
    final Map<String, dynamic> data = extractMap(response);
    final String token = (data['token'] ?? '').toString().trim();
    if (token.isEmpty) {
      throw Exception('管理员登录失败：服务端未返回 token');
    }
    await AdminAuthStore.instance.saveToken(token);
    return token;
  }

  Future<void> logout() async {
    try {
      await _apiClient.post(
        ApiEndpoints.adminLogout,
        body: const <String, dynamic>{},
      );
    } catch (_) {
      // 后端不可达时也允许本地退出
    }
    await AdminAuthStore.instance.clear();
  }

  Future<String> fetchCurrentAdminUsername() async {
    final dynamic response = await _apiClient.get(ApiEndpoints.adminMe);
    final Map<String, dynamic> data = extractMap(response);
    return (data['username'] ?? '').toString();
  }

  Future<void> updatePassword({
    required String oldPassword,
    required String newPassword,
  }) {
    return _apiClient.patch(
      ApiEndpoints.adminPassword,
      body: <String, dynamic>{
        'oldPassword': oldPassword,
        'newPassword': newPassword,
      },
    );
  }
}
