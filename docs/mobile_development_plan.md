# 西电树洞移动端 App 开发计划

> 文档版本：v1.0 | 创建日期：2026-03-22
>
> 注：本文保留了早期 `lib_mobile/` 命名作为历史描述；当前仓库已收敛为 `lib/mobile/` 作为唯一移动端源码目录。

---

## 一、项目概览

### 1.1 项目背景

西电树洞（xduWhisperBox）是面向西安电子科技大学校内用户的匿名社区应用，现有产品形态为 Flutter Web，已具备登录注册、发帖评论、搜索收藏、私信通知、管理员后台等完整功能。

本计划的目标是在同一 Flutter 项目内，**新增 iOS + Android 双平台移动端 App**，最大化复用现有数据层和业务逻辑层，全新设计移动端专属 UI。

### 1.2 核心目标

1. 基于现有 `lib/` 复用数据模型、Repository、API Client、StateNotifier 等数据层代码
2. 新建 `lib_mobile/` 目录实现移动端专属 UI，遵循 iOS 风格设计语言
3. 使用 go_router 路由 + Riverpod 状态管理（与现有风格保持一致）
4. 实现发帖、评论、搜索、私信、收藏、通知、个人中心、管理员后台等完整功能
5. 支持 Android APK 和 iOS IPA 打包上线

### 1.3 技术栈

| 层级 | 技术选型 | 说明 |
| --- | --- | --- |
| **跨平台框架** | Flutter 3.3+ | Web + Mobile 共用 |
| **状态管理** | flutter_riverpod ^2.6.1 | 复用现有 |
| **路由** | go_router ^14.0.0 | 移动端专用 |
| **HTTP** | http ^1.2.2 | 复用现有 |
| **本地存储** | shared_preferences ^2.3.2 | 复用现有 |
| **图片缓存** | cached_network_image ^3.3.1 | 移动端专用 |
| **图片选择** | image_picker ^1.0.7 | 移动端专用 |
| **骨架屏** | shimmer ^3.0.0 | 移动端专用 |
| **日期格式化** | date_format ^2.0.7 | 移动端专用 |

### 1.4 当前项目状态

```
lib/                  ✅ 完整 Web 端（93 个文件）
lib_mobile/           🟡 骨架已搭建，部分页面有 Stub 实现
  ├── main.dart       ✅ 入口文件完成
  ├── core/           ✅ config、theme、navigation、state 已搭建
  ├── features/       🟡 shell、auth、home、search、messages 有部分 Stub
  └── widgets/        ⬜ 未创建
```

---

## 二、项目架构

### 2.1 目录结构

