import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, TargetPlatform, defaultTargetPlatform;

class AppConfig {
  static const String _localApiBaseUrl = 'http://127.0.0.1:8080/api';
  static const String _androidEmulatorApiBaseUrl = 'http://10.0.2.2:8080/api';
  static const String _productionApiBaseUrl =
      'https://www.seediantreehole.cn/api';

  // Web 通常使用 API_BASE_URL 覆盖；移动端使用 MOBILE_API_BASE_URL 覆盖。
  static String get apiBaseUrl {
    const mobileUrl = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
      defaultValue: '',
    );
    if (mobileUrl.trim().isNotEmpty) {
      return _normalizeApiBaseUrl(mobileUrl);
    }

    const webUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');
    if (kIsWeb) {
      if (webUrl.trim().isNotEmpty) {
        return _normalizeApiBaseUrl(webUrl);
      }
      return kReleaseMode ? '/api' : _localApiBaseUrl;
    }

    final isMobile =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
    if (isMobile) {
      return _defaultMobileApiBaseUrl;
    }

    if (webUrl.trim().isNotEmpty) {
      return _normalizeApiBaseUrl(webUrl);
    }
    return kReleaseMode ? _productionApiBaseUrl : _localApiBaseUrl;
  }

  static String get _defaultMobileApiBaseUrl {
    if (kReleaseMode) {
      return _productionApiBaseUrl;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Android 模拟器访问宿主机 localhost 需要使用 10.0.2.2。
      return _androidEmulatorApiBaseUrl;
    }
    // iOS 模拟器可以直接访问宿主机 127.0.0.1；真机调试请注入局域网 IP。
    return _localApiBaseUrl;
  }

  // 统一认证回调固定外网 Origin。
  // Web 端由后端环境变量 BACKEND_XIDIAN_PUBLIC_ORIGIN 控制；
  // 移动端可通过 --dart-define=MOBILE_XIDIAN_PUBLIC_ORIGIN=https://example.com 注入。
  static String get xidianAuthPublicOrigin {
    const mobileAuthOrigin = String.fromEnvironment(
      'MOBILE_XIDIAN_PUBLIC_ORIGIN',
      defaultValue: '',
    );
    if (mobileAuthOrigin.trim().isNotEmpty) {
      return mobileAuthOrigin.trim().replaceAll(RegExp(r'/$'), '');
    }
    const sharedAuthOrigin = String.fromEnvironment(
      'XIDIAN_PUBLIC_ORIGIN',
      defaultValue: '',
    );
    if (sharedAuthOrigin.trim().isNotEmpty) {
      return sharedAuthOrigin.trim().replaceAll(RegExp(r'/$'), '');
    }

    final Uri? apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri != null &&
        apiUri.hasScheme &&
        apiUri.hasAuthority &&
        apiUri.scheme == 'https' &&
        !_isLoopbackHost(apiUri.host.trim().toLowerCase())) {
      final bool includePort =
          apiUri.hasPort &&
          !((apiUri.scheme == 'https' && apiUri.port == 443) ||
              (apiUri.scheme == 'http' && apiUri.port == 80));
      return '${apiUri.scheme}://${apiUri.host}${includePort ? ':${apiUri.port}' : ''}';
    }
    return '';
  }

  static String resolveXidianCallbackUrl(String path) {
    final String trimmedPath = path.startsWith('/') ? path : '/$path';
    final String fixedOrigin = xidianAuthPublicOrigin;
    if (fixedOrigin.isNotEmpty) {
      return Uri.parse(fixedOrigin).resolve(trimmedPath).toString();
    }
    final Uri? apiUri = Uri.tryParse(apiBaseUrl);
    if (apiUri != null &&
        apiUri.hasScheme &&
        apiUri.hasAuthority &&
        apiUri.scheme == 'https' &&
        !_isLoopbackHost(apiUri.host.trim().toLowerCase())) {
      return apiUri.resolve(trimmedPath).toString();
    }
    throw Exception(
      '统一认证回调地址未配置：请设置 HTTPS API 地址，或注入 '
      'MOBILE_XIDIAN_PUBLIC_ORIGIN / XIDIAN_PUBLIC_ORIGIN',
    );
  }

  // 生产构建时由 scripts/build_web_production.sh 通过 --dart-define=APP_VERSION=... 注入
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'dev',
  );

  static const Duration requestTimeout = Duration(seconds: 15);

  // 生产/现网不再展示本地 mock 卡片，空数据时直接显示真实空状态。
  static const bool enableMockFallback = false;

  static String resolveUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final Uri? parsed = Uri.tryParse(trimmed);
    if (parsed != null && parsed.hasScheme) {
      final String host = parsed.host.trim().toLowerCase();
      if (_isLoopbackHost(host)) {
        final String path = parsed.path.isEmpty ? '/' : parsed.path;
        if (trimmed.startsWith('/')) {
          return Uri.base.resolve(trimmed).toString();
        }
        final Uri? apiUri = Uri.tryParse(apiBaseUrl);
        if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
          return apiUri
              .resolveUri(
                Uri(
                  path: path,
                  query: parsed.hasQuery ? parsed.query : null,
                  fragment: parsed.hasFragment ? parsed.fragment : null,
                ),
              )
              .toString();
        }
        return Uri.base
            .resolveUri(
              Uri(
                path: path,
                query: parsed.hasQuery ? parsed.query : null,
                fragment: parsed.hasFragment ? parsed.fragment : null,
              ),
            )
            .toString();
      }
      return parsed.toString();
    }
    if (trimmed.startsWith('//')) {
      return '${Uri.base.scheme}:$trimmed';
    }

    final Uri? apiUri = Uri.tryParse(apiBaseUrl);
    if (trimmed.startsWith('/')) {
      if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
        return apiUri.resolve(trimmed).toString();
      }
      return Uri.base.resolve(trimmed).toString();
    }

    if (apiUri != null && apiUri.hasScheme && apiUri.hasAuthority) {
      return apiUri.resolve(trimmed).toString();
    }
    return Uri.base.resolve(trimmed).toString();
  }

  static bool _isLoopbackHost(String host) {
    return host == 'localhost' ||
        host == '127.0.0.1' ||
        host == '0.0.0.0' ||
        host == '::1';
  }

  static String _normalizeApiBaseUrl(String value) {
    final String trimmed = value.trim();
    if (trimmed == '/') {
      return trimmed;
    }
    return trimmed.replaceAll(RegExp(r'/+$'), '');
  }
}
