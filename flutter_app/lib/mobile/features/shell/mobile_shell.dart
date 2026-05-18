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

/// 搴曢儴瀵艰埅鏍忔樉绀?闅愯棌鐘舵€佸叏灞€ ChangeNotifier
/// 棣栭〉鍚戜笂婊氬姩鏃堕殣钘忥紝鍚戜笅婊氬姩鏃舵樉绀?
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

/// 绉诲姩绔富 Shell
/// 鍖呭惈搴曢儴 Tab 瀵艰埅鏍忥紙Twitter 椋庢牸锛氱函鐧借儗鏅?+ 椤堕儴 0.5px 缁嗙嚎锛屾棤闃村奖锛?
/// 鏀寔锛氬乏鍙虫粦鍔ㄥ垏鎹?Tab銆侀椤垫粦鍔ㄦ椂鑷姩鏀惰捣搴曢儴鏍忋€侀€氱煡绾㈢偣 Badge
class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// 鏈櫥褰曟椂搴曢儴鏍忓彧鏈?3 椤癸紙棣栭〉/娑堟伅/鎴戠殑锛夛紝瀵瑰簲 branch 0銆?銆?锛涖€屾牎鍥€嶄粎瀵瑰凡鐧诲綍鐢ㄦ埛灞曠ず銆?
  static int _displayIndexForBranch(bool loggedIn, int branchIndex) {
    return branchIndex.clamp(0, 2);
  }

  static int _branchIndexForDisplay(bool loggedIn, int displayIndex) {
    return displayIndex.clamp(0, 2);
  }

  @override
  ConsumerState<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<MobileShell>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  /// 璁板綍鏄惁宸叉彁绀?鍐嶆寜涓€娆￠€€鍑?
  bool _backHintShown = false;

  /// PageView 鎺у埗鍣紙鐢ㄤ簬宸﹀彸婊戝姩鍒囨崲 Tab锛?
  late final PageController _pageController;

  /// 搴曢儴鏍忓姩鐢?
  late final AnimationController _navAnimController;
  late final Animation<double> _navSlideAnim;

  /// 褰撳墠娲昏穬 display index锛堢敤浜庡悓姝?PageView锛?
  int _currentDisplayIndex = 0;

  /// 缂撳瓨褰撳墠鐧诲綍鎬佸拰 branch锛堢敤浜庡湪鍥炶皟涓闂渶鏂板€硷級
  bool _loggedIn = false;
  int _currentBranch = 0;
  bool _didPrefetchUnread = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _currentDisplayIndex = widget.navigationShell.currentIndex;
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
    // App 鍒囧洖鍓嶅彴鏃堕噸缃€€鍑烘彁绀虹姸鎬?
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

  /// 鍒囨崲鍒版寚瀹?Tab
  void _switchToTab(int displayIndex) {
    if (displayIndex == _currentDisplayIndex) return;

    _currentDisplayIndex = displayIndex;

    final target = MobileShell._branchIndexForDisplay(_loggedIn, displayIndex);

    widget.navigationShell.goBranch(
      target,
      initialLocation: target == widget.navigationShell.currentIndex,
    );
  }

  /// PageView 婊戝姩缁撴潫鍚庯紝鍚屾 GoRouter 璺敱鐘舵€?
  void _onPageViewIdle(int index) {
    _currentDisplayIndex = index;
    BottomNavVisibilityNotifier.instance.show();

    final target = MobileShell._branchIndexForDisplay(_loggedIn, index);
    if (target == widget.navigationShell.currentIndex) return;

    widget.navigationShell.goBranch(target, initialLocation: false);

    // GoRouter 鏇存柊 navigationShell.currentIndex 鍚庯紝鍚屾 PageView
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final expectedDisplay = MobileShell._displayIndexForBranch(
        _loggedIn,
        target,
      );
      if (_pageController.hasClients &&
          _pageController.page?.round() != expectedDisplay) {
        _pageController.jumpToPage(expectedDisplay);
      }
    });
  }

  /// 閫€鍑哄簲鐢?
  void _exitApp() {
    if (Platform.isAndroid) {
      SystemNavigator.pop();
    } else {
      exit(0);
    }
  }

  /// 婊氬姩棣栭〉鍒伴《閮?
  void _scrollHomeToTop() {
    ref.read(scrollToTopTriggerProvider.notifier).state =
        DateTime.now().millisecondsSinceEpoch;
  }

  /// 澶勭悊杩斿洖閿紙浣跨敤浼犲叆鐨?branch 鍊硷紝鑰岄潪闂寘鎹曡幏锛?
  void _handleBackPress(int branch) {
    if (!mounted) return;

    if (branch == 0) {
      // 棣栭〉锛氭鏌?Navigator 鏄惁鍙?pop锛堟槸鍚︽湁瀛愰〉闈級
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
      // 娑堟伅/鏍″洯/鎴戠殑锛氱涓€娆″垏鍥為椤碉紝绗簩娆￠€€鍑?
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

    // 鍦?build 鏈€寮€濮嬪悓姝ユ渶鏂板€硷紝纭繚 BackButtonListener 鍥炶皟鎷垮埌姝ｇ‘鐨?branch
    _loggedIn = AuthStore.instance.isAuthenticated;
    _currentBranch = widget.navigationShell.currentIndex;
    if (_loggedIn && !_didPrefetchUnread) {
      Future<void>.microtask(() => _prefetchUnreadStateIfNeeded());
    } else if (!_loggedIn && _didPrefetchUnread) {
      _didPrefetchUnread = false;
    }

    final displayIndex = MobileShell._displayIndexForBranch(
      _loggedIn,
      _currentBranch,
    );

    // 淇濇寔 PageView 鍚屾
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

    // BackButtonListener 浼樺厛浜?go_router 璺敱鍣ㄦ帴鏀?Android 杩斿洖閿€?
    // go_router 14 鐨?RouterDelegate.popRoute() 涓嶇粡杩?Navigator.maybePop()锛?
    // 鍥犳 PopScope 鏃犳硶鎷︽埅 Shell 灞傜骇鐨勮繑鍥為敭锛屽繀椤讳娇鐢?BackButtonListener銆?
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

        // 鍚﹀垯鐢?Shell 鎺ョ锛屾墽琛岃嚜瀹氫箟杩斿洖閫昏緫
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
                tabCount: 3,
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