```
xduWhisperBox/
├── lib/                          # Web 端（现有，完整）
│   ├── main.dart                 # Web 入口
│   ├── app.dart                  # Web 应用壳
│   ├── core/                     # 核心配置
│   │   ├── auth/                # 认证 Store
│   │   ├── config/              # 应用配置
│   │   ├── network/             # API Client + Endpoints
│   │   ├── theme/               # 主题
│   │   └── ...
│   ├── models/                   # 数据模型（移动端直接复用）
│   ├── repositories/            # Repository 层（移动端直接复用）
│   ├── features/                # 业务功能
│   │   ├── auth/                # 认证
│   │   ├── feed/                # 信息流
│   │   ├── post/                # 帖子
│   │   ├── search/              # 搜索
│   │   ├── messages/            # 私信
│   │   ├── notifications/       # 通知
│   │   ├── favorites/           # 收藏
│   │   ├── profile/             # 个人中心
│   │   ├── me/                  # 我的帖子/评论/举报
│   │   └── admin/               # 管理员后台
│   └── widgets/                 # 公共组件
│
├── lib_mobile/                   # 移动端（新建）
│   ├── main.dart                 # 移动端入口
│   ├── lib_mobile.dart          # 库入口文件
│   ├── core/                    # 移动端核心配置
│   │   ├── config/
│   │   │   └── mobile_config.dart   ✅ 已创建
│   │   ├── theme/
│   │   │   └── mobile_theme.dart    ✅ 已创建
│   │   ├── navigation/
│   │   │   └── app_router.dart     ✅ 已创建
│   │   └── state/
│   │       └── mobile_providers.dart ✅ 已创建
│   ├── shared/                   # 复用层（通过 lib/ 相对路径导入）
│   │   └── repositories/         # Repository DI（使用 lib_mobile 内的 providers）
│   ├── features/                 # 移动端 UI 页面
│   │   ├── shell/
│   │   │   └── mobile_shell.dart    ✅ 有部分实现
│   │   ├── auth/
│   │   │   ├── login_page.dart     ✅ 有部分实现
│   │   │   ├── register_page.dart   ✅ 有部分实现
│   │   │   ├── verify_page.dart    ✅ 有部分实现
│   │   │   └── reset_password_page.dart ✅ 有部分实现
│   │   ├── home/
│   │   │   ├── home_page.dart      ✅ 有部分实现
│   │   │   └── post_card.dart      ⬜ 待创建
│   │   ├── search/
│   │   │   └── search_page.dart    ✅ 有部分实现
│   │   ├── messages/
│   │   │   ├── messages_page.dart  ✅ 有部分实现
│   │   │   └── chat_page.dart     ⬜ 待创建
│   │   ├── favorites/
│   │   │   └── favorites_page.dart ⬜ 待创建
│   │   ├── profile/
│   │   │   ├── profile_page.dart   ⬜ 待创建
│   │   │   ├── edit_profile_page.dart ⬜ 待创建
│   │   │   ├── settings_page.dart  ⬜ 待创建
│   │   │   ├── my_posts_page.dart  ⬜ 待创建
│   │   │   ├── my_comments_page.dart ⬜ 待创建
│   │   │   └── my_reports_page.dart ⬜ 待创建
│   │   ├── post/
│   │   │   ├── post_detail_page.dart ⬜ 待创建
│   │   │   └── create_post_page.dart ⬜ 待创建
│   │   ├── notifications/
│   │   │   └── notification_center_page.dart ⬜ 待创建
│   │   └── admin/
│   │       ├── admin_login_page.dart ⬜ 待创建
│   │       └── admin_console_page.dart ⬜ 待创建
│   └── widgets/                  # 移动端专用组件
│       ├── comment_tile.dart     ⬜ 待创建
│       ├── input_bar.dart        ⬜ 待创建
│       ├── emoji_bar.dart        ⬜ 待创建
│       ├── avatar_widget.dart    ⬜ 待创建
│       └── loading_states.dart   ⬜ 待创建
│
├── android/                      # Android 平台配置
├── ios/                          # iOS 平台配置
├── pubspec.yaml                  # 合并后的依赖配置（需更新）
└── analysis_options.yaml
```

### 2.2 复用策略

| 层级 | 复用内容 | 复用方式 |
| --- | --- | --- |
| 数据模型 (`models/`) | 所有数据类 | 通过 `../../lib/` 相对路径导入 |
| Repository (`repositories/`) | 所有 Repository | 通过 `../../lib/repositories/` 导入 |
| API Client (`core/network/`) | api_client.dart, api_endpoints.dart | 直接复用 |
| Auth Store (`core/auth/`) | auth_store.dart, admin_auth_store.dart | 直接复用 |
| Emoji Settings Store | emoji_settings_store.dart | 直接复用 |
| App Config (`core/config/`) | app_config.dart | 复制到 `lib_mobile/shared/` 并修改 API_BASE_URL |
| 状态控制器 (`features/*/_controller.dart`) | StateNotifier | 直接复用 |
| 页面 UI (`features/*/*_page.dart`) | 无 | 全部新建 |
| 通用 Widget (`widgets/`) | async_page_state.dart | 复制并适配移动端 |
| Theme (`core/theme/app_theme.dart`) | 无 | 新建 iOS 风格主题 |

---

## 三、界面设计规范

### 3.1 iOS 风格设计语言

| 设计元素 | 规范 |
| --- | --- |
| **导航栏** | 大标题风格 (Large Title)，背景纯色 |
| **圆角** | 卡片圆角 12px，按钮圆角 10px，输入框圆角 8px |
| **间距** | 页面内边距 16px，元素间距 12px，卡片间距 8px |
| **阴影** | 卡片阴影极淡 `opacity: 0.05, blur: 10, offset: (0, 2)` |
| **头像** | 圆形（border-radius: 50%） |
| **字体** | 系统字体，标题 18px，正文 15px，辅助文字 13px |
| **颜色** | 主色 #155E75，强调色 #E06C4E，背景 #F5F5F7 |
| **列表** | 无分割线，改用间距分隔 |
| **底部 Tab** | BottomNavigationBar，图标 + 文字，未选中灰色，选中主色 |

### 3.2 颜色规范（已定义于 mobile_theme.dart）

