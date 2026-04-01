# See电（西电树洞）项目文档

## 1. 项目概述

**See电**（西电树洞）是一个面向西安电子科技大学校内用户的匿名社区应用，采用 Flutter 跨端技术栈构建，同时支持 Web 端和移动端（Android / iOS）。

### 应用定位

- 为校内同学提供一个自由、平等的交流空间
- 支持多种话题频道，满足学习、生活、情感、吐槽等场景需求
- 强调社区治理能力，配备完善的内容审核、举报处理和用户管理体系

### 核心功能（Web 端 + 移动端）

**社区交流**

- 帖子发布与浏览（支持频道分类、多图上传）
- 评论与回复：嵌套评论树（最多3层缩进），回复 `@alias` 提醒
- 点赞、收藏与阅读量：阅读量通过独立端点计入热度算法（防刷：每用户每帖每天计1次）
- 搜索与筛选（关键词、频道、状态、有图、可私信等条件）
- 热度算法：`likes × 2 + comments × 3 + viewCount - ts/1e9`

**用户体系**

- 校内邮箱注册与登录（学号 + 密码）；移动端：统一身份认证（学号 + 统一认证密码，`@stu.xidian.edu.cn` 自动拼接）
- 用户等级体系：一级用户（享有直接置顶帖子权限）、二级用户
- 匿名发帖：前台完全匿名，管理员后台可追溯真实账号
- 个人中心（资料查看、头像上传、我的帖子、我的评论、我的收藏、我的举报）
- 账号注销申请（双重确认 + 密码验证）

**社交互动**

- 私信功能：私信申请 → 对方同意 → 双向会话建立
- 私信直接进入（微信模式）：无需申请流程，直接创建/进入会话
- 会话屏蔽（拉黑）：屏蔽后禁止继续发起私信和发送消息
- 消息未读数与已读状态；长按气泡操作菜单（复制/删除）
- 关注/粉丝系统：互相关注标记为好友

**通知中心**

- 评论通知、回复通知、点赞通知、收藏通知
- 举报处理结果通知
- 系统公告通知
- 未读数提示与一键已读

**管理员后台**

- 多管理员分级：一级管理员（完整权限）、二级管理员（受限权限）
- 内容审核与批量审核
- 图片审核
- 举报处理
- 用户管理（账号状态管理、注销/恢复）
- 申诉处理
- 数据导出（CSV）
- 敏感词与系统配置管理
- 帖子置顶审批
- 一级用户升级申请审批

**合规与说明**

- 用户协议、隐私政策、社区规范、举报说明

**移动端专属功能**

- **登录/注册页**（`XduLoginPage`）：统一身份认证入口，管理登录和 Admin 登录两个入口；登录成功后一键同步登录凭证、主题、语言到 XDYou 子 App
- **设置主页**（`SettingsMainPage`）：账号安全 / 隐私开关（陌生私信、联系方式可见）/ 通知 / 外观（主题、语言）/ 账号注销双重确认流程
- **XDYou 校园服务**（嵌入底部「校园」Tab，仅登录可见）：课表、成绩、电费、空教室、图书馆、运动打卡、宿舍水费等
- **树洞→XDYou 状态同步**：主 App 的主题（跟随系统/浅色/深色）、语言（简体中文/繁體中文/English）、登录凭证通过 SharedPreferences 单向同步到 XDYou 子 App；XDYou `ThemeController` 优先读取 `treehole_*` 覆写 key，fallback 到原生偏好
- **帖子详情页**（`PostDetailPage`）：操作栏（点赞/收藏/评论/分享）内置于正文与评论区之间，支持嵌套评论树、举报流程、关注/私信作者、表情输入；评论区跳转使用 `Scrollable.ensureVisible` 精确滚动
- **表情输入组件**（`EmojiPickerBar`）：96 个常用 emoji 网格，与键盘互斥（展开时收起键盘防止布局空白）；`insertEmoji()` 方法通过 `GlobalKey` 暴露给父组件调用
- **消息页**（`MessagesPage`）：会话列表直接展示，无 Tab 切换；头像使用 `CachedNetworkImage` 正确加载；会话列表左滑删除；聊天页菜单提供屏蔽/解除屏蔽入口

---

## 2. 目录结构和技术说明

