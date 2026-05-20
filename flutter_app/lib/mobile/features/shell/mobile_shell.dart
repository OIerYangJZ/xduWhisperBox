import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:xdu_treehole_web/core/auth/auth_store.dart';

import '../../core/theme/mobile_theme.dart';
import '../../core/theme/mobile_colors.dart';
import '../../core/state/mobile_providers.dart';
import '../home/home_page.dart';
import '../messages/messages_page.dart';
import '../profile/profile_page.dart';

/// 底部导航栏显示/隐藏状态。
/// 首页向上滚动时隐藏，向下滚动时显示。
class BottomNavVisibilityNotifier extends ChangeNotifier {
  bool _visible = true;
  bool get visible => _visible;

  void show() {
    if (!_visible) {
      _visible = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_visible) {
      _visible = false;
      notifyListeners();
    }
  }

  static final BottomNavVisibilityNotifier instance =
      BottomNavVisibilityNotifier._();
  BottomNavVisibilityNotifier._();
}

/// 移动端主 Shell。
/// 包含首页/消息/我的三个底部 Tab，支持左右滑动切换和未读红点。
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int tabCount = 3;

  static int _displayIndexForBranch(int branchIndex) {
    return branchIndex.clamp(0, tabCount - 1);
  }

  static int _branchIndexForDisplay(int displayIndex) {
    return displayIndex.clamp(0, tabCount - 1);
  }

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 是否已经提示“再按一次退出”。
  bool _backHintShown = false;

  /// 用于左右滑动切换 Tab。
  late final PageController _pageController;

  /// 底部导航栏隐藏动画。
  late final AnimationController _navAnimController;
  late final Animation<double> _navSlideAnim;

  /// 当前激活的 Tab index。
  int _currentDisplayIndex = 0;

  /// 缓存当前登录态和 branch，确保返回键回调读到最新状态。
  bool _loggedIn = false;
  int _currentBranch = 0;
  bool _didPrefetchUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentDisplayIndex = MobileShell._displayIndexForBranch(
      widget.navigationShell.currentIndex,
    );
    _pageController = PageController(initialPage: _currentDisplayIndex);

    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _navSlideAnim = Tween<double>(begin: 0, end: 72).animate(
      CurvedAnimation(parent: _navAnimController, curve: Curves.easeInOut),
    );

    BottomNavVisibilityNotifier.instance.addListener(_onNavVisibilityChanged);
    Future<void>.microtask(() => _prefetchUnreadStateIfNeeded());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // App 切回前台时重置退出提示状态。
    if (state == AppLifecycleState.resumed) {
      _backHintShown = false;
      Future<void>.microtask(
        () => _prefetchUnreadStateIfNeeded(forceRefresh: true),
      );
    }
  }

  Future<void> _prefetchUnreadStateIfNeeded({bool forceRefresh = false}) async {
    if (!AuthStore.instance.isAuthenticated) {
      _didPrefetchUnread = false;
      return;
    }
    if (_didPrefetchUnread && !forceRefresh) {
      return;
    }
    _didPrefetchUnread = true;
    try {
      await ref.read(messagesControllerProvider.notifier).loadInitial();
    } catch (_) {}
  }

  void _onNavVisibilityChanged() {
    if (!mounted) return;
    if (BottomNavVisibilityNotifier.instance.visible) {
      _navAnimController.reverse();
    } else {
      _navAnimController.forward();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    BottomNavVisibilityNotifier.instance.removeListener(
      _onNavVisibilityChanged,
    );
    _pageController.dispose();
    _navAnimController.dispose();
    super.dispose();
  }

  /// 切换到指定 Tab。
  void _switchToTab(int displayIndex) {
    if (displayIndex == _currentDisplayIndex) return;

    _currentDisplayIndex = displayIndex;

    final target = MobileShell._branchIndexForDisplay(displayIndex);

    widget.navigationShell.goBranch(
      target,
      initialLocation: target == widget.navigationShell.currentIndex,
    );
  }

  /// PageView 滑动结束后同步 GoRouter 路由状态。
  void _onPageViewIdle(int index) {
    _currentDisplayIndex = index;
    BottomNavVisibilityNotifier.instance.show();

    final target = MobileShell._branchIndexForDisplay(index);
    if (target == widget.navigationShell.currentIndex) return;

    widget.navigationShell.goBranch(target, initialLocation: false);

    // GoRouter 更新 navigationShell.currentIndex 后，同步 PageView。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final expectedDisplay = MobileShell._displayIndexForBranch(target);
      if (_pageController.hasClients &&
          _pageController.page?.round() != expectedDisplay) {
        _pageController.jumpToPage(expectedDisplay);
      }
    });
  }

  /// 退出应用。
  void _exitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  /// 滚动首页到顶部。
  void _scrollHomeToTop() {
    ref.read(scrollToTopTriggerProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch;
  }

  /// 处理系统返回键。
  void _handleBackPress(int branch) {
    if (!mounted) return;

    if (branch == 0) {
      // 首页：先检查 Navigator 是否可以 pop。
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        navigator.pop();
        return;
      }

      if (_backHintShown) {
        _exitApp();
      } else {
        _backHintShown = true;
        _scrollHomeToTop();
        _showExitHint();
        Future<void>.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _backHintShown = false;
        });
      }
    } else {
      // 消息/我的：第一次回首页，第二次退出。
      if (_backHintShown) {
        _exitApp();
      } else {
        _backHintShown = true;
        _switchToTab(0);
        _showExitHint();
        Future<void>.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) _backHintShown = false;
        });
      }
    }
  }

  void _showExitHint() {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('再按一次退出应用'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messageUnreadCount = ref.watch(messageUnreadCountProvider);
    final notificationsState = ref.watch(notificationsControllerProvider);
    final notificationUnreadCount = notificationsState.unreadCount;

    // 在 build 开始同步最新值，确保 BackButtonListener 回调拿到正确 branch。
    _loggedIn = AuthStore.instance.isAuthenticated;
    _currentBranch = widget.navigationShell.currentIndex;
    if (_loggedIn && !_didPrefetchUnread) {
      Future<void>.microtask(() => _prefetchUnreadStateIfNeeded());
    } else if (!_loggedIn && _didPrefetchUnread) {
      _didPrefetchUnread = false;
    }

    final displayIndex = MobileShell._displayIndexForBranch(_currentBranch);

    // 保持 PageView 同步。
    final currentPage = _pageController.hasClients
        ? (_pageController.page?.round() ?? 0)
        : 0;
    if (currentPage != displayIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(displayIndex);
        }
      });
    }

    // BackButtonListener 优先于 go_router 路由器接收 Android 返回键。
    // go_router 14 的 RouterDelegate.popRoute() 不经过 Navigator.maybePop()，
    // 因此 PopScope 无法拦截 Shell 层级的返回键，必须使用 BackButtonListener。
    final branchForCallback = _currentBranch;

    return BackButtonListener(
      onBackButtonPressed: () async {
        // 先处理通过 Navigator.push 打开的页面（如首页图片预览）。
        final NavigatorState rootNavigator = Navigator.of(
          context,
          rootNavigator: true,
        );
        if (rootNavigator.canPop()) {
          final handled = await rootNavigator.maybePop();
          if (handled) return true;
        }
        final NavigatorState navigator = Navigator.of(context);
        if (navigator.canPop()) {
          final handled = await navigator.maybePop();
          if (handled) return true;
        }

        // go_router 仍有可弹出的页面时，交给路由器处理。
        if (context.canPop()) return false;

        // 否则由 Shell 接管，执行自定义返回逻辑。
        _handleBackPress(branchForCallback);
        return true;
      },
      child: Scaffold(
        body: Stack(
          children: [
            AnimatedBuilder(
              animation: _navSlideAnim,
              builder: (context, child) {
                final bottomInset = MediaQuery.paddingOf(context).bottom;
                final navBarHeight = 60.0 + bottomInset;
                final padding = (navBarHeight - _navSlideAnim.value).clamp(
                  0.0,
                  navBarHeight,
                );
                return Padding(
                  padding: EdgeInsets.only(bottom: padding),
                  child: child!,
                );
              },
              child: _TabBody(
                pageController: _pageController,
                tabCount: MobileShell.tabCount,
                onPageIdle: _onPageViewIdle,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _BottomNavBar(
                currentIndex: displayIndex,
                messageUnreadCount: messageUnreadCount,
                notificationUnreadCount: notificationUnreadCount,
                onTap: _switchToTab,
                slideAnim: _navSlideAnim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// PageView Tab 鍐呭鍖?
class _TabBody extends StatefulWidget {
  const _TabBody({
    required this.pageController,
    required this.tabCount,
    required this.onPageIdle,
  });

  final PageController pageController;
  final int tabCount;
  final void Function(int) onPageIdle;

  @override
  State<_TabBody> createState() => _TabBodyState();
}

class _TabBodyState extends State<_TabBody> {
  int _lastNotifiedPage = 0;

  @override
  void initState() {
    super.initState();
    _lastNotifiedPage = widget.pageController.initialPage;
    widget.pageController.addListener(_onPageIdle);
  }

  @override
  void dispose() {
    widget.pageController.removeListener(_onPageIdle);
    super.dispose();
  }

  void _onPageIdle() {
    final page = widget.pageController.page?.round() ?? 0;
    if (page != _lastNotifiedPage) {
      _lastNotifiedPage = page;
      widget.onPageIdle(page);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: widget.pageController,
      itemCount: widget.tabCount,
      physics: const BouncingScrollPhysics(),
      itemBuilder: (context, index) {
        switch (index) {
          case 0:
            return _HomeTabWrapper(
              tabCount: widget.tabCount,
              pageController: widget.pageController,
            );
          case 1:
            return const MessagesPage();
          case 2:
            return const ProfilePage();
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

/// 棣栭〉 Tab锛氱洃鍚粴鍔ㄦ柟鍚戜互鎺у埗搴曢儴鏍忔樉闅?+ overscroll 鍒囨崲 Tab
class _HomeTabWrapper extends StatefulWidget {
  final int tabCount;
  final PageController pageController;

  const _HomeTabWrapper({required this.tabCount, required this.pageController});

  @override
  State<_HomeTabWrapper> createState() => _HomeTabWrapperState();
}

class _HomeTabWrapperState extends State<_HomeTabWrapper> {
  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // overscroll 鍚戝彸婊戝姩鏃跺垏鎹㈠埌涓婁竴涓?Tab
        if (notification is OverscrollNotification) {
          if (notification.velocity < -200) {
            final currentPage = widget.pageController.page?.round() ?? 0;
            if (currentPage > 0) {
              widget.pageController.animateToPage(
                currentPage - 1,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
          return true;
        }
        return false;
      },
      child: const HomePage(),
    );
  }
}

/// 搴曢儴瀵艰埅鏍忥紙鏀寔鍔ㄧ敾鏄鹃殣锛?
class _BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final int messageUnreadCount;
  final int notificationUnreadCount;
  final void Function(int) onTap;
  final Animation<double> slideAnim;

  const _BottomNavBar({
    required this.currentIndex,
    required this.messageUnreadCount,
    required this.notificationUnreadCount,
    required this.onTap,
    required this.slideAnim,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBackground = isDark ? Colors.black : Colors.white;
    final selectedIconColor = MobileTheme.primaryOf(context);

    return AnimatedBuilder(
      animation: slideAnim,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, slideAnim.value),
          child: child,
        );
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: navBackground,
          border: Border(top: BorderSide(color: colors.divider, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.home_outlined,
                selectedIcon: Icons.home_rounded,
                label: '首页',
                isSelected: currentIndex == 0,
                iconSize: 28,
                onTap: () => onTap(0),
                selectedColor: selectedIconColor,
              ),
              _NavItem(
                icon: Icons.chat_bubble_outline,
                selectedIcon: Icons.chat_bubble_rounded,
                label: '消息',
                isSelected: currentIndex == 1,
                iconSize: 28,
                badgeCount: messageUnreadCount,
                onTap: () => onTap(1),
                selectedColor: selectedIconColor,
              ),
              _NavItem(
                icon: Icons.person_outline,
                selectedIcon: Icons.person_rounded,
                label: '我的',
                isSelected: currentIndex == 2,
                iconSize: 28,
                badgeCount: notificationUnreadCount,
                badgeIsNotification: true,
                onTap: () => onTap(2),
                selectedColor: selectedIconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 鍗曚釜瀵艰埅椤癸紙鍥炬爣 + 鏍囩锛?8px 澶у浘鏍囷紝瀛楅噸鍔犵矖锛?
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final double iconSize;
  final int badgeCount;
  final bool badgeIsNotification;
  final VoidCallback onTap;
  final Color selectedColor;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.iconSize,
    this.badgeCount = 0,
    this.badgeIsNotification = false,
    required this.onTap,
    required this.selectedColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = MobileColors.of(context);
    final color = isSelected ? selectedColor : colors.textSecondary;

    Widget iconWidget = Icon(
      isSelected ? selectedIcon : icon,
      size: iconSize,
      color: color,
    );

    if (badgeCount > 0) {
      iconWidget = Badge(
        isLabelVisible: true,
        smallSize: 8,
        label: Text(
          badgeCount > 99 ? '99+' : badgeCount.toString(),
          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700),
        ),
        child: iconWidget,
      );
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget,
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