```dart
// 品牌色
primary: #155E75
accent: #E06C4E

// 背景色
background: #F5F5F7
surface: #FFFFFF
cardBackground: #FFFFFF

// 文字色
textPrimary: #1D1D1F
textSecondary: #8E8E93
textTertiary: #C7C7CC

// 状态色
success: #34C759
warning: #FF9500
error: #FF3B30
```

### 3.3 页面设计 ASCII 示意

#### 首页

```
┌─────────────────────────────────┐
│  西电树洞                  🔔   │ ← Large Title AppBar
├─────────────────────────────────┤
│  [全部] [学习] [二手] [找搭子] →  │ ← 横向滚动频道 Chip
│  [失物] [吐槽]                   │
├─────────────────────────────────┤
│  ┌───────────────────────────┐ │
│  │ [频道]            3小时前  │ │
│  │ 帖子标题文字               │ │
│  │ 帖子内容摘要，最多显示两行  │ │
│  │ ┌─────┐┌─────┐┌─────┐     │ │
│  │ │ IMG ││ IMG ││ +2  │     │ │
│  │ └─────┘└─────┘└─────┘     │ │
│  │ ♡ 12   ★ 5   💬 8         │ │
│  └───────────────────────────┘ │
│           ... 更多帖子卡片 ...    │
├─────────────────────────────────┤
│  🏠    🔍    💬    ⭐    👤   │ ← 底部 Tab
└─────────────────────────────────┘
```

#### 帖子详情页

```
┌─────────────────────────────────┐
│ ← 返回              更多 ∙∙∙   │
├─────────────────────────────────┤
│ ┌──┐  匿名同学        3小时前  │
│ │头像│ 🔖 进行中                │
│ └──┘                            │
│ 帖子标题文字（加粗，18px）        │
│                                 │
│ 帖子正文内容，支持多段落。        │
│                                 │
│ ┌─────┐┌─────┐┌─────┐         │
│ │ IMG ││ IMG ││ IMG │         │
│ └─────┘└─────┘└─────┘         │
│ ────────────────────────────── │
│ 💬 8 条评论                    │
│ ────────────────────────────── │
│ ┌──┐  评论者昵称    2小时前    │
│ │头像│ 评论内容文字...          │
│ └──┘ ♡ 3                      │
│           ... 更多评论 ...       │
├─────────────────────────────────┤
│ ┌─────────────────────┐ [发送] │
│ │ 输入评论...       😀 📷 │     │
│ └─────────────────────┘       │
└─────────────────────────────────┘
```

#### 发帖页

```
┌─────────────────────────────────┐
│ 取消          发帖         发布  │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐│
│ │ 标题（选填，不超过50字）      ││
│ └─────────────────────────────┘│
│ ┌─────────────────────────────┐│
│ │ 正文内容...                   ││
│ │                       😀 📷  ││ ← 自适应高度
│ └─────────────────────────────┘│
│ 频道: [▼ 选择频道]              │
│ ☑️ 允许评论  ☑️ 允许私信        │
│ ┌────┐┌────┐┌────┐            │
│ │ +  ││ IMG││ IMG│            │
│ └────┘└────┘└────┘            │
└─────────────────────────────────┘
```

#### 通知中心页

```
┌─────────────────────────────────┐
│ 通知中心              全部已读  │
├─────────────────────────────────┤
│ 🔴 你有 5 条新通知              │
│ ────────────────────────────── │
│ 💬  用户A 评论了你的帖子         │
│    "写得很好！"         3小时前  │
│ 🔥  用户B 点赞了你的帖子        │
│    "求助帖"             昨天    │
│ ⭐  用户C 收藏了你的帖子         │
│    "期末资料"           2天前   │
│ 📢  平台更新通知                │
│    新功能上线公告...      1周前  │
└─────────────────────────────────┘
```

---

## 四、功能开发清单