```
xduWhisperBox/
├── backend/                        # Python 后端（模块化架构）
│   ├── server.py                   # 核心入口 (~745行)，路由分发 + 服务器启动
│   ├── _globals.py                 # 全局状态单点：配置常量 + 运行时对象
│   ├── sql_repository.py           # SQLite schema、初始化、持久化逻辑 (~1712行)
│   ├── object_storage.py           # 对象存储（本地 / S3 兼容）(~258行)
│   ├── reset_db.py                 # 数据库重置脚本
│   ├── migrate_json_to_sql.py      # JSON → MySQL/PostgreSQL 迁移脚本
│   ├── helpers/                    # 通用辅助函数（跨 handler/service 复用）
│   │   ├── __init__.py             # barrel file，重新导出所有 helpers
│   │   ├── _auth_helpers.py        # 密码哈希、邮箱验证、ID 解析
│   │   ├── _datetime_helpers.py    # 时间/时区处理
│   │   ├── _http_helpers.py        # HTTP 响应（json_error、send_json 等）
│   │   ├── _mailer.py              # 邮件发送（验证邮件、密码重置邮件）
│   │   └── _rate_limit.py          # 限流、IP 检查、文本风险评估
│   ├── handlers/                   # HTTP 请求处理层（按功能域拆分）
│   │   ├── __init__.py             # barrel file，重新导出 ~60 个 handle_* 函数
│   │   ├── _auth_handler.py        # 认证：登录/注册/登出/验证码/密码重置
│   │   ├── _post_handler.py        # 帖子：CRUD/点赞/收藏/举报/申诉/置顶申请
│   │   ├── _comment_handler.py     # 评论：创建/删除；账号：注销申请/等级升级
│   │   ├── _message_handler.py     # 私信：申请/接受/拒绝/会话/消息/屏蔽
│   │   ├── _user_handler.py        # 用户：个人资料/关注/粉丝/好友
│   │   ├── _notification_handler.py # 通知：列表/标记已读/全部已读
│   │   ├── _admin_handler.py       # 管理后台：审核/举报/用户/配置/公告等
│   │   ├── _upload_handler.py       # 文件上传：头像上传/图片上传
│   │   └── _static_handler.py      # 静态文件：存储文件读取/Web 兜底
│   ├── services/                   # 业务逻辑层（数据操作 + 业务规则）
│   │   ├── __init__.py             # barrel file，重新导出所有 service 函数
│   │   ├── _db_service.py          # 数据库操作：查询/序列化/管理员构建函数
│   │   └── _user_service.py        # 用户业务：通知创建/会话同步/数据规范化
│   ├── sql/                        # SQL schema 文件
│   │   ├── schema_mysql.sql
│   │   └── schema_postgresql.sql
│   └── tests/                      # 后端单元测试（pytest）
├── lib/                            # Flutter Web 前端
│   ├── core/                       # 核心基础设施
│   │   ├── auth/                   # 鉴权相关（AuthStore、AdminAuthStore）
│   │   ├── config/                 # 配置（AppConfig、API_BASE_URL 解析）
│   │   ├── emoji/                  # 表情目录 + 用户偏好
│   │   ├── media/                  # 媒体处理（图片选择器 Web/Mobile 条件编译）
│   │   ├── navigation/             # 导航（URL 状态管理）
│   │   ├── network/                # 网络请求（ApiClient、ApiEndpoints、JsonUtils）
│   │   ├── state/                  # 状态管理（AppProviders）
│   │   ├── theme/                  # 主题（AppTheme + SharedColors 统一跨端颜色）
│   │   └── utils/                  # 工具函数（Web 文件下载、时间格式化）
│   ├── data/                       # Mock 数据
│   ├── features/                   # 功能模块
│   │   ├── admin/                  # 管理员后台
│   │   ├── auth/                   # 登录/注册/验证码/密码重置
│   │   ├── favorites/              # 收藏
│   │   ├── feed/                   # 信息流
│   │   ├── legal/                  # 合规说明页（用户协议/隐私政策等）
│   │   ├── me/                     # 个人中心
│   │   ├── messages/               # 私信（会话列表 + 聊天）
│   │   ├── notifications/          # 通知中心
│   │   ├── post/                   # 发帖/帖子详情
│   │   └── search/                # 搜索
│   ├── models/                     # 数据模型
│   │   ├── admin/                 # 管理员模型子目录（9 个独立文件）
│   │   │   ├── admin_shared_helpers.dart
│   │   │   ├── admin_overview_models.dart
│   │   │   ├── admin_review_models.dart
│   │   │   ├── admin_report_models.dart
│   │   │   ├── admin_user_models.dart
│   │   │   ├── admin_system_models.dart
│   │   │   ├── admin_account_models.dart
│   │   │   ├── admin_appeal_models.dart
│   │   │   └── admin_export_models.dart
│   │   ├── admin_models.dart       # admin barrel file（重新导出）
│   │   └── [其他模型]              # post_item、comment_item、user_profile 等
│   ├── repositories/               # Repository 层（7 个文件）
│   └── widgets/                    # 公共组件（4 个文件）
├── lib/mobile/                     # Flutter 移动端（Android / iOS）
│   ├── core/                       # 核心基础设施
│   │   ├── config/                 # MobileConfig（移动端 API 地址默认值）
│   │   ├── navigation/             # 移动端路由（app_router）
│   │   ├── state/                  # AppSettingsStore + MobileProviders
│   │   │   ├── app_settings_store.dart  # 主题/语言持久化 + XDYou 同步触发
│   │   │   └── mobile_providers.dart    # Riverpod Provider 统一入口
│   │   ├── theme/                  # MobileTheme + SharedColors
│   │   └── utils/                  # 工具函数（时间格式化 time_utils）
│   ├── features/                   # 功能模块（移动端独立实现）
│   │   ├── admin/                  # 管理员后台（移动端）
│   │   ├── auth/
│   │   │   └── login_page.dart     # XduLoginPage：统一身份认证登录入口
│   │   ├── feed/                   # 首页信息流
│   │   ├── messages/              # 消息页（会话列表 + 聊天）
│   │   ├── notifications/          # 通知中心
│   │   ├── post/
│   │   │   ├── comment_input_bar.dart  # 评论输入栏（emoji 插入 API）
│   │   │   └── post_detail_page.dart   # 帖子详情页（嵌套评论树 + 操作栏）
│   │   ├── profile/
│   │   │   └── settings_main_page.dart # 设置主页（主题/语言/隐私/账号注销）
│   │   └── widgets/                # 移动端公共组件（AvatarWidget 等）
│   ├── integrations/               # XDYou 集成层（移动端，仅移动端打包）
│   │   ├── xdyou_bootstrap.dart     # 真机：初始化 XDYou + 注册同步函数
│   │   ├── xdyou_bootstrap_stub.dart # Web stub：所有函数为空操作
│   │   └── xdyou_sync_bridge.dart    # 函数指针桥接层（打破循环 import）
│   ├── main.dart                  # 移动端入口（初始化所有 Store + runApp）
│   └── lib_mobile.dart            # 移动端 barrel file
├── packages/                       # 可选本地依赖（gitignore，见 scripts/setup_xdyou.sh）
│   └── traintime_pda/              # XDYou 子 App（移动端嵌入，MPL-2.0）
│       └── lib/
│           ├── controller/
│           │   └── theme_controller.dart  # XDYou 主题/语言控制器
│           │                                # （读取 treehole_* 覆写 key，fallback 原生偏好）
│           ├── page/
│           │   ├── homepage/
│           │   │   ├── home_card_padding.dart  # 通用卡片样式扩展（OutlinedButton 包装）
│           │   │   └── homepage.dart            # XDYou 主仪表盘（课表/电费/图书馆等）
│           │   └── setting/
│           │       └── setting.dart             # XDYou 设置页（主题/语言/账号/缓存等）
│           └── themes/
│               └── color_seed.dart              # XDYou 品牌色定义（pdaTealLight/Dark
│                                                 # 与树洞 SharedColors.primary 对齐）
├── scripts/                        # 部署与构建脚本
│   ├── build_web_beta.sh           # 内测 Web 构建
│   ├── build_web_production.sh     # 生产 Web 构建
│   ├── deploy_tencent.sh           # 腾讯云部署
│   ├── health_check.sh             # 健康检查
│   ├── install_tencent_host.sh     # 服务器环境安装
│   ├── package_release.sh          # 发布包打包
│   ├── rollback.sh                 # 版本回滚
│   ├── run_backend_beta.sh         # 内测后端启动
│   ├── setup_xdyou.sh              # 拉取 traintime_pda 至 packages/（移动端嵌入 XDYou）
│   └── version.sh                  # 版本信息生成
├── .github/
│   └── workflows/
│       ├── dart.yml               # Flutter CI（flutter analyze + flutter test）
│       └── python.yml              # Python CI（pytest 后端测试）
├── Dockerfile                      # 后端多阶段 Docker 构建
├── docker-compose.yml              # 服务编排（backend + nginx）
├── docker-compose.prod.yml         # 生产环境覆盖（TLS 扩展点）
├── deploy/                         # 部署配置
│   ├── production/                 # 生产环境配置
│   └── tencent/                    # 腾讯云配置
├── docs/                           # 文档
├── test/                           # 前端测试
├── web/                            # Web 静态资源（index.html、manifest.json）
├── pubspec.yaml                    # Flutter 依赖配置（Dart SDK >=3.8.0）
├── analysis_options.yaml           # Dart Lint 配置（排除 traintime_pda 目录）
├── .gitignore                      # Git 忽略配置
└── README.md                       # 项目主说明
```

