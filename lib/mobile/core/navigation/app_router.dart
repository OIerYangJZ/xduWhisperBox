import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';
import 'package:xdu_treehole_web/core/auth/admin_auth_store.dart';
import 'package:xdu_treehole_web/repositories/app_repositories.dart';
import '../../features/shell/mobile_shell.dart';
import '../../features/auth/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/search/search_page.dart';
import '../../features/messages/messages_page.dart';
import '../../features/favorites/favorites_page.dart';
import '../../features/profile/public_user_profile_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/post/post_detail_page.dart';
import '../../features/post/create_post_page.dart';
import '../../features/messages/chat_page.dart';
import '../../features/notifications/notification_center_page.dart';
import '../../features/profile/edit_profile_page.dart';
import '../../features/profile/settings_main_page.dart';
import '../../features/profile/notification_settings_page.dart';
import '../../features/profile/my_posts_page.dart';
import '../../features/profile/my_comments_page.dart';
import '../../features/profile/my_reports_page.dart';
import '../../features/profile/help_and_feedback_page.dart';
import '../../features/profile/acknowledgements_page.dart';
import '../../features/admin/admin_login_page.dart';
import 'package:xdu_treehole_web/features/admin/admin_console_page.dart';
import 'package:xdu_treehole_web/features/legal/terms_of_service_page.dart';
import 'package:xdu_treehole_web/features/legal/privacy_policy_page.dart';
import 'package:xdu_treehole_web/features/legal/community_guidelines_page.dart';
import 'package:xdu_treehole_web/features/legal/report_guidelines_page.dart';

/// 路由守卫：检查是否已登录
String? _authGuard(BuildContext context, GoRouterState state) {
  final isLoggedIn = AuthStore.instance.isAuthenticated;
  final isAdminLoggedIn = AdminAuthStore.instance.isAuthenticated;
  final isAuthRoute = state.matchedLocation.startsWith('/auth');
  final isAdminRoute = state.matchedLocation.startsWith('/admin');
  final isAdminLoginRoute = state.matchedLocation == '/admin/login';
  final isPublicRoute =
      state.matchedLocation == '/profile/help-feedback' ||
      state.matchedLocation.startsWith('/legal/');

  // 如果是管理员路由
  if (isAdminRoute) {
    if (!isAdminLoggedIn && !isAdminLoginRoute) {
      return '/admin/login';
    }
    if (isAdminLoggedIn && isAdminLoginRoute) {
      return '/admin';
    }
    return null;
  }

  // 如果是认证路由
  if (isAuthRoute) {
    if (isLoggedIn) {
      return '/';
    }
    return null;
  }

  // 其他路由需要登录（公开路由除外）
  if (!isLoggedIn && !isPublicRoute) {
    return '/auth/login';
  }

  return null;
}

/// 路由配置
final appRouter = GoRouter(
  initialLocation: '/',
  refreshListenable: AuthStore.instance,
  redirect: _authGuard,
  routes: [
    // 认证路由（未登录状态）
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/auth/verify',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/auth/reset-password',
      builder: (context, state) => const LoginPage(),
    ),

    // 主页面（底部 Tab 导航）— 3 tabs: 首页 / 消息 / 我的
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return MobileShell(navigationShell: navigationShell);
      },
      branches: [
        // 首页
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomePage()),
          ],
        ),
        // 消息
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/messages',
              builder: (context, state) => const MessagesPage(),
            ),
          ],
        ),
        // 我的
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfilePage(),
            ),
          ],
        ),
      ],
    ),

    // 搜索（全屏，不在 Tab 内）
    GoRoute(path: '/search', builder: (context, state) => const SearchPage()),
    // 收藏（全屏，不在 Tab 内）
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesPage(),
    ),

    // 他人主页
    GoRoute(
      path: '/user/:id',
      builder: (context, state) {
        final userId = state.pathParameters['id']!;
        return PublicUserProfilePage(userId: userId);
      },
    ),

    // 全屏页面（不在 Tab 内）
    GoRoute(
      path: '/post/create',
      builder: (context, state) => const CreatePostPage(),
    ),
    GoRoute(
      path: '/post/:id',
      builder: (context, state) {
        final postId = state.pathParameters['id']!;
        final String? initialCommentId = state.uri.queryParameters['commentId'];
        return PostDetailPage(
          postId: postId,
          initialCommentId: initialCommentId,
        );
      },
    ),
    GoRoute(
      path: '/chat/:conversationId',
      builder: (context, state) {
        final conversationId = state.pathParameters['conversationId']!;
        final extra = state.uri.queryParameters;
        return ChatPage(
          conversationId: conversationId,
          peerName: extra['name'],
          peerAvatar: extra['avatar'],
          peerUserId: extra['userId'],
        );
      },
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationCenterPage(),
    ),
    GoRoute(
      path: '/users/:userId',
      builder: (context, state) {
        final userId = state.pathParameters['userId']!;
        return PublicUserProfilePage(userId: userId);
      },
    ),
    GoRoute(
      path: '/profile/change-password',
      builder: (context, state) => const SettingsMainPage(),
    ),
    GoRoute(
      path: '/profile/edit',
      builder: (context, state) => const EditProfilePage(),
    ),
    GoRoute(
      path: '/profile/settings',
      builder: (context, state) => const SettingsMainPage(),
    ),
    GoRoute(
      path: '/profile/settings/main',
      builder: (context, state) => const SettingsMainPage(),
    ),
    GoRoute(
      path: '/profile/settings/notifications',
      builder: (context, state) => const NotificationSettingsPage(),
    ),
    GoRoute(
      path: '/profile/posts',
      builder: (context, state) => const MyPostsPage(),
    ),
    GoRoute(
      path: '/profile/comments',
      builder: (context, state) => const MyCommentsPage(),
    ),
    GoRoute(
      path: '/profile/reports',
      builder: (context, state) => const MyReportsPage(),
    ),
    GoRoute(
      path: '/profile/help-feedback',
      builder: (context, state) => const HelpAndFeedbackPage(),
    ),
    GoRoute(
      path: '/profile/acknowledgements',
      builder: (context, state) => const AcknowledgementsPage(),
    ),
    GoRoute(
      path: '/legal/terms',
      builder: (context, state) => const TermsOfServicePage(),
    ),
    GoRoute(
      path: '/legal/privacy',
      builder: (context, state) => const PrivacyPolicyPage(),
    ),
    GoRoute(
      path: '/legal/guidelines',
      builder: (context, state) => const CommunityGuidelinesPage(),
    ),
    GoRoute(
      path: '/legal/report',
      builder: (context, state) => const ReportGuidelinesPage(),
    ),

    // 管理员路由
    GoRoute(
      path: '/admin/login',
      builder: (context, state) => const AdminLoginPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => AdminConsolePage(
        repository: AppRepositories.adminPortal,
        onLogout: () async {
          try {
            await AppRepositories.adminAuth.logout();
          } catch (_) {}
          AdminAuthStore.instance.clear();
        },
      ),
    ),
  ],
);