### 4.1 第一阶段：项目搭建与基础架构 ✅

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 1.1 创建 lib_mobile 目录结构 | 按照架构创建目录和文件占位 | P0 | ✅ 完成 |
| 1.2 创建移动端主题 mobile_theme.dart | iOS 风格配色、字体、圆角规范 | P0 | ✅ 完成 |
| 1.3 创建移动端入口 main.dart | 初始化 Flutter + Riverpod | P0 | ✅ 完成 |
| 1.4 创建路由 app_router.dart | go_router 路由配置 + 权限守卫 | P0 | ✅ 完成 |
| 1.5 创建状态 providers | Riverpod Provider 配置 | P0 | ✅ 完成 |
| 1.6 创建移动端配置 mobile_config.dart | API_BASE_URL 配置 | P0 | ✅ 完成 |
| 1.7 创建 App Shell | MobileShell + 底部 Tab 导航 | P0 | 🟡 部分完成 |
| 1.8 修改 pubspec.yaml | 添加移动端专用依赖 | P0 | ⬜ 待完成 |
| 1.9 配置 Android 权限 | build.gradle + AndroidManifest | P0 | ⬜ 待完成 |
| 1.10 配置 iOS 权限 | Info.plist 相机/相册权限 | P0 | ⬜ 待完成 |
| 1.11 创建 Git 分支 | 创建 `feature/mobile-app` 分支 | P0 | ⬜ 待完成 |

### 4.2 第二阶段：登录认证流程 🟡

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 2.1 登录页 UI | 学号/邮箱 + 密码登录，iOS 风格 | P0 | 🟡 部分完成 |
| 2.2 注册页 UI | 邮箱注册流程 | P0 | 🟡 部分完成 |
| 2.3 邮箱验证页 UI | 验证码输入界面 | P0 | 🟡 部分完成 |
| 2.4 找回密码页 UI | 密码重置流程 | P1 | 🟡 部分完成 |
| 2.5 认证状态持久化 | SharedPreferences Token 管理 | P0 | ✅ 完成（复用） |
| 2.6 管理员登录入口 | 独立管理员登录页面 | P1 | ⬜ 待创建 |
| 2.7 登录注册流程联调 | 与后端 API 对接测试 | P0 | ⬜ 待完成 |

### 4.3 第三阶段：主框架与导航 ✅

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 3.1 底部导航栏 | BottomNavigationBar，5 个 Tab | P0 | ✅ 完成 |
| 3.2 App Shell | 主页面容器，路由管理 | P0 | ✅ 完成 |
| 3.3 首页框架 | Large Title 导航栏 + 频道筛选 | P0 | ✅ 完成 |
| 3.4 页面路由配置 | go_router 路由表定义 | P0 | ✅ 完成 |
| 3.5 权限拦截 | 未登录自动跳转登录页 | P0 | ✅ 完成 |

### 4.4 第四阶段：核心信息流 🟡

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 4.1 帖子卡片组件 | 移动端专用 PostCard | P0 | 🟡 部分完成 |
| 4.2 帖子列表下拉刷新 | PullToRefresh | P0 | ✅ 完成（复用） |
| 4.3 帖子列表上拉加载更多 | 翻页加载 | P0 | ⬜ 待完成 |
| 4.4 频道筛选交互 | 横向滚动 Chip 切换 | P0 | ⬜ 待完成 |
| 4.5 排序切换 | 热门/最新切换 | P0 | ⬜ 待完成 |
| 4.6 快捷发帖入口 | 首页悬浮按钮或导航栏按钮 | P0 | ⬜ 待完成 |

### 4.5 第五阶段：帖子详情与互动 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 5.1 帖子详情页 UI | 帖子正文 + 图片画廊 | P0 | ⬜ 待创建 |
| 5.2 图片画廊组件 | 点击放大、手势缩放、滑动切换 | P0 | ⬜ 待创建 |
| 5.3 评论列表 UI | 嵌套评论展示 | P0 | ⬜ 待创建 |
| 5.4 评论输入框 | 固定底部输入栏 + 表情 + 图片 | P0 | ⬜ 待创建 |
| 5.5 点赞/收藏交互 | 乐观更新 | P0 | ⬜ 待完成 |
| 5.6 举报功能 | 底部弹出举报选项 | P0 | ⬜ 待创建 |
| 5.7 分享功能 | 原生分享 | P1 | ⬜ 待创建 |

### 4.6 第六阶段：发帖功能 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 6.1 发帖页 UI | 标题 + 正文 + 频道 + 标签 | P0 | ⬜ 待创建 |
| 6.2 富文本输入 | 多行文本输入框 | P0 | ⬜ 待创建 |
| 6.3 图片选择与上传 | 多图选择 + 预览 + 删除 | P0 | ⬜ 待创建 |
| 6.4 频道/标签选择器 | 底部弹出选择器 | P0 | ⬜ 待创建 |
| 6.5 选项开关 | 允许评论/允许私信 | P0 | ⬜ 待创建 |
| 6.6 发布流程 | 进度提示 + 成功后跳转 | P0 | ⬜ 待创建 |
| 6.7 编辑/删除帖子 | 我的帖子管理 | P1 | ⬜ 待创建 |

