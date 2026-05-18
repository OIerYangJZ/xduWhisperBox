import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../auth/auth_store.dart';
import '../config/app_config.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({http.Client? httpClient, String? Function()? tokenResolver})
    : _http = httpClient ?? http.Client(),
      _tokenResolver = tokenResolver ?? (() => AuthStore.instance.token);

  final http.Client _http;
  final String? Function() _tokenResolver;

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool auth = true,
  }) {
    return _request(
      method: 'GET',
      path: path,
      queryParameters: queryParameters,
      auth: auth,
    );
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
  }) {
    return _request(
      method: 'POST',
      path: path,
      queryParameters: queryParameters,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> patch(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
  }) {
    return _request(
      method: 'PATCH',
      path: path,
      queryParameters: queryParameters,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> delete(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
  }) {
    return _request(
      method: 'DELETE',
      path: path,
      queryParameters: queryParameters,
      body: body,
      auth: auth,
    );
  }

  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> fields,
    required String fileFieldName,
    required Uint8List fileBytes,
    required String fileName,
    Map<String, dynamic>? queryParameters,
    bool auth = true,
    Duration? timeout,
  }) async {
    final Uri uri = _buildUri(path, queryParameters: queryParameters);
    final http.MultipartRequest request = http.MultipartRequest('POST', uri)
      ..headers['Accept'] = 'application/json';

    if (auth) {
      final String? token = _tokenResolver();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    request.fields.addAll(fields);
    request.files.add(
      http.MultipartFile.fromBytes(
        fileFieldName,
        fileBytes,
        filename: fileName,
      ),
    );

    late http.Response response;
    try {
      final http.StreamedResponse streamed = await request.send().timeout(
        timeout ?? AppConfig.requestTimeout,
      );
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiException(message: '请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(message: '网络错误：$error');
    }

    final dynamic decoded = _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final String message =
        _extractMessage(decoded) ?? '请求失败（${response.statusCode}）';
    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: decoded,
    );
  }

  Future<dynamic> _request({
    required String method,
    required String path,
    Map<String, dynamic>? queryParameters,
    Object? body,
    required bool auth,
  }) async {
    final Uri uri = _buildUri(path, queryParameters: queryParameters);
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (auth) {
      final String? token = _tokenResolver();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    late http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http
              .get(uri, headers: headers)
              .timeout(AppConfig.requestTimeout);
          break;
        case 'POST':
          response = await _http
              .post(uri, headers: headers, body: _encodeBody(body))
              .timeout(AppConfig.requestTimeout);
          break;
        case 'PATCH':
          response = await _http
              .patch(uri, headers: headers, body: _encodeBody(body))
              .timeout(AppConfig.requestTimeout);
          break;
        case 'DELETE':
          response = await _http
              .delete(uri, headers: headers, body: _encodeBody(body))
              .timeout(AppConfig.requestTimeout);
          break;
        default:
          throw ApiException(message: 'Unsupported HTTP method: $method');
      }
    } on TimeoutException {
      throw ApiException(message: '请求超时，请稍后重试');
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(message: '网络错误：$error');
    }

    final dynamic decoded = _tryDecode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    final String message =
        _extractMessage(decoded) ?? '请求失败（${response.statusCode}）';
    throw ApiException(
      message: message,
      statusCode: response.statusCode,
      data: decoded,
    );
  }

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final String base = AppConfig.apiBaseUrl;
    final String normalized =
        path.startsWith('http://') || path.startsWith('https://')
        ? path
        : '${base.endsWith('/') ? base.substring(0, base.length - 1) : base}${path.startsWith('/') ? path : '/$path'}';

    final Uri uri = Uri.parse(normalized);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final Map<String, String> qp = <String, String>{};
    queryParameters.forEach((String key, dynamic value) {
      if (value == null) {
        return;
      }
      qp[key] = value.toString();
    });

    return uri.replace(queryParameters: qp.isEmpty ? null : qp);
  }

  String? _encodeBody(Object? body) {
    if (body == null) {
      return null;
    }
    if (body is String) {
      return body;
    }
    return jsonEncode(body);
  }

  dynamic _tryDecode(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractMessage(dynamic data) {
    if (data is Map<String, dynamic>) {
      final dynamic message = data['message'] ?? data['msg'] ?? data['error'];
      if (message != null) {
        return message.toString();
      }
    }
    if (data is Map) {
      final dynamic message = data['message'] ?? data['msg'] ?? data['error'];
      if (message != null) {
        return message.toString();
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      return data.trim();
    }
    return null;
  }
}
