---
name: xduWhisperBox 移动端开发
overview: 在现有 Flutter Web 端基础上，新建 lib_mobile/ 目录实现 iOS + Android 双平台 App。核心任务是完善 pubspec.yaml 依赖配置、实现所有移动端页面 UI 和交互逻辑、确保 Android/iOS 打包可用。
todos:
  - id: mobile-dep-01
    content: 更新 pubspec.yaml，添加 go_router、cached_network_image、image_picker、shimmer、date_format 等移动端专用依赖
    status: completed
  - id: mobile-dep-02
    content: 完善 Android 平台配置 — build.gradle 配置 minSdk/targetSdk/compileSdk，AndroidManifest 添加网络/相机/相册权限
    status: completed
  - id: mobile-dep-03
    content: 完善 iOS 平台配置 — Info.plist 添加 NSCameraUsageDescription、NSPhotoLibraryUsageDescription，配置竖屏支持
    status: completed
  - id: mobile-dep-04
    content: 完善登录页 LoginPage（学号/邮箱+密码表单、错误提示、loading 状态）+ 注册页 RegisterPage（邮箱注册流程）+ 验证页 VerifyPage（验证码输入）+ 找回密码页 ResetPasswordPage，完成与后端 API 的联调测试
    status: completed
  - id: mobile-dep-05
    content: 完善首页帖子卡片组件 PostCard — 帖子标题/摘要/频道标签/时间戳、图片网格（最多3张）、点赞/收藏/评论数显示、点击跳转详情
    status: completed
  - id: mobile-dep-06
    content: 完善首页频道筛选交互 — 横向滚动 Chip 列表（全部/学习/二手/找搭子/失物/吐槽等）、热门/最新排序切换、快捷发帖悬浮按钮
    status: completed
  - id: mobile-dep-07
    content: 实现帖子详情页 PostDetailPage — 帖子正文/图片画廊（点击放大/手势缩放/滑动切换）/ 评论列表（嵌套展示）/ 固定底部评论输入框（表情/图片附件）/ 点赞/收藏/举报交互（乐观更新）
    status: completed
  - id: mobile-dep-08
    content: 实现发帖页 CreatePostPage — 标题输入（选填，不超过50字）/ 正文多行输入框 / 频道/标签选择器（底部弹出）/ 允许评论/允许私信开关 / 多图选择+预览+删除 / 发布进度提示 + 成功后跳转
    status: completed
  - id: mobile-dep-09
    content: 实现搜索页 SearchPage — 搜索结果列表（复用 PostCard）/ 频道/状态/有图筛选 / 本地搜索历史存储 / 热门搜索词展示（复用 Web 端逻辑）
    status: completed
  - id: mobile-dep-10
    content: 实现聊天页 ChatPage — 消息气泡（左右区分）/ 时间戳分组 / 输入框固定底部 / 表情栏 EmojiAssistantBar / 发送消息乐观更新 / 键盘弹出交互适配
    status: completed
  - id: mobile-dep-11
    content: 实现收藏页 FavoritesPage — 帖子卡片列表（复用 PostCard）/ 滑动或长按取消收藏 / 空状态 UI
    status: completed
  - id: mobile-dep-12
    content: 实现个人中心页 ProfilePage — 头像（圆形）+ 昵称/学号 / 我的帖子/评论/收藏/举报统计入口 / 账号设置/隐私设置入口
    status: completed
  - id: mobile-dep-13
    content: 实现编辑资料页 EditProfilePage — 昵称/学号修改表单 / 头像上传（图片选择+预览+裁剪+上传）/ 保存后回显
    status: completed
  - id: mobile-dep-14
    content: 实现我的帖子页 MyPostsPage / 我的评论页 MyCommentsPage / 我的举报页 MyReportsPage — 复用 Web 端已有页面逻辑，适配移动端 UI
    status: completed
  - id: mobile-dep-15
    content: 实现设置页 SettingsPage — 隐私设置（陌生人私信/联系方式可见）/ 表情设置入口 / 账号注销申请 / 退出登录（清理 Token + 跳转登录页）
    status: completed
  - id: mobile-dep-16
    content: 实现通知中心页 NotificationCenterPage — 分类型展示通知（评论/点赞/收藏/系统公告）/ 通知类型图标 / 单条+全部已读 / 未读数角标 / 点击跳转对应帖子或内容
    status: completed
  - id: mobile-dep-17
    content: 实现管理员登录页 AdminLoginPage（独立入口）+ 管理员后台控制台页 AdminConsolePage — 复用 Web 端 admin_console_page 逻辑，适配移动端 UI
    status: completed
  - id: mobile-dep-18
    content: 实现移动端公共组件 — 骨架屏 ShimmerLoading / 空状态 EmptyState / 错误重试页 ErrorRetryPage / 评论列表项 CommentTile / 底部输入框 InputBar / 表情栏 EmojiBar / 头像组件 AvatarWidget
    status: completed
  - id: mobile-dep-19
    content: Android APK 打包验证 — flutter build apk --debug 和 --release 构建成功，确认应用可在 Android 真机/模拟器运行
    status: completed
  - id: mobile-dep-20
    content: iOS IPA 打包验证 — Xcode 配置 iOS Deployment Target，flutter build ios --simulator --no-codesign 构建成功
    status: pending
