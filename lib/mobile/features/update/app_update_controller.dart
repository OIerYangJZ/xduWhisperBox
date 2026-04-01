import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:xdu_treehole_web/mobile/core/config/mobile_config.dart';
import 'package:xdu_treehole_web/models/app_release_item.dart';
import 'package:xdu_treehole_web/repositories/app_repositories.dart';

class AppUpdateController extends ChangeNotifier {
  AppUpdateController._();

  static final AppUpdateController instance = AppUpdateController._();

  Future<void>? _initializeFuture;
  bool _initialized = false;
  bool _checking = false;
  String? _error;
  AppReleaseItem? _latestRelease;
  String _currentVersionName = MobileConfig.appVersion;
  int _currentVersionCode = 0;
  int? _startupPromptedVersionCode;

  bool get initialized => _initialized;
  bool get checking => _checking;
  String? get error => _error;
  AppReleaseItem? get latestRelease => _latestRelease;
  String get currentVersionName => _currentVersionName;
  int get currentVersionCode => _currentVersionCode;

  String get currentVersionLabel {
    if (_currentVersionCode > 0) {
      return '$_currentVersionName（$_currentVersionCode）';
    }
    return _currentVersionName;
  }

  String get latestVersionLabel {
    final release = _latestRelease;
    if (release == null) {
      return '';
    }
    if (release.versionCode > 0) {
      return '${release.versionName}（${release.versionCode}）';
    }
    return release.versionName;
  }

  bool get hasUpdate {
    final release = _latestRelease;
    if (release == null) {
      return false;
    }
    return _compareReleaseWithCurrent(release) > 0;
  }

  Future<void> ensureInitialized() {
    return _initializeFuture ??= _initialize();
  }

  Future<bool> checkForUpdates({bool clearError = true}) async {
    await ensureInitialized();
    if (_checking) {
      return hasUpdate;
    }

    _checking = true;
    if (clearError) {
      _error = null;
    }
    notifyListeners();

    try {
      _latestRelease = await AppRepositories.releases
          .fetchLatestAndroidRelease();
      _error = null;
    } catch (error) {
      _error = error.toString().replaceAll('Exception: ', '');
    } finally {
      _checking = false;
      notifyListeners();
    }

    return hasUpdate;
  }

  bool consumeStartupPrompt() {
    final release = _latestRelease;
    if (release == null || !hasUpdate) {
      return false;
    }
    if (_startupPromptedVersionCode == release.versionCode) {
      return false;
    }
    _startupPromptedVersionCode = release.versionCode;
    return true;
  }

  Future<void> _initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final String versionName = packageInfo.version.trim();
      final int versionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
      if (versionName.isNotEmpty) {
        _currentVersionName = versionName;
      }
      _currentVersionCode = versionCode;
    } catch (_) {
      _currentVersionName = MobileConfig.appVersion;
      _currentVersionCode = 0;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  int _compareReleaseWithCurrent(AppReleaseItem release) {
    if (release.versionCode > 0 && _currentVersionCode > 0) {
      final int codeCompare = release.versionCode.compareTo(
        _currentVersionCode,
      );
      if (codeCompare != 0) {
        return codeCompare;
      }
    }
    return _compareVersionNames(release.versionName, _currentVersionName);
  }

  int _compareVersionNames(String latest, String current) {
    final List<int> latestParts = _parseVersionParts(latest);
    final List<int> currentParts = _parseVersionParts(current);
    final int maxLength = latestParts.length > currentParts.length
        ? latestParts.length
        : currentParts.length;
    for (int index = 0; index < maxLength; index++) {
      final int latestValue = index < latestParts.length
          ? latestParts[index]
          : 0;
      final int currentValue = index < currentParts.length
          ? currentParts[index]
          : 0;
      if (latestValue != currentValue) {
        return latestValue.compareTo(currentValue);
      }
    }
    return 0;
  }

  List<int> _parseVersionParts(String raw) {
    return raw
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
