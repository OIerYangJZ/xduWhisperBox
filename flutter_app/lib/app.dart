import 'package:flutter/material.dart';

import 'core/auth/admin_auth_store.dart';
import 'core/auth/auth_store.dart';
import 'features/admin/admin_portal_page.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';
import 'features/download/android_release_page.dart';
import 'features/legal/privacy_policy_page.dart';
import 'features/legal/community_guidelines_page.dart';
import 'features/legal/report_guidelines_page.dart';
import 'features/legal/terms_of_service_page.dart';
import 'widgets/home_shell.dart';

class XduTreeholeApp extends StatelessWidget {
  const XduTreeholeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '西电树洞',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      onGenerateRoute: _onGenerateRoute,
    );
  }

  static Route<dynamic>? _onGenerateRoute(RouteSettings settings) {
    final String routeName = settings.name ?? '/';

    if (routeName == '/') {
      return MaterialPageRoute<void>(
        builder: (_) => _initialPage(),
        settings: settings,
      );
    }

    if (routeName == '/terms') {
      return MaterialPageRoute<void>(
        builder: (_) => const TermsOfServicePage(),
        settings: settings,
      );
    }
    if (routeName == '/privacy') {
      return MaterialPageRoute<void>(
        builder: (_) => const PrivacyPolicyPage(),
        settings: settings,
      );
    }
    if (routeName == '/guidelines') {
      return MaterialPageRoute<void>(
        builder: (_) => const CommunityGuidelinesPage(),
        settings: settings,
      );
    }
    if (routeName == '/report-guidelines') {
      return MaterialPageRoute<void>(
        builder: (_) => const ReportGuidelinesPage(),
        settings: settings,
      );
    }
    if (routeName == '/download') {
      return MaterialPageRoute<void>(
        builder: (_) => const AndroidReleasePage(),
        settings: settings,
      );
    }
    return null;
  }

  static Widget _initialPage() {
    if (AuthStore.instance.isAuthenticated) {
      return const HomeShell();
    }
    if (AdminAuthStore.instance.isAuthenticated) {
      return const AdminPortalPage();
    }
    return const LoginPage();
  }
}