isProject: false
---

# 西电树洞移动端 App 开发计划

## 一、项目架构

### 1.1 整体架构

```
xduWhisperBox/
├── lib/                          # Web 端（现有）
├── lib_mobile/                   # 移动端专用代码（新增）
│   ├── main.dart                 # 移动端入口
│   ├── app.dart                  # 移动端应用壳
│   ├── core/                     # 移动端核心配置
│   │   ├── config/
│   │   │   └── mobile_config.dart
│   │   ├── theme/
│   │   │   └── mobile_theme.dart
│   │   └── navigation/
│   │       └── app_router.dart
│   ├── shared/                   # 复用代码（条件导入）
│   │   ├── models/               # 数据模型（复用现有）
│   │   ├── repositories/         # Repository（复用现有）
│   │   ├── core/
│   │   │   ├── network/         # API Client + Endpoints（复用）
│   │   │   ├── auth/            # Auth Store（复用）
│   │   │   └── config/          # App Config（复用）
│   │   └── features/             # 业务逻辑（复用现有）
│   │       ├── feed/
│   │       ├── post/
│   │       ├── auth/
│   │       ├── messages/
│   │       ├── notifications/
│   │       ├── favorites/
│   │       ├── search/
│   │       ├── profile/
│   │       └── admin/
│   ├── features/                 # 移动端新 UI（全新设计）
│   │   ├── shell/
│   │   │   └── mobile_shell.dart
│   │   ├── home/
│   │   │   └── home_page.dart
│   │   ├── search/
│   │   │   └── search_page.dart
│   │   ├── messages/
│   │   │   ├── messages_page.dart
│   │   │   └── chat_page.dart
│   │   ├── favorites/
│   │   │   └── favorites_page.dart
│   │   ├── profile/
│   │   │   └── profile_page.dart
│   │   ├── auth/
│   │   │   ├── login_page.dart
│   │   │   ├── register_page.dart
│   │   │   └── verify_page.dart
│   │   ├── post/
│   │   │   ├── post_detail_page.dart
│   │   │   └── create_post_page.dart
│   │   ├── notifications/
│   │   │   └── notification_center_page.dart
│   │   └── admin/
│   │       └── admin_console_page.dart
│   └── widgets/                  # 移动端专用组件
│       ├── post_card.dart
│       ├── comment_tile.dart
│       ├── input_bar.dart
│       ├── emoji_bar.dart
│       ├── avatar_widget.dart
│       └── loading_states.dart
├── pubspec.yaml                  # 合并后的依赖配置
└── analysis_options.yaml
```

### 1.2 复用策略

| 层级                                      | 复用内容                                   | 新建/修改方式                                     |

| --------------------------------------- | -------------------------------------- | ------------------------------------------- |

| 数据模型 (`models/`)                        | 所有数据类                                  | 直接复用，通过 `lib/` 相对路径导入                       |

| Repository (`repositories/`)            | 所有 Repository                          | 直接复用，通过 `lib/` 相对路径导入                       |

| API Client (`core/network/`)            | api_client.dart, api_endpoints.dart    | 直接复用                                        |

| Auth Store (`core/auth/`)               | auth_store.dart, admin_auth_store.dart | 直接复用                                        |

| App Config (`core/config/`)             | app_config.dart                        | 复制一份到 `lib_mobile/shared/` 并修改 API_BASE_URL |

| 状态控制器 (`features/*/ *_controller.dart`) | StateNotifier                          | 直接复用                                        |

| 页面 UI (`features/*/*_page.dart`)        | 无                                      | 全部新建，参考 Web 端交互逻辑                           |

| 通用 Widget (`widgets/`)                  | async_page_state.dart                  | 复制并适配移动端                                    |

| Theme (`core/theme/app_theme.dart`)     | 无                                      | 新建 iOS 风格主题                                 |

---

## 二、技术选型

### 2.1 核心依赖

