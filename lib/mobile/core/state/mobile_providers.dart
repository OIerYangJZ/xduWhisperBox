import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/update/app_update_controller.dart';
import 'app_settings_store.dart';
import 'package:xdu_treehole_web/features/messages/messages_controller.dart'
    show messagesControllerProvider;
import 'package:xdu_treehole_web/features/notifications/notifications_controller.dart'
    show notificationsControllerProvider;

/// Re-export all shared providers for lib/mobile/features/ pages
export 'package:xdu_treehole_web/core/state/app_providers.dart';
export 'package:xdu_treehole_web/features/feed/feed_controller.dart'
    show feedControllerProvider;
export 'package:xdu_treehole_web/features/search/search_controller.dart';
export 'package:xdu_treehole_web/features/messages/messages_controller.dart'
    show messagesControllerProvider;
export 'package:xdu_treehole_web/features/notifications/notifications_controller.dart'
    show notificationsControllerProvider;

/// Mobile-only Providers

/// 应用级设置（主题、语言）
final appSettingsProvider = ChangeNotifierProvider<AppSettingsStore>((ref) {
  // AppSettingsStore 是单例，直接返回已有实例
  ref.onDispose(() {});
  return AppSettingsStore.instance;
});

/// App 更新状态
final appUpdateProvider = ChangeNotifierProvider<AppUpdateController>((ref) {
  ref.onDispose(() {});
  return AppUpdateController.instance;
});

/// 当前 Tab 索引
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

/// 骨架屏加载状态
final skeletonLoadingProvider = StateProvider<bool>((ref) => false);

/// 首页滚动到顶部触发器（每次变化即触发一次滚动）
final scrollToTopTriggerProvider = StateProvider<int>((ref) => 0);

/// 通知未读数
final notificationUnreadCountProvider = Provider<int>((ref) {
  final notificationsState = ref.watch(notificationsControllerProvider);
  return notificationsState.unreadCount;
});

/// 消息未读数
final messageUnreadCountProvider = Provider<int>((ref) {
  final messagesState = ref.watch(messagesControllerProvider);
  return messagesState.conversations.fold<int>(
    0,
    (int sum, item) => sum + item.unreadCount,
  );
});

/// 搜索历史
final searchHistoryProvider =
    StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
      return SearchHistoryNotifier();
    });

class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  void add(String keyword) {
    if (keyword.trim().isEmpty) return;
    final trimmed = keyword.trim();
    state = [
      trimmed,
      ...state.where((item) => item != trimmed).take(9),
    ].toList();
  }

  void remove(String keyword) {
    state = state.where((item) => item != keyword).toList();
  }

  void clear() {
    state = [];
  }
}

/// 返回键处理器注册器（供 RootBackButtonDispatcher 使用）
/// Shell 在 initState 时注册，路由器在收到系统返回键时调用
final mobileBackHandlerProvider =
    StateNotifierProvider<MobileBackHandlerNotifier, MobileBackHandlerState>((
      ref,
    ) {
      return MobileBackHandlerNotifier();
    });

class MobileBackHandlerState {
  final int currentBranch;
  final bool isLoggedIn;
  final void Function(int branch) handler;

  const MobileBackHandlerState({
    this.currentBranch = 0,
    this.isLoggedIn = false,
    required this.handler,
  });

  MobileBackHandlerState copyWith({
    int? currentBranch,
    bool? isLoggedIn,
    void Function(int branch)? handler,
  }) {
    return MobileBackHandlerState(
      currentBranch: currentBranch ?? this.currentBranch,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      handler: handler ?? this.handler,
    );
  }
}

class MobileBackHandlerNotifier extends StateNotifier<MobileBackHandlerState> {
  MobileBackHandlerNotifier()
    : super(const MobileBackHandlerState(handler: _noopHandler));

  static void _noopHandler(int branch) {}

  void register(void Function(int branch) handler) {
    state = state.copyWith(handler: handler);
  }

  void updateState({required int currentBranch, required bool isLoggedIn}) {
    state = state.copyWith(
      currentBranch: currentBranch,
      isLoggedIn: isLoggedIn,
    );
  }
}