### 4.7 第七阶段：搜索功能 🟡

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 7.1 搜索页 UI | 搜索框 + 历史记录 | P0 | 🟡 部分完成 |
| 7.2 搜索历史 | 本地存储最近搜索 | P0 | ✅ 完成 |
| 7.3 搜索结果列表 | 帖子卡片列表 | P0 | ⬜ 待完成 |
| 7.4 筛选功能 | 频道/状态/有图筛选 | P1 | ⬜ 待创建 |
| 7.5 热门搜索词 | 后端获取热门标签 | P1 | ⬜ 待创建 |

### 4.8 第八阶段：私信与消息 🟡

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 8.1 消息中心 UI | 申请列表 + 会话列表 Tab | P0 | 🟡 部分完成 |
| 8.2 私信申请处理 | 同意/拒绝操作 | P0 | ⬜ 待完成 |
| 8.3 会话列表 UI | 头像 + 昵称 + 最新消息 + 未读数 | P0 | ⬜ 待完成 |
| 8.4 聊天页 UI | 消息气泡 + 时间戳 | P0 | ⬜ 待创建 |
| 8.5 消息发送与接收 | 乐观更新发送 | P0 | ⬜ 待完成 |
| 8.6 未读消息红点 | 消息数角标 | P0 | ✅ 完成 |
| 8.7 会话删除 | 左滑删除 | P1 | ⬜ 待创建 |

### 4.9 第九阶段：个人中心 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 9.1 个人中心页 UI | 头像 + 资料 + 菜单列表 | P0 | ⬜ 待创建 |
| 9.2 编辑资料页 | 昵称/学号修改 | P0 | ⬜ 待创建 |
| 9.3 头像上传 | 图片裁剪 + 上传 | P0 | ⬜ 待创建 |
| 9.4 我的帖子列表 | 管理已发帖 | P0 | ⬜ 待创建 |
| 9.5 我的评论列表 | 评论历史 | P0 | ⬜ 待创建 |
| 9.6 隐私设置 | 陌生人私信/联系方式可见 | P1 | ⬜ 待创建 |
| 9.7 账号注销申请 | 注销流程 | P1 | ⬜ 待创建 |
| 9.8 退出登录 | 清理 Token + 跳转登录 | P0 | ⬜ 待创建 |

### 4.10 第十阶段：收藏功能 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 10.1 收藏列表页 UI | 帖子卡片列表 | P0 | ⬜ 待创建 |
| 10.2 取消收藏 | 滑动或长按取消 | P0 | ⬜ 待创建 |
| 10.3 空状态 UI | 无收藏时占位图 | P0 | ⬜ 待创建 |

### 4.11 第十一阶段：通知中心 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 11.1 通知列表 UI | 分类型展示通知 | P0 | ⬜ 待创建 |
| 11.2 通知类型图标 | 评论/点赞/收藏/系统公告 | P0 | ⬜ 待创建 |
| 11.3 标记已读 | 单条 + 全部已读 | P0 | ⬜ 待完成 |
| 11.4 未读数角标 | TabBar 红点 + 数字 | P0 | ✅ 完成 |
| 11.5 通知跳转 | 点击跳转对应帖子/内容 | P0 | ⬜ 待创建 |

### 4.12 第十二阶段：管理员后台 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 12.1 管理员登录 | 独立入口 | P1 | ⬜ 待创建 |
| 12.2 管理后台概览 | 统计数据仪表盘 | P1 | ⬜ 待创建 |
| 12.3 内容审核 | 帖子/评论审核列表 | P1 | ⬜ 待创建 |
| 12.4 举报管理 | 举报处理流程 | P1 | ⬜ 待创建 |
| 12.5 图片审核 | 图片审核队列 | P1 | ⬜ 待创建 |
| 12.6 用户管理 | 禁言/封禁操作 | P1 | ⬜ 待创建 |
| 12.7 系统配置 | 频道/标签/敏感词管理 | P1 | ⬜ 待创建 |
| 12.8 发布公告 | 系统公告发布 | P1 | ⬜ 待创建 |

### 4.13 第十三阶段：优化与完善 ⬜