```yaml
# pubspec.yaml 新增/修改
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.6.1          # 状态管理（复用现有）
  riverpod_annotation: ^2.6.1       # Riverpod 代码生成（可选）
  http: ^1.2.2                       # HTTP 客户端（复用现有）
  shared_preferences: ^2.3.2         # 本地存储（复用现有）
  cupertino_icons: ^1.0.8            # iOS 风格图标
  
  # 新增移动端专用
  go_router: ^14.0.0                 # 路由管理（替代 Navigator）
  cached_network_image: ^3.3.1        # 图片缓存
  image_picker: ^1.0.7                # 图片选择
  flutter_svg: ^2.0.10               # SVG 渲染
  shimmer: ^3.0.0                     # 骨架屏加载效果
  pull_to_refresh_flutter3: ^2.0.2   # 下拉刷新
  date_format: ^2.0.7                 # 日期格式化

dev_dependencies:
  flutter_lints: ^4.0.0
  build_runner: ^2.4.8
  riverpod_generator: ^2.4.0          # Riverpod 代码生成（可选）
```

### 2.2 平台配置

**Android (**`android/app/build.gradle`**)**:

- minSdkVersion: 21
- targetSdkVersion: 34
- compileSdkVersion: 34
- 网络权限: `<uses-permission android:name="android.permission.INTERNET"/>`
- 相机权限: `<uses-permission android:name="android.permission.CAMERA"/>`
- 相册权限: `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>`

**iOS (**`ios/Runner/Info.plist`**)**:

- `NSCameraUsageDescription`: "需要相机权限来拍照上传"
- `NSPhotoLibraryUsageDescription`: "需要相册权限来选择图片"
- 支持的朝向: 竖屏优先

---

## 三、界面设计规范

### 3.1 iOS 风格设计语言

| 设计元素       | 规范                                               |

| ---------- | ------------------------------------------------ |

| **导航栏**    | 大标题风格 (Large Title)，背景模糊效果                       |

| **圆角**     | 卡片圆角 12px，按钮圆角 10px，输入框圆角 8px                    |

| **间距**     | 页面内边距 16px，元素间距 12px，卡片间距 8px                    |

| **阴影**     | 卡片阴影极淡 `opacity: 0.05, blur: 10, offset: (0, 2)` |

| **图片**     | 头像圆角 50%，帖子图片圆角 8px                              |

| **字体**     | 系统字体，标题 18px，正文 15px，辅助文字 13px                   |

| **颜色**     | 主色 #155E75（复用），强调色 #E06C4E（复用），背景 #F5F5F7        |

| **列表**     | 无分割线，改用间距分隔                                      |

| **底部 Tab** | CupertinoTabBar，图标 + 文字，未选中灰色，选中主色               |

### 3.2 页面设计详情

#### 3.2.1 首页 (Home Page)

```
┌─────────────────────────────────┐
│ ░░░░░░░░ 状态栏 ░░░░░░░░░░░░░░ │
├─────────────────────────────────┤
│  西电树洞                        │ ← 大标题导航栏
│  ────────────────────────────── │
│                                 │
│  [全部] [学习] [二手] [找搭子]    │ ← 横向滚动频道筛选
│  [失物] [吐槽]                   │
│                                 │
│  ┌───────────────────────────┐  │
│  │ [频道]              3小时前 │  │
│  │ 帖子标题文字                 │  │
│  │ 帖子内容摘要，最多显示两行...│  │
│  │ ┌─────┐┌─────┐┌─────┐     │  │ ← 图片网格（最多3张）
│  │ │ IMG ││ IMG ││ +2  │     │  │
│  │ └─────┘└─────┘└─────┘     │  │
│  │ ♡ 12   ★ 5   💬 8         │  │
│  └───────────────────────────┘  │
│                                 │
│  (更多帖子卡片...)               │
│                                 │
├─────────────────────────────────┤
│  🏠    🔍    💬    ⭐    👤     │ ← 底部 Tab
└─────────────────────────────────┘
```

#### 3.2.2 帖子详情页

```
┌─────────────────────────────────┐
│ ← 返回           更多 ∙∙∙      │
├─────────────────────────────────┤
│ ┌──┐  匿名同学        3小时前   │
│ │头像│ 🔖 进行中                 │
│ └──┘                             │
│                                 │
│  帖子标题文字（加粗，18px）      │
│                                 │
│  帖子正文内容，支持多段落。       │
│  可以包含换行和长文本。          │
│                                 │
│  ┌─────┐┌─────┐┌─────┐        │
│  │ IMG ││ IMG ││ IMG │        │ ← 图片画廊，点击全屏
│  └─────┘└─────┘└─────┘        │
│                                 │
│  ────────────────────────────── │
│  💬 8 条评论                    │
│  ────────────────────────────── │
│                                 │
│  ┌──┐  评论者昵称    2小时前    │
│  │头像│                              │
│  └──┘ 评论内容文字...               │
│       ♡ 3                          │
│                                 │
│  (更多评论...)                    │
│                                 │
├─────────────────────────────────┤
│ ┌─────────────────────────┐ [发送]│ ← 输入框固定在底部
│ │ 输入评论...         😀 📷 │    │
│ └─────────────────────────┘      │
└─────────────────────────────────┘
```