### 后端模块架构图

```
server.py (~745行)
  │
  ├── _globals.py                  # 全局状态单点（运行时对象 + 配置常量）
  │
  ├── helpers/                     # 通用工具层
  │     ├── _auth_helpers.py      # 密码哈希、邮箱验证、ID 解析
  │     ├── _datetime_helpers.py   # 时间/时区处理
  │     ├── _http_helpers.py       # HTTP 响应（json_error、send_json 等）
  │     ├── _mailer.py             # 邮件发送
  │     └── _rate_limit.py         # 限流、IP 检查、文本风险评估
  │
  ├── services/                    # 业务逻辑层
  │     ├── _db_service.py         # 数据库查询、序列化、管理员构建函数
  │     └── _user_service.py       # 用户业务规则、通知创建、会话同步
  │
  └── handlers/                    # HTTP 处理层（60+ handle_* 函数）
        ├── _auth_handler.py       # 认证：登录/注册/登出/验证码/密码重置
        ├── _post_handler.py       # 帖子：CRUD/点赞/收藏/举报/申诉/置顶申请
        ├── _comment_handler.py    # 评论创建/删除；账号注销申请/等级升级
        ├── _message_handler.py     # 私信：申请/接受/拒绝/会话/消息/屏蔽
        ├── _user_handler.py        # 用户：个人资料/关注/粉丝/好友
        ├── _notification_handler.py # 通知：列表/标记已读/全部已读
        ├── _admin_handler.py      # 管理后台：审核/举报/用户/配置/公告等
        ├── _upload_handler.py      # 文件上传：头像上传/图片上传
        └── _static_handler.py     # 静态文件：存储文件读取/Web 兜底
```