| 任务 | 描述 | 优先级 | 状态 |
| --- | --- | --- | --- |
| 13.1 骨架屏加载 | Shimmer 效果 | P1 | ⬜ 待创建 |
| 13.2 错误重试页 | 网络错误 + 重试按钮 | P0 | ⬜ 待创建 |
| 13.3 空状态页 | 各列表空状态设计 | P0 | ⬜ 待创建 |
| 13.4 图片懒加载 | CachedNetworkImage | P1 | ⬜ 待完成 |
| 13.5 Android APK 打包 | debug/release 构建 | P0 | ⬜ 待完成 |
| 13.6 iOS IPA 打包 | Xcode 打包配置 | P0 | ⬜ 待完成 |
| 13.7 黑暗模式 | 跟随系统暗黑模式 | P2 | 🟡 已定义（未激活） |
| 13.8 深链接支持 | App Links / Universal Links | P2 | ⬜ 待创建 |

---

## 五、API 对接清单

| 模块 | API 端点 | 对接状态 |
| --- | --- | --- |
| 认证 | `/api/auth/login`, `/api/auth/register`, `/api/auth/verify` | ✅ 已有 Repository |
| 帖子列表 | `/api/posts` (GET with filters) | ✅ 已有 Repository |
| 帖子详情 | `/api/posts/<id>` | ✅ 已有 Repository |
| 发布帖子 | `/api/posts` (POST) | ✅ 已有 Repository |
| 评论列表 | `/api/posts/<id>/comments` | ✅ 已有 Repository |
| 发布评论 | `/api/posts/<id>/comments` (POST) | ✅ 已有 Repository |
| 点赞/收藏 | `/api/posts/<id>/like`, `/api/posts/<id>/favorite` | ✅ 已有 Repository |
| 搜索 | `/api/posts` (GET with keyword) | ✅ 已有 Repository |
| 私信申请 | `/api/messages/requests` | ✅ 已有 Repository |
| 会话列表 | `/api/messages/conversations` | ✅ 已有 Repository |
| 发送消息 | `/api/messages` | ✅ 已有 Repository |
| 通知列表 | `/api/notifications` | ✅ 已有 Repository |
| 标记已读 | `/api/notifications/read-all` | ✅ 已有 Repository |
| 用户资料 | `/api/users/me` | ✅ 已有 Repository |
| 头像上传 | `/api/users/avatar` | ✅ 已有 Repository |
| 图片上传 | `/api/uploads/images` | ✅ 已有 Repository |
| 举报 | `/api/reports` | ✅ 已有 Repository |
| 管理员 | `/api/admin/*` (全部端点) | ✅ 已有 Repository |

> **说明**: 所有后端 API 的 Repository 已存在于 `lib/repositories/`，移动端通过 `lib_mobile/core/state/mobile_providers.dart` 中的 Provider 注入复用。

---

## 六、数据模型映射

移动端直接复用现有数据模型，无需新建：

| 模型文件 | 使用场景 |
| --- | --- |
| `lib/models/post_item.dart` | 帖子列表、详情、收藏 |
| `lib/models/comment_item.dart` | 评论列表 |
| `lib/models/user_profile.dart` | 个人资料、用户信息 |
| `lib/models/notification_item.dart` | 通知列表 |
| `lib/models/conversation_item.dart` | 私信会话列表 |
| `lib/models/direct_message_item.dart` | 聊天消息 |
| `lib/models/report_item.dart` | 举报列表 |
| `lib/models/dm_request_item.dart` | 私信申请 |
| `lib/models/uploaded_image_item.dart` | 图片上传结果 |
| `lib/models/admin_models.dart` | 管理员后台数据 |
| `lib/models/my_comment_item.dart` | 我的评论 |

---

## 七、状态管理方案

### 7.1 Riverpod Provider 架构（已定义于 mobile_providers.dart）