#### 3.2.3 发帖页

```
┌─────────────────────────────────┐
│ 取消          发帖         发布  │
├─────────────────────────────────┤
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 标题（选填，不超过50字）     │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │                             │ │
│ │ 正文内容...                  │ │
│ │                             │ │
│ │                             │ │
│ │                     😀 📷   │ │ ← 输入框自适应高度
│ └─────────────────────────────┘ │
│                                 │
│  频道: [▼ 选择频道]             │
│  标签: [学习] [求助] [+]        │
│                                 │
│  ☑️ 允许评论  ☑️ 允许私信       │
│                                 │
│  ┌────┐┌────┐┌────┐          │ ← 图片预览网格
│  │ +  ││ IMG││ IMG│          │
│  └────┘└────┘└────┘          │
│                                 │
└─────────────────────────────────┘
```

#### 3.2.4 搜索页

```
┌─────────────────────────────────┐
│  🔍 搜索帖子、用户、内容...     │ ← 搜索框固定在顶部
├─────────────────────────────────┤
│                                 │
│  搜索历史                       │
│  ────────────────────────────── │
│  最近搜索1  ✕                   │
│  最近搜索2  ✕                   │
│                                 │
│  热门搜索                      │
│  ────────────────────────────── │
│  # 期末考试    # 二手交易       │
│  # 找搭子      # 租房           │
│                                 │
└─────────────────────────────────┘
```

#### 3.2.5 消息页

```
┌─────────────────────────────────┐
│  消息中心              消息 ∙∙∙ │
├─────────────────────────────────┤
│  [私信申请(3)] [会话列表]       │ ← Tab 切换
├─────────────────────────────────┤
│                                 │
│  私信申请                      │
│  ────────────────────────────── │
│  ┌──┐  用户A  想和你私信         │
│  │头像│  "想请教一下..."        │
│  └──┘  [同意] [拒绝]    3小时前  │
│                                 │
│  ┌──┐  用户B  想和你私信         │
│  │头像│  [已同意]              │
│  └──┘                   昨天     │
│                                 │
├─────────────────────────────────┤
│  会话列表                      │
│  ────────────────────────────── │
│  ┌──┐  用户昵称                  │
│  │头像│  最后一条消息...         │
│  └──┘ ●            3小时前  (3) │ ← 红点未读数
│                                 │
└─────────────────────────────────┘
```

#### 3.2.6 个人中心页

```
┌─────────────────────────────────┐
│  ⚙️ 设置            编辑资料     │
├─────────────────────────────────┤
│                                 │
│       ┌─────────┐               │
│       │  头像   │               │
│       │ (可编辑) │               │
│       └─────────┘               │
│        昵称 / 学号                │
│      ✉️ user@email.com          │
│                                 │
│  ────────────────────────────── │
│  我的帖子           5      →    │
│  我的评论           12      →    │
│  我的收藏           8       →    │
│  我的举报           2       →    │
│  ────────────────────────────── │
│  账号设置                    →  │
│  隐私设置                    →  │
│  ────────────────────────────── │
│  [退出登录]                    │
│                                 │
└─────────────────────────────────┘
```

#### 3.2.7 通知中心页

```
┌─────────────────────────────────┐
│  通知中心              全部已读 │
├─────────────────────────────────┤
│                                 │
│  🔴 你有 5 条新通知             │ ← 未读提示条
│  ────────────────────────────── │
│                                 │
│  💬  评论通知                   │
│  ┌──┐  用户A 评论了你的帖子     │
│  │头像│  "写得很好！"          │
│  └──┘                   3小时前 │
│                                 │
│  🔥  点赞通知                   │
│  ┌──┐  用户B 点赞了你的帖子     │
│  │头像│  "求助帖"              │
│  └──┘                   昨天   │
│                                 │
│  ⭐  收藏通知                   │
│  ┌──┐  用户C 收藏了你的帖子     │
│  │头像│  "期末资料"            │
│  └──┘                   2天前   │
│                                 │
│  📢  系统公告                   │
│  ┌──┐  平台更新通知            │
│  │📢│  新功能上线公告...       │
│  └──┘                   1周前   │
│                                 │
└─────────────────────────────────┘
```

---

## 四、功能开发清单

### 4.1 第一阶段：项目搭建与基础架构

| 任务                            | 描述                             | 优先级 | 预计工时 |

| ----------------------------- | ------------------------------ | --- | ---- |

