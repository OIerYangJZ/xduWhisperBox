import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/config/mobile_config.dart';
import 'core/theme/mobile_theme.dart';
import 'core/navigation/app_router.dart';
import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/auth/admin_auth_store.dart';
import 'package:xdu_treehole_web/core/emoji/emoji_settings_store.dart';
import '../l10n/generated/app_localizations.dart';
import 'core/state/app_settings_store.dart';
import 'core/state/mobile_providers.dart' show appSettingsProvider;
import 'features/update/app_update_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (MobileConfig.debugMode) {
    debugPrint('[mobile] API base: ${MobileConfig.apiBaseUrl}');
    if (MobileConfig.xidianPublicOrigin.isNotEmpty) {
      debugPrint('[mobile] Xidian auth public origin: ${MobileConfig.xidianPublicOrigin}');
    }
  }

  // 初始化存储
  await AuthStore.instance.init();
  await AdminAuthStore.instance.init();
  await EmojiSettingsStore.instance.init();
  await AppSettingsStore.instance.init();

  // 设置状态栏样式
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  // 设置竖屏方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const ProviderScope(child: XduTreeholeMobileApp()));
}

class XduTreeholeMobileApp extends ConsumerWidget {
  const XduTreeholeMobileApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp.router(
      title: '西电树洞',
      debugShowCheckedModeBanner: false,
      theme: MobileTheme.lightTheme,
      darkTheme: MobileTheme.darkTheme,
      themeMode: settings.themeMode,
      locale: settings.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: appRouter,
      builder: (context, child) =>
          AppUpdateBootstrap(child: child ?? const SizedBox.shrink()),
    );
  }
}
