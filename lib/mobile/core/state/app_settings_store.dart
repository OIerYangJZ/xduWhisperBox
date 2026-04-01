import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 树洞移动端应用级设置（主题、语言）的持久化管理。
/// 单例，通过 AppSettingsStore.instance 访问。
class AppSettingsStore extends ChangeNotifier {
  AppSettingsStore._();
  static final AppSettingsStore instance = AppSettingsStore._();

  SharedPreferences? _prefs;

  static const String _brightnessKey =
      'treehole_brightness'; // ThemeMode.index: 0=system, 1=light, 2=dark
  static const String _localeKey =
      'treehole_localization'; // 'zh_CN', 'zh_Hant', 'en_US'
  static const String _legacyLocaleKey = 'treehole_locale';

  ThemeMode _themeMode = ThemeMode.light;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;

  /// 应用启动时调用，从 SharedPreferences 恢复持久化状态。
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _themeMode = ThemeMode.values[_prefs!.getInt(_brightnessKey) ?? 1];
    final String loc =
        _prefs!.getString(_localeKey) ??
        _prefs!.getString(_legacyLocaleKey) ??
        'zh_CN';
    _locale = _parseLocaleCode(loc);
    notifyListeners();
  }

  /// 设置主题亮度并持久化。
  Future<void> setBrightness(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs?.setInt(_brightnessKey, mode.index);
    notifyListeners();
  }

  /// 设置语言并持久化。
  Future<void> setLocale(Locale loc) async {
    _locale = _normalizeLocale(loc);
    final code = _storageLocaleCode(_locale!);
    await _prefs?.setString(_localeKey, code);
    await _prefs?.setString(_legacyLocaleKey, code);
    notifyListeners();
  }

  Locale _normalizeLocale(Locale locale) {
    if (locale.languageCode == 'zh' &&
        (locale.scriptCode == 'Hant' || locale.countryCode == 'TW')) {
      return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
    }
    if (locale.languageCode == 'en') {
      return const Locale('en');
    }
    return const Locale('zh', 'CN');
  }

  Locale _parseLocaleCode(String raw) {
    final String code = raw.trim();
    switch (code) {
      case 'zh_TW':
      case 'zh_Hant':
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      case 'en':
      case 'en_US':
        return const Locale('en');
      case 'zh':
      case 'zh_CN':
      default:
        return const Locale('zh', 'CN');
    }
  }

  String _storageLocaleCode(Locale locale) {
    if (locale.languageCode == 'zh' && locale.scriptCode == 'Hant') {
      return 'zh_Hant';
    }
    if (locale.languageCode == 'en') {
      return 'en_US';
    }
    return 'zh_CN';
  }
}