| 1.1 创建 lib_mobile 目录结构        | 按照上述架构创建所有目录和文件占位              | P0  | 2h   |

| 1.2 修改 pubspec.yaml           | 添加移动端专用依赖                      | P0  | 1h   |

| 1.3 创建移动端入口 main.dart         | 初始化 Flutter + Riverpod         | P0  | 1h   |

| 1.4 创建移动端主题 mobile_theme.dart | iOS 风格配色、字体、圆角规范               | P0  | 2h   |

| 1.5 配置移动端 API 地址              | 修改 API_BASE_URL 指向实际服务器        | P0  | 0.5h |

| 1.6 配置 Android 权限和网络          | build.gradle + AndroidManifest | P0  | 1h   |

| 1.7 配置 iOS 权限                 | Info.plist 相机/相册权限             | P0  | 0.5h |

| 1.8 初始化 Git 分支                | 创建 `feature/mobile-app` 分支     | P0  | 0.5h |

### 4.2 第二阶段：登录认证流程

| 任务           | 描述                         | 优先级 | 预计工时 |

| ------------ | -------------------------- | --- | ---- |

| 2.1 登录页 UI   | 学号/邮箱 + 密码登录，iOS 风格        | P0  | 3h   |

| 2.2 注册页 UI   | 邮箱注册流程                     | P0  | 3h   |

| 2.3 邮箱验证页 UI | 验证码输入界面                    | P0  | 2h   |

| 2.4 找回密码页 UI | 密码重置流程                     | P1  | 2h   |

| 2.5 认证状态持久化  | SharedPreferences Token 管理 | P0  | 1h   |

| 2.6 管理员登录入口  | 独立管理员登录页面                  | P1  | 2h   |

| 2.7 登录注册流程联调 | 与后端 API 对接测试               | P0  | 3h   |

### 4.3 第三阶段：主框架与导航

| 任务            | 描述                      | 优先级 | 预计工时 |

| ------------- | ----------------------- | --- | ---- |

| 3.1 底部导航栏     | CupertinoTabBar，5 个 Tab | P0  | 3h   |

| 3.2 App Shell | 主页面容器，路由管理 (go_router)  | P0  | 4h   |

| 3.3 首页框架      | Large Title 导航栏 + 频道筛选  | P0  | 3h   |

| 3.4 页面路由配置    | go_router 路由表定义         | P0  | 2h   |

| 3.5 权限拦截      | 未登录自动跳转登录页              | P0  | 2h   |

### 4.4 第四阶段：核心信息流

| 任务             | 描述             | 优先级 | 预计工时 |

| -------------- | -------------- | --- | ---- |

| 4.1 帖子卡片组件     | 移动端专用 PostCard | P0  | 4h   |

| 4.2 帖子列表下拉刷新   | PullToRefresh  | P0  | 2h   |

| 4.3 帖子列表上拉加载更多 | 翻页加载           | P0  | 2h   |

| 4.4 频道筛选交互     | 横向滚动 Tab 切换    | P0  | 3h   |

| 4.5 排序切换       | 热门/最新切换        | P0  | 1h   |

| 4.6 快捷发帖入口     | 首页悬浮按钮或导航栏按钮   | P0  | 1h   |

### 4.5 第五阶段：帖子详情与互动

| 任务           | 描述                | 优先级 | 预计工时 |

| ------------ | ----------------- | --- | ---- |

| 5.1 帖子详情页 UI | 帖子正文 + 图片画廊       | P0  | 4h   |

| 5.2 图片画廊组件   | 点击放大、手势缩放、滑动切换    | P0  | 4h   |

| 5.3 评论列表 UI  | 嵌套评论展示            | P0  | 3h   |

| 5.4 评论输入框    | 固定底部输入栏 + 表情 + 图片 | P0  | 4h   |

| 5.5 点赞/收藏交互  | 乐观更新              | P0  | 2h   |

| 5.6 举报功能     | 底部弹出举报选项          | P0  | 3h   |

| 5.7 分享功能     | 原生分享              | P1  | 2h   |

### 4.6 第六阶段：发帖功能

| 任务           | 描述                | 优先级 | 预计工时 |

| ------------ | ----------------- | --- | ---- |

| 6.1 发帖页 UI   | 标题 + 正文 + 频道 + 标签 | P0  | 4h   |

| 6.2 富文本输入    | 多行文本输入框           | P0  | 2h   |

| 6.3 图片选择与上传  | 多图选择 + 预览 + 删除    | P0  | 4h   |

| 6.4 频道/标签选择器 | 底部弹出选择器           | P0  | 3h   |

| 6.5 选项开关     | 允许评论/允许私信         | P0  | 1h   |

