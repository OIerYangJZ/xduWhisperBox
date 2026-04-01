# See电 — 西电树洞

面向西安电子科技大学校内用户的匿名社区应用，采用 Flutter 跨端技术栈构建，同时支持 **Web 端**和**移动端（Android / iOS）**。应用内嵌 [XDYou（原 Traintime PDA）](https://github.com/BenderBlog/traintime_pda) 子模块，提供课表、成绩、电费、图书馆等校园服务。

## 技术栈

| 层级 | 技术 |
|------|------|
| 前端 | Flutter Web + Dart SDK `>=3.8.0 <4.0.0` |
| 状态管理 | `flutter_riverpod: ^2.6.1` + GetX（仅移动端 XDYou 子模块） |
| HTTP 客户端 | `http: ^1.2.2` |
| 本地存储 | `shared_preferences: ^2.3.2` |
| 后端 | Python 3（标准库 HTTP 服务：`http.server + ThreadingHTTPServer`） |
| 数据库 | SQLite（WAL 模式） |
| 对象存储 | 本地文件系统 / 可选 S3 兼容存储（`boto3 >=1.34,<2.0`） |
| 部署 | Docker / 腾讯云 Ubuntu 22.04 + Nginx + systemd |

## 核心功能

### 社区交流

- **帖子发布与浏览**：支持频道分类（表白/吐槽/学习/生活等）、多图上传、热度排序
- **评论与回复**：嵌套评论树（最多3层缩进），回复 `@alias` 提醒
- **点赞、收藏与阅读量**：阅读量通过独立端点计入热度算法（防刷：每用户每帖每天计1次）
- **搜索与筛选**：关键词、频道、状态、有图、可私信等组合条件过滤
- **热度算法**：`likes × 2 + comments × 3 + viewCount - ts/1e9`

### 用户体系

- **统一身份认证登录**：学号 + 统一认证密码（`@stu.xidian.edu.cn` 自动拼接），单次登录凭证跨端同步
- **用户等级体系**：一级用户（享有直接置顶帖子权限）、二级用户
- **匿名发帖**：前台完全匿名，管理员后台可追溯真实账号
- **个人中心**：资料查看、头像上传、我的帖子、我的评论、我的收藏、我的举报
- **账号注销申请**：双重确认 + 密码验证

### 社交互动

- **私信直接进入（微信模式）**：无需申请流程，直接创建/进入会话
- **会话屏蔽（拉黑）**：屏蔽后禁止继续发起私信和发送消息
- **消息未读数与已读状态**：Badge 红点跟随 Tab 栏显示
- **长按气泡操作菜单**：复制 / 删除 / 查看详情
- **关注/粉丝系统**：互相关注标记为好友

### 通知中心

- 评论通知、回复通知、点赞通知、收藏通知
- 举报处理结果通知
- 系统公告通知
- 未读数提示与一键已读

### 管理员后台

- 多管理员分级（一级管理员 / 二级管理员）
- 内容审核与批量审核
- 图片审核
- 举报处理
- Android Release 发布管理（上传 APK、维护版本号/更新说明、设置强制更新）
- 用户管理（账号状态管理、注销/恢复）
- 申诉处理
- 数据导出（CSV）
- 敏感词与系统配置管理
- 帖子置顶审批
- 一级用户升级申请审批

### 合规与说明

- 用户协议、隐私政策、社区规范、举报说明

### 移动端专属功能

- **登录/注册页**：`XduLoginPage`，统一身份认证入口，管理登录和 Admin 登录两个入口
- **设置主页**：`SettingsMainPage`，账号安全 / 隐私开关（陌生私信、联系方式可见）/ 通知 / 外观（主题、语言）/ 账号注销
- **版本更新与安装包下载**：Web 端提供 Android Release 下载页，移动端设置页支持检查新版本并跳转下载
- **XDYou 校园服务**（嵌入底部「校园」Tab）：课表、成绩、电费、空教室、图书馆、运动打卡、宿舍水费通知等
- **帖子详情页**：`PostDetailPage`，操作栏（点赞/收藏/评论/分享）内置于正文与评论区之间，支持嵌套评论树、举报流程、关注/私信作者、表情输入
- **表情输入组件**：`EmojiPickerBar`，96 个常用 emoji 网格，与键盘互斥（展开时收起键盘防止布局空白）
- **消息页**：`MessagesPage`，会话列表直接展示，无 Tab 切换；头像使用 `CachedNetworkImage` 正确加载

---

## 目录结构

```
xduWhisperBox/
├── backend/                        # Python 后端（模块化架构）
│   ├── server.py                   # 核心入口 (~745行)，路由分发 + 服务器启动
│   ├── _globals.py                 # 全局状态单点：配置常量 + 运行时对象
│   ├── sql_repository.py           # SQLite schema、初始化、持久化逻辑 (~1712行)
│   ├── object_storage.py           # 对象存储（本地 / S3 兼容）(~258行)
│   ├── reset_db.py                 # 数据库重置脚本
│   ├── migrate_json_to_sql.py      # JSON → SQL 迁移脚本
│   ├── helpers/                    # 通用辅助函数
│   │   ├── _auth_helpers.py        # 密码哈希、邮箱验证、ID 解析
│   │   ├── _datetime_helpers.py    # 时间/时区处理
│   │   ├── _http_helpers.py        # HTTP 响应（json_error、send_json 等）
│   │   ├── _mailer.py              # 邮件发送（验证邮件、密码重置邮件）
│   │   └── _rate_limit.py          # 限流、IP 检查、文本风险评估
│   ├── handlers/                   # HTTP 请求处理层（按功能域拆分）
│   │   ├── _auth_handler.py        # 认证：登录/注册/登出/验证码/密码重置
│   │   ├── _post_handler.py        # 帖子：CRUD/点赞/收藏/举报/申诉/置顶申请
│   │   ├── _comment_handler.py     # 评论创建/删除；账号注销申请/等级升级
│   │   ├── _message_handler.py     # 私信：申请/接受/拒绝/会话/消息/屏蔽
│   │   ├── _user_handler.py        # 用户：个人资料/关注/粉丝/好友
│   │   ├── _notification_handler.py # 通知：列表/标记已读/全部已读
│   │   ├── _admin_handler.py       # 管理后台：审核/举报/用户/配置/公告等
│   │   ├── _upload_handler.py       # 文件上传：头像上传/图片上传
│   │   └── _static_handler.py      # 静态文件：存储文件读取/Web 兜底
│   ├── services/                   # 业务逻辑层
│   │   ├── _db_service.py          # 数据库操作：查询/序列化/管理员构建函数
│   │   └── _user_service.py        # 用户业务：通知创建/会话同步/数据规范化
│   └── sql/                        # SQL schema 文件
│       ├── schema_mysql.sql
│       └── schema_postgresql.sql
├── lib/                            # Flutter Web 前端
│   ├── core/                       # 核心基础设施
│   │   ├── auth/                   # 鉴权（AuthStore、AdminAuthStore）
│   │   ├── config/                 # AppConfig、API_BASE_URL 解析
│   │   ├── emoji/                  # 表情目录 + 用户偏好
│   │   ├── media/                  # 媒体处理（图片选择器 Web/Mobile 条件编译）
│   │   ├── navigation/             # 导航（GoRouter）
│   │   ├── network/                # 网络请求（ApiClient、ApiEndpoints、JsonUtils）
│   │   ├── state/                  # AppProviders（Riverpod 全局 Provider）
│   │   ├── theme/                  # 主题（AppTheme + SharedColors 统一跨端颜色）
│   │   └── utils/                  # 工具函数（Web 文件下载）
│   ├── data/                       # Mock 数据
│   ├── features/                   # 功能模块（Web 端）
│   │   ├── admin/                  # 管理员后台
│   │   ├── auth/                   # 登录/注册/验证码/密码重置
│   │   ├── favorites/              # 收藏
│   │   ├── feed/                   # 信息流
│   │   ├── legal/                  # 合规说明页（用户协议/隐私政策等）
│   │   ├── me/                     # 个人中心
│   │   ├── messages/               # 私信（会话列表 + 聊天）
│   │   ├── notifications/           # 通知中心
│   │   ├── post/                   # 发帖/帖子详情
│   │   └── search/                # 搜索
│   ├── models/                     # 数据模型
│   │   └── admin/                  # 管理员模型子目录（9 个独立文件）
│   ├── repositories/               # Repository 层
│   └── widgets/                    # 公共组件
├── lib/mobile/                     # Flutter 移动端（Android / iOS）
│   ├── core/                       # 核心基础设施
│   │   ├── config/                 # MobileConfig（移动端 API 地址）
│   │   ├── navigation/             # 移动端路由（app_router）
│   │   ├── state/                  # AppSettingsStore + MobileProviders
│   │   └── theme/                  # MobileTheme + SharedColors
│   ├── features/                   # 功能模块（移动端独立实现）
│   │   ├── admin/                  # 管理员后台（移动端）
│   │   ├── auth/                   # XduLoginPage（统一身份认证登录）
│   │   ├── feed/                   # 首页信息流
│   │   ├── messages/               # 消息页（会话列表 + 聊天）
│   │   ├── notifications/           # 通知中心
│   │   ├── post/                   # 发帖/帖子详情/评论输入栏
│   │   ├── profile/                # 个人中心/设置主页
│   │   ├── search/                # 搜索
│   │   └── widgets/                # 移动端公共组件
│   ├── integrations/               # XDYou 集成层（移动端）
│   │   ├── xdyou_bootstrap.dart    # 真机实现：初始化 + 状态同步
│   │   ├── xdyou_bootstrap_stub.dart # Web stub：所有函数为空操作
│   │   └── xdyou_sync_bridge.dart   # 函数指针桥接层（打破循环依赖）
│   ├── main.dart                  # 移动端入口
│   └── lib_mobile.dart            # 移动端 barrel file
├── packages/                       # 可选本地依赖（gitignore，见 scripts/setup_xdyou.sh）
│   └── traintime_pda/              # XDYou 子 App（移动端嵌入，MPL-2.0）
│       └── lib/
│           ├── controller/
│           │   └── theme_controller.dart  # XDYou 主题/语言控制器（读取 treehole_* 覆写）
│           ├── page/
│           │   ├── homepage/
│           │   │   ├── home_card_padding.dart  # 通用卡片样式扩展
│           │   │   └── homepage.dart            # XDYou 主仪表盘
│           │   └── setting/
│           │       └── setting.dart             # XDYou 设置页
│           └── themes/
│               └── color_seed.dart              # XDYou 品牌色定义（与树洞对齐）
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
├── web/                            # Web 静态资源
├── pubspec.yaml                    # Flutter 依赖配置
├── analysis_options.yaml           # Dart Lint 配置（排除 traintime_pda 目录）
├── .gitignore                      # Git 忽略配置
├── PROJECT.md                      # 项目进程文档
└── README.md                       # 项目主说明
```

---

## 快速开始

### 前置依赖

- Flutter SDK `>=3.8.0 <4.0.0`
- Python 3.10+
- SQLite3
- （可选）Docker + Docker Compose

### 1. 克隆项目

```bash
git clone https://github.com/YOUR_USERNAME/xduWhisperBox.git
cd xduWhisperBox
```

### 2. 后端启动

```bash
cd backend

# 安装可选依赖（仅 S3 存储需要）
pip install boto3

# 配置环境变量（复制模板后修改）
cp deploy/tencent/backend.env.example .env

# 启动后端（默认端口 8080）
python3 server.py
```

后端启动后会：
- 自动创建 `backend/data/treehole.db`（SQLite WAL 模式）
- 初始化种子数据（默认管理员账号、示例帖子）
- 启动 HTTP 服务器

**默认管理员账号：** `admin` / `admin123456`（生产环境必须修改）

### 3. 前端启动

```bash
# 安装依赖（CI 会自动拉取 traintime_pda 子模块）
flutter pub get

# Web 开发服务器（默认连接 localhost:8080）
flutter run -d chrome

# Android APK（需要 Android SDK）
flutter build apk --release
```

**移动端 API 地址：** 移动端默认连接 `http://81.69.16.134/api`（腾讯云公网 IP），可通过 `--dart-define=MOBILE_API_BASE_URL=...` 覆盖。  
**统一认证注意：** 正式分发时，若移动端 API 仍走 IP / 非 HTTPS 地址，必须额外注入 `--dart-define=MOBILE_XIDIAN_PUBLIC_ORIGIN=https://IDS已登记域名`，否则会出现“应用未注册”。

**Android Release 分发说明：**

- 默认对外分发通用包：`build/app/outputs/flutter-apk/app-release.apk`
- 当前 Release APK 最低支持 **Android 7.0（API 24）**
- `app-arm64-v8a-release.apk` 为 ARM64 单架构包，仅在确认用户设备架构兼容时再单独分发

### Android 发布签名

团队统一使用同一份 Android 上传签名，不要各自生成新的 keystore。

1. 将统一分发的 `upload-keystore.jks` 放到 `android/keystore/upload-keystore.jks`
2. 复制 `android/key.properties.example` 为 `android/key.properties`
3. 在 `android/key.properties` 中填写真实密码
4. 执行 `keytool -list -v -keystore android/keystore/upload-keystore.jks -alias xdu_whisper_box`，确认指纹一致

当前统一核对指纹：

- `SHA1: D0:1C:86:62:29:A0:7A:66:CF:3C:DE:C1:25:EF:DC:8B:E0:C5:6A:81`
- `SHA256: 48:D6:B0:E3:F1:19:DF:91:3D:ED:AD:8E:8F:2D:C8:24:B0:36:99:5D:F0:50:94:A6:3C:1E:23:A1:45:9D:3E:1B`

说明：

- 仓库不会提交真实 `android/key.properties`
- 仓库不会提交真实 `android/keystore/upload-keystore.jks`
- 如果缺少这两个本地文件，`flutter build apk --release` 会直接失败，避免误用 debug 签名发布

### 4. Docker 方式启动后端

```bash
# 仅后端
docker compose up backend -d

# 后端 + Nginx 反向代理
docker compose up -d
```

---

## 环境变量

后端通过环境变量配置，参考 `deploy/tencent/backend.env.example`：

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `BACKEND_HOST` | `0.0.0.0` | 监听地址 |
| `BACKEND_PORT` | `8080` | 监听端口 |
| `BACKEND_XIDIAN_PUBLIC_ORIGIN` | — | 统一认证固定回调外网 Origin，必须填写 IDS 已登记的 HTTPS 域名，例如 `https://treehole.example.com` |
| `BACKEND_DB_FILE` | `backend/data/treehole.db` | SQLite 数据库路径 |
| `BACKEND_STORAGE_DIR` | `backend/storage/objects` | 本地对象存储目录 |
| `BACKEND_WEB_ROOT` | `build/web` | Flutter Web 构建产物目录 |
| `BACKEND_OBJECT_STORAGE_BACKEND` | `local` | 存储后端（`local` 或 `s3`） |
| `BACKEND_ADMIN_USERNAME` | `admin` | 默认管理员用户名 |
| `BACKEND_ADMIN_PASSWORD` | `admin123456` | 默认管理员密码 |
| `BACKEND_SMTP_HOST` | — | SMTP 服务器地址 |
| `BACKEND_SMTP_PORT` | `465` | SMTP 端口 |
| `BACKEND_SMTP_USERNAME` | — | SMTP 用户名 |
| `BACKEND_SMTP_PASSWORD` | — | SMTP 密码/授权码 |
| `BACKEND_SMTP_FROM_EMAIL` | — | 发件人邮箱 |
| `BACKEND_ALLOW_DEBUG_VERIFY_CODE` | `false` | 允许调试验证码（生产必须 `false`） |
| `BACKEND_INCLUDE_DEBUG_CODE` | `false` | 响应包含调试信息（生产必须 `false`） |

**S3 存储配置**（当 `BACKEND_OBJECT_STORAGE_BACKEND=s3` 时）：

| 变量 | 说明 |
|------|------|
| `AWS_ACCESS_KEY_ID` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | AWS Secret Key |
| `AWS_REGION` | S3 区域（如 `ap-northeast-1`） |
| `AWS_S3_BUCKET` | S3 Bucket 名称 |

---

## 统一认证一次性对齐

如果你要启用“西电统一认证”并避免出现“应用未注册”，请一次性完成下面 4 件事：

1. 在 IDS 侧登记回调地址：
   `https://你的正式域名/api/auth/xidian/callback`
   `https://你的正式域名/api/auth/xidian/mobile/callback`
2. 服务器环境变量 `/etc/xdu-whisperbox.env` 中设置：
   `BACKEND_XIDIAN_PUBLIC_ORIGIN=https://你的正式域名`
3. Nginx 配置 `server_name` 改为同一个正式域名，并启用 HTTPS；80 端口只做跳转到 443。
4. 移动端正式构建使用：
   `flutter build apk --release --dart-define=MOBILE_API_BASE_URL=https://你的正式域名/api --dart-define=MOBILE_XIDIAN_PUBLIC_ORIGIN=https://你的正式域名`

说明：

- Web 端构建保持 `API_BASE_URL=/api` 即可，因为它通过同源 `/api` 访问后端。
- `BACKEND_XIDIAN_PUBLIC_ORIGIN`、Nginx `server_name`、IDS 已登记域名，这三者必须完全一致。
- 不建议用公网 IP 直接做统一认证回调；IDS 通常要求已登记的正式 HTTPS 域名。

---

## API 文档

后端启动后访问 `http://localhost:8080/api/` 根路径可查看可用端点。

### 主要端点

**认证**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/auth/send-code` | 发送邮箱验证码 |
| `POST` | `/api/auth/register` | 注册账号 |
| `POST` | `/api/auth/login` | 登录 |
| `POST` | `/api/auth/verify` | 验证邮箱 |
| `POST` | `/api/auth/logout` | 登出 |
| `POST` | `/api/auth/password/send-code` | 发送密码重置验证码 |
| `POST` | `/api/auth/password/reset` | 重置密码 |

**帖子**

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/posts` | 获取帖子列表（支持 channel、keyword、authorId 等过滤） |
| `POST` | `/api/posts` | 发布帖子 |
| `GET` | `/api/posts/{id}` | 获取帖子详情 |
| `POST` | `/api/posts/{id}/view` | 增加阅读量（防刷：每用户每帖每天计1次） |
| `POST` | `/api/posts/{id}/like` | 点赞 |
| `POST` | `/api/posts/{id}/favorite` | 收藏 |
| `DELETE` | `/api/posts/{id}/favorite` | 取消收藏 |
| `POST` | `/api/posts/{id}/comments` | 添加评论 |
| `POST` | `/api/reports` | 举报内容 |

**用户**

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/users/me` | 获取当前用户资料 |
| `PATCH` | `/api/users/me` | 更新个人资料 |
| `POST` | `/api/users/avatar` | 上传头像 |
| `POST` | `/api/users/{id}/follow` | 关注用户 |
| `POST` | `/api/users/{id}/unfollow` | 取消关注 |

**私信**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/messages/conversations/direct` | 直接创建/进入会话（微信模式） |
| `GET` | `/api/messages/conversations` | 会话列表 |
| `POST` | `/api/messages/conversations/{id}/messages` | 发送消息 |

**管理员**

| 方法 | 路径 | 说明 |
|------|------|------|
| `POST` | `/api/admin/auth/login` | 管理员登录 |
| `GET` | `/api/admin/overview` | 仪表盘统计 |
| `GET` | `/api/admin/reviews` | 内容审核列表 |
| `POST` | `/api/admin/reviews/batch` | 批量审核 |
| `GET` | `/api/admin/reports` | 举报处理列表 |
| `POST` | `/api/admin/reports/{id}/handle` | 处理举报 |
| `GET` | `/api/admin/users` | 用户管理 |
| `GET` | `/api/admin/export` | 数据导出 |

---

## 近期更新

- `2026-04-01`：补齐 **Android Release 发布与下载链路**。管理员后台现已支持维护 Android 安装包版本、更新说明、下载链接和强制更新标记；Web 端同步增加 Android 下载页与浏览器下载辅助入口。
- `2026-04-01`：完成 **设置页与致谢页整理**。移动端设置主页分组与入口文案优化，恢复完整开发者致谢名单与独立致谢页。
- `2026-04-01`：上线 **帖子详情与校园工具体验升级**。移动端帖子详情补充图片保存/复制、评论区间距优化；XDYou 首页/工具箱继续适配主 App 主题与导航结构。
- `2026-03-31 ~ 2026-04-01`：集中修复 **图片浏览与评论交互问题**。处理帖子详情图集滑动、评论操作气泡、返回栈和发帖页一级用户置顶控制等稳定性问题。
- `2026-03-31`：打通 **移动端通知设置**。后端完成通知偏好持久化字段与接口，移动端新增独立通知设置页，支持评论、回复、点赞、收藏、举报结果、系统通知逐项开关。

## 当前开发进度

- 正在接入 **应用内更新提示**：已新增移动端更新控制器与更新弹窗，准备把“检查更新 / 启动时提示新版本”接到设置页与启动流程。
- 正在拆分 **移动端设置页**：计划把 XDYou 原设置能力迁移到树洞主 App，细分为「一站式设置」「课表设置」等子页。
- 正在收口 **XDYou 旧设置入口**：继续清理子应用内部已废弃的颜色种子与旧主题入口，统一跟随树洞主题和语言同步策略。
- 正在优化 **Android 分发兼容性说明**：已确认当前 Release APK 最低支持 Android 7.0（API 24），后续会继续收敛分发流程并优先引导用户下载通用 `app-release.apk`。

---

## 跨端架构说明

### Web 端（`lib/`）

- 页面使用 `GoRouter` 管理路由
- 核心状态使用 Riverpod `StateNotifier`
- Repository 模式封装所有 HTTP 请求
- `lib/core/` 提供跨端可复用的网络、主题、鉴权基础设施

### 移动端（`lib/mobile/`）

- 独立入口 `lib/mobile/main.dart`，由 `lib/main.dart` 通过 `kIsWeb` 分流调用
- 移动端路由使用 `GoRouter`（`app_router.dart`），与 Web 端路由平行
- 移动端 Provider 层（`mobile_providers.dart`）复用 Web 端 Repository 的同时提供平台特定状态
- **条件编译**：使用 `if (dart.library.io)` 条件导入，Web 端使用 `xdyou_bootstrap_stub.dart`（空操作），移动端使用 `xdyou_bootstrap.dart`（真机实现）

### XDYou 子模块集成（仅移动端）

```
树洞主 App（lib/mobile/）
  │
  ├─ AppSettingsStore.instance          # 管理主题/语言/登录凭证
  │     ├─ setBrightness() → callSyncThemeToXdyou()
  │     ├─ setLocale()     → callSyncLocaleToXdyou()
  │     └─ syncAllToXdyou() (登录时一键同步)
  │            │
  │            ▼
  │     xdyou_sync_bridge.dart         # 函数指针桥接层（打破循环 import）
  │            │
  │            ▼
  ├─ xdyou_bootstrap.dart              # 真机：注册 sync 函数 + 初始化 XDYou
  │     └─ buildXdyouApp() → MyApp(isFirst: ...)
  │
  └─ packages/traintime_pda/            # XDYou 子 App（嵌入式页面）
        └─ ThemeController.updateTheme()
              ├─ 优先读取 treehole_brightness / treehole_color_seed / treehole_localization
              └─ fallback 到 XDYou 原生偏好
```

XDYou 子模块共享树洞的 SharedPreferences 命名空间，共享 `pubspec.yaml` 的 `flutter_i18n` 配置，主题颜色（`pdaTealLight` / `pdaTealDark`）与树洞 `SharedColors` 品牌色对齐。

---

## 开发规范

### 后端

- API 路由通过 `server.py` 分发到 `handlers/` 中的独立模块
- 业务逻辑下沉到 `services/` 层
- 通用工具函数放在 `helpers/` 层
- 全局状态（线程锁、数据库连接池等）通过 `_globals.py` 统一管理
- 所有配置通过环境变量注入，不硬编码
- 生产环境必须设置 `BACKEND_ALLOW_DEBUG_VERIFY_CODE=false`

### 前端

- 页面使用 `Riverpod StateNotifier` 管理状态
- Repository 模式封装所有 HTTP 请求
- 公共接口路径统一放在 `lib/core/network/api_endpoints.dart`
- 页面初始化的异步加载放在 `initState + Future.microtask()`
- 发帖后立即展示，不等待审核

### 移动端

- 移动端新增页面应放在 `lib/mobile/features/` 对应子目录
- 使用 `mobile_providers.dart` 统一访问 Provider，避免直接从 `lib/` 深层 import
- XDYou 集成代码必须使用条件导入（`if (dart.library.io)`），禁止在 Web 端引入 `packages/traintime_pda`
- 主题变更通过 `AppSettingsStore` 触发自动同步，无需手动调用

---

## 相关文档

- [项目进程文档](PROJECT.md) — 版本历史、构建记录、未跨端适配功能
- [开发规范](CLAUDE.md) — 架构约定、命名规范、状态管理规范
- [代理说明](AGENTS.md) — 项目使命、技术栈、上下文锚点、未完成任务