```dart
// lib_mobile/core/state/mobile_providers.dart

// API Client
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

// Repository Providers
final authRepositoryProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(ref.read(apiClientProvider)));
final postRepositoryProvider = Provider<PostRepository>((ref) =>
    PostRepository(ref.read(apiClientProvider)));
final userRepositoryProvider = Provider<UserRepository>((ref) =>
    UserRepository(ref.read(apiClientProvider)));
final messageRepositoryProvider = Provider<MessageRepository>((ref) =>
    MessageRepository(ref.read(apiClientProvider)));
final notificationRepositoryProvider = Provider<NotificationRepository>((ref) =>
    NotificationRepository(ref.read(apiClientProvider)));
final adminRepositoryProvider = Provider<AdminRepository>((ref) =>
    AdminRepository(ref.read(apiClientProvider)));

// Controller Providers - 复用 Web 端
final feedControllerProvider = feedControllerProvider;
final searchControllerProvider = searchControllerProvider;
final messagesControllerProvider = messagesControllerProvider;
final notificationsControllerProvider = notificationsControllerProvider;

// 移动端专用 Providers
final currentTabIndexProvider = StateProvider<int>((ref) => 0);
final skeletonLoadingProvider = StateProvider<bool>((ref) => false);
final notificationUnreadCountProvider = Provider<int>((ref) =>
    ref.watch(notificationsControllerProvider).unreadCount);
final messageUnreadCountProvider = Provider<int>((ref) =>
    ref.watch(messagesControllerProvider).conversations.fold<int>(
        0, (int sum, item) => sum + item.unreadCount));

// 搜索历史
final searchHistoryProvider = StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) =>
    SearchHistoryNotifier());
```

---

## 八、路由设计方案

### 8.1 路由表（已定义于 app_router.dart）

```dart
// 认证路由（未登录状态）
/auth/login          → LoginPage
/auth/register       → RegisterPage
/auth/verify         → VerifyPage
/auth/reset-password → ResetPasswordPage

// 主页面（底部 Tab 导航，StatefulShellRoute.indexedStack）
/                    → HomePage       （首页）
/search              → SearchPage     （搜索）
/messages            → MessagesPage   （消息）
/favorites           → FavoritesPage  （收藏）
/profile             → ProfilePage    （我的）

// 全屏页面（不在 Tab 内）
/post/create         → CreatePostPage
/post/:id            → PostDetailPage
/chat/:conversationId → ChatPage
/notifications       → NotificationCenterPage
/profile/edit        → EditProfilePage
/profile/settings    → SettingsPage
/profile/posts       → MyPostsPage
/profile/comments    → MyCommentsPage
/profile/reports     → MyReportsPage

// 管理员路由
/admin/login         → AdminLoginPage
/admin               → AdminConsolePage
```

### 8.2 权限守卫逻辑

```
未登录用户访问非 auth 路由 → 跳转 /auth/login
已登录用户访问 auth 路由    → 跳转 /
未登录管理员访问 /admin/*   → 跳转 /admin/login
已登录管理员访问 /admin/login → 跳转 /admin
```

---

## 九、开发里程碑

```
里程碑 1: 项目基础搭建 ✅ (2026-03-22)
  ├── lib_mobile 目录结构创建         ✅
  ├── 核心配置 (theme, router, state) ✅
  ├── 移动端入口 main.dart            ✅
  └── 能跑通一个空白页面基础           ✅

里程碑 2: 登录认证 🟡
  ├── 用户登录/注册/验证 UI           🟡 部分完成
  ├── 认证状态持久化                  ✅ (复用)
  └── 管理员登录                     ⬜

里程碑 3: 主框架上线 ✅
  ├── 5 个 Tab 底部导航              ✅
  ├── 首页信息流                     🟡 部分完成
  └── 路由和权限拦截                 ✅

里程碑 4: 核心发帖功能 ⬜
  ├── 发帖 + 图片上传
  ├── 帖子详情
  └── 评论/回复

里程碑 5: 社交互动 ⬜
  ├── 点赞/收藏
  ├── 搜索
  ├── 私信
  └── 通知中心

里程碑 6: 个人中心 ⬜
  ├── 资料编辑
  ├── 我的帖子/评论/收藏
  └── 隐私设置

里程碑 7: 管理员后台 ⬜
  └── 管理员全部功能

里程碑 8: 优化与发布 ⬜
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
6. **深色模式**: Web 端是浅色，移动端如要支持暗黑需额外设计一套暗色主题（已定义 darkTheme，待激活）
7. **iOS 审核**: 涉及用户生成内容(UGC)需要内容审核机制，App Store 可能要求隐私政策等
8. **pubspec.yaml 更新**: 当前 pubspec.yaml 尚未添加移动端专用依赖（go_router, cached_network_image, image_picker, shimmer 等）

---

## 十一、开发指南

### 11.1 启动移动端

```bash
# 安装依赖
flutter pub get

# Android 调试
flutter run -d android

# iOS 模拟器
flutter run -d iphone

# 指定 API 地址
flutter run -d chrome --dart-define=MOBILE_API_BASE_URL=http://127.0.0.1:8080/api
```

### 11.2 打包命令

```bash
# Android
flutter build apk --release
flutter build apk --debug