| 6.6 发布流程     | 进度提示 + 成功后跳转      | P0  | 2h   |

| 6.7 编辑/删除帖子  | 我的帖子管理            | P1  | 3h   |

### 4.7 第七阶段：搜索功能

| 任务         | 描述         | 优先级 | 预计工时 |

| ---------- | ---------- | --- | ---- |

| 7.1 搜索页 UI | 搜索框 + 历史记录 | P0  | 3h   |

| 7.2 搜索历史   | 本地存储最近搜索   | P0  | 2h   |

| 7.3 搜索结果列表 | 帖子卡片列表     | P0  | 2h   |

| 7.4 筛选功能   | 频道/状态/有图筛选 | P1  | 3h   |

| 7.5 热门搜索词  | 后端获取热门标签   | P1  | 2h   |

### 4.8 第八阶段：私信与消息

| 任务          | 描述                   | 优先级 | 预计工时 |

| ----------- | -------------------- | --- | ---- |

| 8.1 消息中心 UI | 申请列表 + 会话列表 Tab      | P0  | 3h   |

| 8.2 私信申请处理  | 同意/拒绝操作              | P0  | 3h   |

| 8.3 会话列表 UI | 头像 + 昵称 + 最新消息 + 未读数 | P0  | 3h   |

| 8.4 聊天页 UI  | 消息气泡 + 时间戳           | P0  | 4h   |

| 8.5 消息发送与接收 | 乐观更新发送               | P0  | 3h   |

| 8.6 未读消息红点  | 消息数角标                | P0  | 2h   |

| 8.7 会话删除    | 左滑删除                 | P1  | 2h   |

### 4.9 第九阶段：个人中心

| 任务           | 描述              | 优先级 | 预计工时 |

| ------------ | --------------- | --- | ---- |

| 9.1 个人中心页 UI | 头像 + 资料 + 菜单列表  | P0  | 4h   |

| 9.2 编辑资料页    | 昵称/学号修改         | P0  | 3h   |

| 9.3 头像上传     | 图片裁剪 + 上传       | P0  | 3h   |

| 9.4 我的帖子列表   | 管理已发帖           | P0  | 3h   |

| 9.5 我的评论列表   | 评论历史            | P0  | 3h   |

| 9.6 隐私设置     | 陌生人私信/联系方式可见    | P1  | 2h   |

| 9.7 账号注销申请   | 注销流程            | P1  | 2h   |

| 9.8 退出登录     | 清理 Token + 跳转登录 | P0  | 1h   |

### 4.10 第十阶段：通知中心

| 任务           | 描述             | 优先级 | 预计工时 |

| ------------ | -------------- | --- | ---- |

| 10.1 通知列表 UI | 分类型展示通知        | P0  | 3h   |

| 10.2 通知类型图标  | 评论/点赞/收藏/系统公告  | P0  | 2h   |

| 10.3 标记已读    | 单条 + 全部已读      | P0  | 2h   |

| 10.4 未读数角标   | TabBar 红点 + 数字 | P0  | 2h   |

| 10.5 通知跳转    | 点击跳转对应帖子/内容    | P0  | 3h   |

### 4.11 第十一阶段：收藏功能

| 任务            | 描述      | 优先级 | 预计工时 |

| ------------- | ------- | --- | ---- |

| 11.1 收藏列表页 UI | 帖子卡片列表  | P0  | 3h   |

| 11.2 取消收藏     | 滑动或长按取消 | P0  | 2h   |

| 11.3 空状态 UI   | 无收藏时占位图 | P0  | 1h   |

### 4.12 第十二阶段：管理员后台

| 任务          | 描述          | 优先级 | 预计工时 |

| ----------- | ----------- | --- | ---- |

| 12.1 管理员登录  | 独立入口        | P1  | 2h   |

| 12.2 管理后台概览 | 统计数据仪表盘     | P1  | 4h   |

| 12.3 内容审核   | 帖子/评论审核列表   | P1  | 4h   |

| 12.4 举报管理   | 举报处理流程      | P1  | 4h   |

| 12.5 图片审核   | 图片审核队列      | P1  | 3h   |

| 12.6 用户管理   | 禁言/封禁操作     | P1  | 3h   |

| 12.7 系统配置   | 频道/标签/敏感词管理 | P1  | 4h   |

| 12.8 发布公告   | 系统公告发布      | P1  | 3h   |

### 4.13 第十三阶段：优化与完善

| 任务                  | 描述                          | 优先级 | 预计工时 |

| ------------------- | --------------------------- | --- | ---- |

| 13.1 骨架屏加载          | Shimmer 效果                  | P1  | 3h   |

| 13.2 错误重试页          | 网络错误 + 重试按钮                 | P0  | 2h   |

