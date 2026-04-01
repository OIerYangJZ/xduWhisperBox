import 'package:flutter/foundation.dart';

  /// 移动端专用配置文件
  /// 通过 --dart-define 在编译时注入实际 API 地址
class MobileConfig {
  /// API 基础地址
  /// 通过 --dart-define=MOBILE_API_BASE_URL=... 在构建时注入
  /// 生产环境默认直连现网 HTTP（腾讯云公网 IP）；正式分发建议改为 HTTPS 域名。
  static const String apiBaseUrl = String.fromEnvironment(
    'MOBILE_API_BASE_URL',
    defaultValue: 'http://81.69.16.134/api',
  );

  /// 统一认证固定回调域名（必须为 IDS 已登记的 HTTPS 外网 Origin）。
  /// 当 API 仍走 IP / 非 HTTPS 地址时，移动端统一认证必须单独配置这个值。
  static const String xidianPublicOrigin = String.fromEnvironment(
    'MOBILE_XIDIAN_PUBLIC_ORIGIN',
    defaultValue: '',
  );

  /// App 版本号
  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// 请求超时时间
  static const Duration requestTimeout = Duration(seconds: 15);

  /// 是否启用调试模式
  static const bool debugMode = kDebugMode;

  /// 检查是否为生产环境
  static bool get isProduction => !kDebugMode;
}
