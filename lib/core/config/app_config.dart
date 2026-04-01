import 'package:flutter/foundation.dart'
    show kIsWeb, kReleaseMode, TargetPlatform, defaultTargetPlatform;

class AppConfig {
  // 运行时可通过 --dart-define=API_BASE_URL=http://host:port/api 覆盖
  // 移动端优先使用 MOBILE_API_BASE_URL（通过 MobileConfig 传入）
  static String get apiBaseUrl {
    // 先尝试移动端环境变量
    const mobileUrl = String.fromEnvironment(
      'MOBILE_API_BASE_URL',
      defaultValue: '',
    );
    if (mobileUrl.isNotEmpty) {
      return mobileUrl;
    }
    // 移动端通过 --dart-define=MOBILE_API_BASE_URL=... 注入
    final isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    if (isMobile) {
      // 移动端默认直连现网 HTTP（腾讯云公网 IP）；后续切 HTTPS 后应改回域名地址。
      // 如果通过 --dart-define 注入了真实地址，则优先使用注入值
      return const String.fromEnvironment(
        'MOBILE_API_BASE_URL',
        defaultValue: 'http://81.69.16.134/api',
      );
    }
    if (kReleaseMode) {
      return const String.fromEnvironment('API_BASE_URL', defaultValue: '/api');
    }
    return const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://localhost:8080/api',
    );
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
}