| 13.3 空状态页           | 各列表空状态设计                    | P0  | 2h   |

| 13.4 图片懒加载          | CachedNetworkImage          | P1  | 2h   |

| 13.5 Android APK 打包 | debug/release 构建            | P0  | 2h   |

| 13.6 iOS IPA 打包     | Xcode 打包配置                  | P0  | 2h   |

| 13.7 黑暗模式           | 跟随系统暗黑模式                    | P2  | 4h   |

| 13.8 深链接支持          | App Links / Universal Links | P2  | 4h   |

---

## 五、API 对接清单

| 模块    | API 端点                                                      | 对接状态 |

| ----- | ----------------------------------------------------------- | ---- |

| 认证    | `/api/auth/login`, `/api/auth/register`, `/api/auth/verify` | 待对接  |

| 帖子列表  | `/api/posts` (GET with filters)                             | 待对接  |

| 帖子详情  | `/api/posts/<id>`                                           | 待对接  |

| 发布帖子  | `/api/posts` (POST)                                         | 待对接  |

| 评论列表  | `/api/posts/<id>/comments`                                  | 待对接  |

| 发布评论  | `/api/posts/<id>/comments` (POST)                           | 待对接  |

| 点赞/收藏 | `/api/posts/<id>/like`, `/api/posts/<id>/favorite`          | 待对接  |

| 搜索    | `/api/posts` (GET with keyword)                             | 待对接  |

| 私信申请  | `/api/messages/requests`                                    | 待对接  |

| 会话列表  | `/api/messages/conversations`                               | 待对接  |

| 发送消息  | `/api/messages`                                             | 待对接  |

| 通知列表  | `/api/notifications`                                        | 待对接  |

| 标记已读  | `/api/notifications/read-all`                               | 待对接  |

| 用户资料  | `/api/users/me`                                             | 待对接  |

| 头像上传  | `/api/users/avatar`                                         | 待对接  |

| 图片上传  | `/api/uploads/images`                                       | 待对接  |

| 举报    | `/api/reports`                                              | 待对接  |

| 管理员   | `/api/admin/*` (全部端点)                                       | 待对接  |

---

## 六、数据模型映射

移动端直接复用现有数据模型，无需新建：

| 模型文件                              | 使用场景       |

| --------------------------------- | ---------- |

| `models/post_item.dart`           | 帖子列表、详情、收藏 |

| `models/comment_item.dart`        | 评论列表       |

| `models/user_profile.dart`        | 个人资料、用户信息  |

| `models/notification_item.dart`   | 通知列表       |

| `models/conversation_item.dart`   | 私信会话列表     |

| `models/direct_message_item.dart` | 聊天消息       |

| `models/report_item.dart`         | 举报列表       |

| `models/dm_request_item.dart`     | 私信申请       |

| `models/uploaded_image_item.dart` | 图片上传结果     |

| `models/admin_models.dart`        | 管理员后台数据    |

---

## 七、状态管理方案

### 7.1 Riverpod Provider 架构

```dart
// 复用现有的 StateNotifier + 移动端专用 Provider

// 1. Feed 状态（复用现有 feed_controller.dart）
final feedControllerProvider = StateNotifierProvider<FeedController, FeedState>((ref) {
  return FeedController(ref.read(postRepositoryProvider));
});

// 2. Search 状态（复用现有 search_controller.dart）
final searchControllerProvider = StateNotifierProvider<SearchController, SearchState>((ref) {
  return SearchController(ref.read(postRepositoryProvider));
});

// 3. Messages 状态（复用现有 messages_controller.dart）
final messagesControllerProvider = StateNotifierProvider<MessagesController, MessagesState>((ref) {
  return MessagesController(ref.read(messageRepositoryProvider));
});

// 4. Notifications 状态（复用现有 notifications_controller.dart）
final notificationsControllerProvider = StateNotifierProvider<NotificationsController, NotificationsState>((ref) {
  return NotificationsController(ref.read(notificationRepositoryProvider));
});

// 5. 新增：当前 Tab 索引（移动端专用）
final currentTabIndexProvider = StateProvider<int>((ref) => 0);

// 6. 新增：骨架屏状态（移动端专用）
final skeletonLoadingProvider = StateProvider<bool>((ref) => false);
```

### 7.2 Repository 依赖注入

```dart
// lib_mobile/shared/repositories/providers.dart
import '../../lib/repositories/auth_repository.dart';
import '../../lib/repositories/post_repository.dart';
import '../../lib/repositories/user_repository.dart';
import '../../lib/repositories/message_repository.dart';
import '../../lib/repositories/notification_repository.dart';
import '../../lib/repositories/admin_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.read(apiClientProvider));
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.read(apiClientProvider));
});

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  return MessageRepository(ref.read(apiClientProvider));
});

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(ref.read(apiClientProvider));
});

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.read(apiClientProvider));
});
```