### 移动端模块架构图

```
lib/mobile/main.dart
  │
  ├── 初始化阶段（按顺序）
  │     ├── AuthStore.instance.init()        # 恢复登录态
  │     ├── AdminAuthStore.instance.init()   # 恢复管理员登录态
  │     ├── EmojiSettingsStore.instance      # 表情偏好
  │     └── AppSettingsStore.instance.init()  # 主题/语言持久化恢复
  │
  └── XduTreeholeMobileApp (ConsumerWidget)
        │
        ├── appSettingsProvider (ChangeNotifierProvider)
        │     └─ 驱动 MaterialApp.router 的 themeMode / locale
        │
        ├── MobileProviders（Re-exports lib/core/state/ 的所有 Provider）
        │     ├─ authRepositoryProvider
        │     ├─ feedControllerProvider
        │     ├─ notificationsControllerProvider
        │     ├─ messagesControllerProvider
        │     └─ appSettingsProvider
        │
        ├── app_router（GoRouter）
        │     ├─ /auth/login   → XduLoginPage
        │     ├─ /             → MobileShell (4-Tab: 首页/消息/校园/我的)
        │     ├─ /xdyou       → buildXdyouApp()（嵌入 XDYou MyApp）
        │     └─ ...其他路由...
        │
        └── xdyou_bootstrap.dart（条件导入，仅移动端生效）
              │
              ├─ ensureXdyouEmbedInitialized()
              │     ├─ 初始化 SharedPreferencesWithCache
              │     ├─ Get.put(ThemeController())
              │     └─ registerXdyouSyncFunctions(syncTheme, syncLocale)
              │
              ├─ initXdyouNotificationServices()
              │     └─ 初始化所有 NotificationServiceRegistrar
              │
              └─ buildXdyouApp()
                    └─ MyApp(isFirst: !loggedIn && xdyouIsFirstLogin())

状态同步流向（AppSettingsStore → XDYou）：

  用户变更主题/语言
       │
       ▼
  AppSettingsStore.setBrightness() / setLocale()
       │
       ├─→ SharedPreferences['treehole_brightness'] = index
       ├─→ SharedPreferences['treehole_localization'] = locale
       │
       ▼
  callSyncThemeToXdyou() / callSyncLocaleToXdyou()
       │  (xdyou_sync_bridge.dart 函数指针)
       ▼
  xdyou_bootstrap.dart 注册的 sync lambda
       │
       ├─→ SharedPreferences['color'] = seed
       └─→ ThemeController.updateTheme()
             ├─ 优先读取 treehole_brightness / treehole_color_seed / treehole_localization
             └─ fallback 到 XDYou 原生 Preference 值
```