# iOS（需在 macOS + Xcode 环境下）
flutter build ios --release
flutter build ios --simulator --no-codesign
```

### 11.3 代码规范

- 页面文件：`*_page.dart`
- 组件文件：`*_widget.dart`
- 状态控制器：复用 `lib/features/*/` 下的现有 Controller
- 移动端专用组件放在 `lib_mobile/widgets/`
- 使用 `../../lib/` 相对路径导入共享代码
- 遵循 iOS 风格设计语言（见第三章）

### 11.4 新增页面流程

1. 在 `lib_mobile/features/<feature>/` 下创建 `*_page.dart`
2. 在 `app_router.dart` 中注册路由
3. 如需新组件，在 `lib_mobile/widgets/` 下创建
4. 如需复用 Web 端 Controller，通过 `mobile_providers.dart` 注入

---

## 十二、后续扩展方向（不在本次计划内）

1. **推送通知**: 集成 FCM 或极光推送
2. **深色模式**: 完整暗色主题支持
3. **深链接**: 从外部链接直接打开 App 内特定页面
4. **评论图片**: 当前 Web 端评论不支持图片，移动端可扩展
5. **语音/视频**: 帖子支持音视频内容
6. **微信/QQ 登录**: 第三方社交账号登录
7. **表情包功能**: 增强版表情选择器
8. **草稿箱**: 发帖草稿自动保存
9. **版本更新**: App 内检测更新提示

---

## 附录：文件清单

### 已完成文件

| 文件路径 | 说明 |
| --- | --- |
| `lib_mobile/main.dart` | 移动端入口，初始化 + ProviderScope |
| `lib_mobile/lib_mobile.dart` | 库入口文件 |
| `lib_mobile/core/config/mobile_config.dart` | API_BASE_URL 配置 |
| `lib_mobile/core/theme/mobile_theme.dart` | iOS 风格主题定义 |
| `lib_mobile/core/navigation/app_router.dart` | go_router 路由配置 |
| `lib_mobile/core/state/mobile_providers.dart` | Riverpod Provider 配置 |
| `lib_mobile/features/shell/mobile_shell.dart` | 主 Shell + 底部导航 |
| `lib_mobile/features/auth/login_page.dart` | 登录页（部分实现） |
| `lib_mobile/features/auth/register_page.dart` | 注册页（部分实现） |
| `lib_mobile/features/auth/verify_page.dart` | 验证页（部分实现） |
| `lib_mobile/features/auth/reset_password_page.dart` | 找回密码页（部分实现） |
| `lib_mobile/features/home/home_page.dart` | 首页（部分实现） |
| `lib_mobile/features/search/search_page.dart` | 搜索页（部分实现） |
| `lib_mobile/features/messages/messages_page.dart` | 消息页（部分实现） |

### 待创建文件

| 文件路径 | 说明 |
| --- | --- |
| `lib_mobile/features/home/post_card.dart` | 帖子卡片组件 |
| `lib_mobile/features/post/post_detail_page.dart` | 帖子详情页 |
| `lib_mobile/features/post/create_post_page.dart` | 发帖页 |
| `lib_mobile/features/messages/chat_page.dart` | 聊天页 |
| `lib_mobile/features/favorites/favorites_page.dart` | 收藏页 |
| `lib_mobile/features/profile/profile_page.dart` | 个人中心页 |
| `lib_mobile/features/profile/edit_profile_page.dart` | 编辑资料页 |
| `lib_mobile/features/profile/settings_page.dart` | 设置页 |
| `lib_mobile/features/profile/my_posts_page.dart` | 我的帖子页 |
| `lib_mobile/features/profile/my_comments_page.dart` | 我的评论页 |
| `lib_mobile/features/profile/my_reports_page.dart` | 我的举报页 |
| `lib_mobile/features/notifications/notification_center_page.dart` | 通知中心页 |
| `lib_mobile/features/admin/admin_login_page.dart` | 管理员登录页 |
| `lib_mobile/features/admin/admin_console_page.dart` | 管理员后台页 |
| `lib_mobile/widgets/comment_tile.dart` | 评论列表项组件 |
| `lib_mobile/widgets/input_bar.dart` | 输入框组件 |
| `lib_mobile/widgets/emoji_bar.dart` | 表情栏组件 |
| `lib_mobile/widgets/avatar_widget.dart` | 头像组件 |
| `lib_mobile/widgets/loading_states.dart` | 加载状态组件 |