---

## 八、路由设计方案

### 8.1 路由表 (go_router)

```dart
// lib_mobile/core/navigation/app_router.dart

final appRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final isLoggedIn = authStore.isLoggedIn;
    final isAuthRoute = state.matchedLocation.startsWith('/auth');
    
    if (!isLoggedIn && !isAuthRoute) {
      return '/auth/login';
    }
    if (isLoggedIn && isAuthRoute) {
      return '/';
    }
    return null;
  },
  routes: [
    // 认证路由（未登录）
    GoRoute(path: '/auth/login', builder: (_, __) => LoginPage()),
    GoRoute(path: '/auth/register', builder: (_, __) => RegisterPage()),
    GoRoute(path: '/auth/verify', builder: (_, __) => VerifyPage()),
    GoRoute(path: '/auth/reset-password', builder: (_, __) => ResetPasswordPage()),
    
    // 主页面（底部 Tab）
    StatefulShellRoute.indexedStack(
      builder: (_, __, shell) => MobileShell(child: shell),
      branches: [
        // 首页
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => HomePage()),
        ]),
        // 搜索
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => SearchPage()),
        ]),
        // 消息
        StatefulShellBranch(routes: [
          GoRoute(path: '/messages', builder: (_, __) => MessagesPage()),
        ]),
        // 收藏
        StatefulShellBranch(routes: [
          GoRoute(path: '/favorites', builder: (_, __) => FavoritesPage()),
        ]),
        // 我的
        StatefulShellBranch(routes: [
          GoRoute(path: '/profile', builder: (_, __) => ProfilePage()),
        ]),
      ],
    ),
    
    // 全屏页面（不在 Tab 内）
    GoRoute(path: '/post/create', builder: (_, __) => CreatePostPage()),
    GoRoute(path: '/post/:id', builder: (_, state) => PostDetailPage(postId: state.pathParameters['id']!)),
    GoRoute(path: '/chat/:conversationId', builder: (_, state) => ChatPage(conversationId: state.pathParameters['conversationId']!)),
    GoRoute(path: '/notifications', builder: (_, __) => NotificationCenterPage()),
    GoRoute(path: '/profile/edit', builder: (_, __) => EditProfilePage()),
    GoRoute(path: '/settings', builder: (_, __) => SettingsPage()),
    
    // 管理员路由
    GoRoute(path: '/admin/login', builder: (_, __) => AdminLoginPage()),
    GoRoute(path: '/admin', builder: (_, __) => AdminConsolePage()),
  ],
);
```

---

## 九、开发里程碑

```
里程碑 1: 项目基础搭建 ✅ → ✅
  ├── lib_mobile 目录结构创建
  ├── 依赖配置完成
  ├── 主题配置完成
  └── 能跑通一个空白页面

里程碑 2: 登录认证 ✅
  ├── 用户登录/注册/验证完整流程
  └── 管理员登录

里程碑 3: 主框架上线 ✅
  ├── 5 个 Tab 底部导航
  ├── 首页信息流
  └── 路由和权限拦截

里程碑 4: 核心发帖功能 ✅
  ├── 发帖 + 图片上传
  ├── 帖子详情
  └── 评论/回复

里程碑 5: 社交互动 ✅
  ├── 点赞/收藏
  ├── 搜索
  ├── 私信
  └── 通知中心

里程碑 6: 个人中心 ✅
  ├── 资料编辑
  ├── 我的帖子/评论/收藏
  └── 隐私设置

里程碑 7: 管理员后台 ✅
  └── 管理员全部功能

里程碑 8: 优化与发布 ✅
  ├── 骨架屏/空状态
  ├── APK/IPA 打包
  └── 测试与修复
```

---

## 十、风险与注意事项

1. **代码复用冲突**: Web 和 App 在同一仓库，修改 `lib/` 下的共享代码时需注意兼容性
2. **API 跨域**: 移动端直接请求 API，不存在 Web 的 CORS 问题，但需处理 HTTPS
3. **图片上传兼容性**: Web 端用 Base64，移动端建议直接上传文件 (`multipart/form-data`)，需确认后端是否支持
4. **Token 刷新**: 当前后端无 Token 刷新机制，Token 过期需重新登录
5. **通知轮询**: 不实现推送时，需定时拉取通知（建议 App 打开时 + 每 5 分钟）
6. **深色模式**: Web 端是浅色，移动端如要支持暗黑需额外设计一套暗色主题
7. **iOS 审核**: 涉及用户生成内容(UGC)需要内容审核机制，App Store 可能要求隐私政策等