---

## 3. 版本历史

| 版本号 | 更新日期 | 更新内容 |
|--------|----------|----------|
| 0.1.0+35 | 2026-04-01 | **Android Release 发布与下载链路**：管理员后台新增 Android Release 管理能力，支持上传 APK、维护 `versionName/versionCode`、文件大小、更新说明、下载链接与强制更新标记；后端补充 release 数据模型与 API；Web 端新增 Android 下载页与浏览器下载/选包辅助；登录页与个人页补充 Android 下载入口；补充 `android/key.properties.example`，统一团队发布签名配置 |
| 0.1.0+34 | 2026-04-01 | **设置页与致谢页整理**：移动端设置主页分组与入口信息优化，恢复完整开发者致谢名单与独立致谢页，便于对 XDYou 原作者与贡献者进行完整署名 |
| 0.1.0+33 | 2026-04-01 | **帖子详情与校园工具体验升级**：移动端帖子详情支持图片保存/复制、评论区间距与交互细节优化；通知页、个人页、设置页信息密度调整；XDYou 首页/工具箱补充常用地址配置并继续适配主 App 主题与导航结构 |
| 0.1.0+32 | 2026-03-31 ~ 2026-04-01 | **图片浏览与评论交互修复**：集中修复移动端帖子详情的图集滑动、评论操作气泡、图片导航与返回栈问题；恢复发帖页一级用户帖子置顶控制，提升帖子交互稳定性 |
| 0.1.0+31 | 2026-03-31 | **移动端通知设置正式打通**：后端补全 `notifyComment / notifyReply / notifyLike / notifyFavorite / notifyReportResult / notifySystem` 持久化字段与接口；移动端新增独立通知设置页，支持评论、回复、点赞、收藏、举报结果、系统通知逐项开关，并同步到 XDYou 子应用 |
| 0.1.0+30 | 2026-03-31 | **移动端深色模式支持**：新增 `MobileColors` (`lib/mobile/core/theme/mobile_colors.dart`) 作为 `ThemeExtension`，支持浅色/深色主题颜色动态切换；在 31 个移动端文件中将硬编码的 `MobileTheme.background/surface/textPrimary/textSecondary/textTertiary/divider` 替换为 `MobileColors.of(context).xxx` 动态引用；`MobileTheme.primary/accent/error/success/warning` 品牌色保持不变；所有嵌套私有 widget 的 `build()` 方法均添加了 `final colors = MobileColors.of(context);`；`flutter analyze` 零 error |
| 0.1.0+28 | 2026-03-30 | **移动端底部导航栏与 Tab 交互全面升级**：① 底部导航栏图标从默认尺寸增大到 **28px**，选中/未选中文案字重分别加粗到 `FontWeight.w700/w600`，高度从 60 增大到 68；② 消息 Tab 图标增加红色 Badge 点，未读数 > 0 时显示红色小圆点；③ 首页"我的"Tab 增加通知红点 Badge，显示未读通知数；④ 首页向上滑动帖子时自动隐藏底部导航栏，向下滑动时自动展开（`BottomNavVisibilityNotifier` 全局单例 ChangeNotifier + `AnimatedBuilder`）；⑤ 首页顶部导航栏添加 `titleSpacing: 0` 和 `systemOverlayStyle: SystemUiOverlayStyle.dark`，使标题更贴合左侧，状态栏更清晰；⑥ **左右滑动切换 Tab**：重构 `MobileShell` 为 PageView + 直接页面 Widget 结构（非 StatefulNavigationShell），支持首页 → 消息 → 校园 → 我的四个页面之间左右滑动切换；首页 overscroll（向上快速拖过顶部）自动切换到上一个 Tab；`flutter analyze` 零 error |
| 0.1.0+25 | 2026-03-30 | **登录页 UI 与交互修复**：① 密码输入框 `hintText` 改为"统一认证密码"（与学号框样式一致，均为浅灰 placeholder）；② 登录按钮下方提示文案改为"您的密码信息不会上传至任何服务器，仅存储在手机本地。"；③ 修复「帮助与反馈」按钮被父级 `CrossAxisAlignment.stretch` 撑满宽度导致点击区域异常的问题，包裹 `Align(alignment: Alignment.center)` 恢复自然宽度；`flutter analyze` 零 error；**删除注册功能**：移除移动端 `register_page.dart` 文件、`lib_mobile.dart` 中的 export 及 `app_router.dart` 中 `/auth/register` 路由；`flutter analyze` 零 error |
| 0.1.0+24 | 2026-03-30 | **树洞→XDYou 状态同步**：① 新建 `AppSettingsStore`（`lib/mobile/core/state/app_settings_store.dart`）管理主 App 主题亮度（`ThemeMode`）和语言（`Locale`）的持久化，单例模式；② `xdyou_bootstrap.dart` 新增 `TreeholeSharedKeys` 常量类（`treehole_brightness` / `treehole_color_seed` / `treehole_localization`）和三个同步函数（`syncTreeholeThemeToXdyou` / `syncTreeholeLanguageToXdyou` / `syncAllToXdyou`）；③ `ThemeController` 的 `updateTheme()` 优先读取 `treehole_*` 覆写 key，fallback 到 XDYou 原生偏好，实现单向覆写；④ `settings_main_page.dart` 新增「外观」区块，支持切换主题（跟随系统/浅色/深色）和语言（简体中文/繁體中文/English）；⑤ 登录页改用 `syncAllToXdyou` 一键同步全部状态；⑥ `main.dart` 初始化 `AppSettingsStore` 并驱动 `MaterialApp.router` 的 `themeMode`；`flutter analyze` 零 error |
| 0.1.0+23 | 2026-03-30 | **移动端帖子详情页优化**：① 将点赞/收藏/评论/分享操作栏从页面底部 Column 移至帖子内容与评论区之间（`_buildActionBar()` + `GlobalKey` 精确定位评论区）；评论区跳转逻辑改为 `_scrollToComments()` → `Scrollable.ensureVisible` 滚动到评论区标题；② 将表情输入框从 `CommentInputBar` 内部拆分独立为 `EmojiPickerBar` 组件；`PostDetailPage` 自己管理 `_showEmoji` 状态，`bottomNavigationBar` 中 `EmojiPickerBar` 位于 `CommentInputBar` 上方，弹出时从页面最底部往上展开；`_CommentInputBarState.insertEmoji()` 暴露给父组件调用；③ 修复表情栏展开时收起键盘（`_FocusScope.of(context).unfocus()`），防止键盘和表情栏同时出现导致布局空白；④ 评论头像点击添加 `HitTestBehavior.opaque`，修复点击不跳转个人主页的问题；`flutter analyze` 零 error |
| 0.1.0+21 | 2026-03-29 | **修复 traintime_pda 子 App 中文字体不显示**：`packages/traintime_pda/lib/main.dart` 移除不可靠的 `chinese_font_library` 的 `useSystemChineseFont()` 调用（在嵌套 MaterialApp 场景下 platform channel 返回空字体名导致所有文字无字体渲染）；改为在 `DefaultTextStyle.merge` 中显式指定 `fontFamily: 'Noto Sans SC'`（Android 系统内置思源黑体）；`flutter analyze` 零 error |
| 0.1.0+20 | 2026-03-29 | `android/gradle.properties` 移除 `TLSv1.1` 和 `TLSv1` 不安全协议，保留 `TLSv1.2`/`TLSv1.3`；`flutter pub get` 确认 `device_calendar` 和 `sprintf` 共 2 个依赖移除生效；**修复 device_calendar 残留源码未清理**：此前 v0.1.0+20 仅删除了 `pubspec.yaml` 中的 `device_calendar` 声明，但 `classtable_state.dart` 的 import 和依赖代码未同步删除，导致 `flutter run` 报 `device_calendar` 包找不到的错误；现已彻底删除 `classtable_state.dart` 中的 `import 'package:device_calendar/device_calendar.dart'`、`import 'package:timezone/data/latest.dart' as tz` 及 `events`/`iCalenderStr`/`outputToCalendar` 三个成员（约 267 行）；`flutter analyze` 零 error；`flutter pub get` 正常 |
| 0.1.0+19 | 2026-03-29 | **精简 traintime_pda 包（方案 A）**：用户手动删除 `packages/traintime_pda/` 下非源码目录（`android/`、`ios/`、`linux/`、`windows/`、`pigeon_bridge/`、`test/`、`docs/`、`fastlane/`、`tool/`、`.github/`、`.vscode/`、`.flutter/`、`blobs/`、`XDYou-Poster.jpg`）；精简 `assets/` 目录（从 102 文件裁剪至 4 文件：`icon.png` + 3 个 i18n yaml）；`pubspec.yaml` 删除 `flutter_launcher_icons`、`flutter_native_splash` 配置段及对应依赖；`flutter pub get` 确认 `flutter_native_splash` 移除生效；`flutter analyze` 无 error；由于子 App 仅运行于移动端，无需添加 Web 兼容 stub |
| 0.1.0+18 | 2026-03-29 | **校园 Tab 仅登录可见**：`AuthStore` 继承 `ChangeNotifier` 并在 `init`/`saveToken`/`clear` 时 `notifyListeners()`；`GoRouter` 增加 `refreshListenable: AuthStore.instance`；`MobileShell` 用 `ListenableBuilder` 监听登录态，仅 `isAuthenticated` 时展示「校园」Tab，未登录时底部为 3 Tab（首页/消息/我的）并映射 branch 0、1、3；若未登录仍停留在校园 branch 则下一帧切回首页 |
| 0.1.0+17 | 2026-03-29 | **移动端嵌入 XDYou**：通过 path 依赖引入 `watermeter`（[Traintime PDA](https://github.com/BenderBlog/traintime_pda)，MPL-2.0）；`scripts/setup_xdyou.sh` 拉取源码至 `packages/traintime_pda`（目录已 gitignore）；`lib/mobile/integrations/xdyou_bootstrap.dart` 复现独立应用启动时的本地存储与通知初始化；底部 Tab 增加「校园」路由 `/xdyou` 全屏嵌入 `MyApp`；Dart SDK 提升至 `>=3.8.0`；`analysis_options` 排除 `packages/traintime_pda`；CI 在 `flutter pub get` 前执行 `setup_xdyou.sh` |
| 0.1.0+12~16 | 2026-03-27~28 | **后端模块化拆分**：`backend/server.py`（原 3620 行）拆分为 `helpers/`（5 个子模块）、`services/`（`_db_service`、`_user_service`）、`handlers/`（9 个功能域处理器），最终行数 745 行（-79%）；**移动端功能完善**：修复移动端登录 API 地址（`localhost:8080` → `81.69.16.134:8080`）；消息页改为会话列表直接展示（删除私信申请 Tab）；帖子卡片重构为 Instagram 风格（PageView 图片展示）；引入阅读量指标 + 热度算法优化（`likes×2 + comments×3 + viewCount - ts/1e9`）；帖子列表 API 支持 `authorId` 查询；评论列表 API 新增 `authorAvatar` 和 `authorUserId` |
| 0.1.0+10~11 | 2026-03-26 | **工程审计整改**：删除废弃 `lib_mobile/`（40 文件）和 `backup_lib/`（80 文件）目录；`admin_models.dart`（732 行）拆分为 `lib/models/admin/` 子目录（9 个独立文件，每文件 < 200 行）；新建 `lib/core/theme/shared_colors.dart` 统一跨端品牌色；后端添加 Python `logging` 结构化日志系统（替换所有 `print()`）；异常处理器消除内部信息泄漏；环境变量模板新增生产安全警告 |
| 0.1.0+8~9 | 2026-03-26 | **私信微信模式 + 匿名/非匿名头像**：后端新增 `POST /api/messages/conversations/direct` 端点（无需申请直接创建会话）；移动端私信按钮直接进入或创建会话；新建他人公开主页 `PublicUserProfilePage`（关注/私信按钮）；`PostCard` 非匿名帖显示真实头像并支持点击跳转他人主页；`PostItem` 新增 `isAnonymous`、`authorAvatarUrl`、`authorUserId` 字段 |
| 0.1.0+4~6 | 2026-03-25 | **移动端早期建设**：清理重复移动端目录，确认 `lib/mobile/` 为唯一源码目录；重构底部导航（3 Tab：首页/消息/我的）；实现关注/粉丝系统（API 端点 + Repository + 好友标记）；管理员控制台恢复完整功能；修复消息页加载、头像点击、首页点赞乐观更新、下拉刷新、收藏 Tab 真实数据等多个 bug |
| 0.1.0+1~5 | 2026-03-25 | **首个 Android APK 发布**：创建 `lib/mobile/` Junction 指向 `lib_mobile/`，在 `lib/main.dart` 用 `kIsWeb` 平台分流，`flutter build apk` 直接可用；首个 Android ARM64 Release APK 构建成功 |

## 3.1 当前开发进度（未推送）

- **应用内更新提示**：已新增移动端 `app_update_controller.dart` 与更新弹窗，准备把“检查更新 / 启动时提示新版本”接到设置页与启动流程
- **设置页拆分迁移**：正在将移动端设置页细分为「一站式设置」「课表设置」等子页，把 XDYou 原设置能力逐步迁移到树洞主 App
- **XDYou 设置收口**：正在清理子应用内已废弃的颜色种子与旧主题入口，统一跟随树洞主题与语言同步策略
- **Android 分发兼容性排查**：已确认当前 Release APK 最低支持 Android 7.0（API 24），后续会继续收敛分发流程并优先引导用户下载通用 `app-release.apk`

## 4. 未跨端兼容的功能

> 以下记录尚未同时在 Web 端和移动端适配的功能，跨端适配完成后请删除对应条目。

| 功能名称 | 描述 | 当前实现平台 | 备注 |
|----------|------|-------------|------|
| 个人主页（ProfilePage） | 背景色条 + 重叠头像 + 统计行 + Tab（帖子/收藏/动态）+ 右上角设置入口 | 仅移动端 | |
| 设置主页（SettingsMainPage） | 独立设置页：账号安全 / 隐私开关 / 通知 / 外观（主题/语言） / 账号注销 | 仅移动端 | 外观区块 v0.1.0+24 新增 |
| 发帖页（CreatePostPage） | 极简发帖：内联频道选择器、底部工具栏、匿名昵称输入、PopupMenu 可见性选择 | 仅移动端 | |
| 帖子详情页（PostDetailPage） | 操作栏置于正文与评论区之间 + 嵌套评论树（最多3层缩进）+ EmojiPickerBar + 举报流程 + 关注/私信作者 | 仅移动端 | 操作栏位置/嵌套评论/表情输入 v0.1.0+23/24 重构 |
| 消息页（MessagesPage） | 会话列表直接展示，无 Tab 切换；头像使用 `CachedNetworkImage` + `AppConfig.resolveUrl()` 正确加载 | 仅移动端（`lib/mobile/features/messages/`） | |
| AvatarWidget | 使用 `AppConfig.resolveUrl()` + `CachedNetworkImage` 正确加载头像 | 仅移动端（`lib/mobile/features/widgets/`） | |
| 统一身份认证登录（XduLoginPage） | 学号 + 统一认证密码，`@stu.xidian.edu.cn` 自动拼接；登录后一键同步登录凭证/主题/语言到 XDYou | 仅移动端（`lib/mobile/features/auth/login_page.dart`） | v0.1.0+24 新增文件 |
| AppSettingsStore | 主题（ThemeMode）+ 语言（Locale）的持久化与 XDYou 同步触发；单例 ChangeNotifier | 仅移动端（`lib/mobile/core/state/app_settings_store.dart`） | v0.1.0+24 新增文件 |
| XDYou 集成层 | `xdyou_bootstrap.dart`（真机）/ `xdyou_bootstrap_stub.dart`（Web 空操作）/ `xdyou_sync_bridge.dart`（函数指针桥接） | 仅移动端（`lib/mobile/integrations/`） | v0.1.0+24 新增文件 |
| EmojiPickerBar | 96 个常用 emoji 网格，与键盘互斥（展开时收起键盘防止布局空白）；`insertEmoji()` API 通过 GlobalKey 暴露 | 仅移动端（`lib/mobile/features/post/comment_input_bar.dart`） | v0.1.0+24 新增组件 |
| CommentInputBar（含 insertEmoji API） | 评论输入栏公开 `insertEmoji()` 方法供父组件调用；聚焦时自动滚动到输入框 | 仅移动端（`lib/mobile/features/post/comment_input_bar.dart`） | v0.1.0+23 新增 API |
| 学号登录（自动拼接邮箱后缀） | 登录/注册只需填学号，系统自动拼接 `@stu.xidian.edu.cn` | 仅移动端 | |
| 关注/粉丝系统（FollowSystem） | 粉丝/关注数实时显示，点击弹出列表，互相关注标记为好友；API 端点 + `FollowUserItem` 模型 + Repository 方法 | 仅移动端 | |
| 首条消息警告横幅 | 对话无历史消息时显示横幅提示"只能发1条消息"，对方回复或关注后解锁 | 仅移动端 | |
| 私信直接进入（微信模式） | 私信按钮直接进入或创建会话，无需申请流程；长按气泡 WeChat 风格浮层（复制/转发/详情/回复/撤回）；消息详情显示秒级时间；屏蔽/解除屏蔽入口；批量选中删除；转发到联系人会话 | 仅移动端 | |
| 匿名头像点击 | 匿名帖不能点击头像进入主页；非匿名帖点击头像进入公开主页（支持关注和私信） | 仅移动端（`lib/mobile/features/`） | |
| 帮助与反馈入口（登录/注册页） | 登录页底部行增加「帮助与反馈」按钮；注册页底部同样添加入口 | 仅移动端 | |

---

*最后更新：2026-04-01（补录 v0.1.0+31 ~ v0.1.0+35 发布记录，并同步当前移动端更新与设置页重构进度）*
