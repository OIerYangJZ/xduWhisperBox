# Project Context (XDUWhisperBox)

This file (`CONTEXT.md`) is the central handoff context for AI coding assistants working on this repository. Read it before making code changes.

## Project Mission

西电树洞是一个面向西电校内用户的匿名社区 Web 应用，当前形态是 `Flutter Web + Python 后端` 的可内测版本。仓库也包含正在开发中的微信小程序端，复用同一套后端 API。

当前阶段：

- 前台已具备登录/注册、发帖、评论、搜索、收藏、举报、私信、个人中心、头像上传、管理员后台等主流程
- 后端已从 JSON 迁移到 SQLite Repository/DAO + 事务
- 图片上传、图片审核、账号注销审核、管理员后台、真实邮箱验证码、私信持久化已完成
- 通知中心已在本地代码完成：评论/回复/点赞/收藏/举报结果/系统公告通知、未读数、已读逻辑
- AI 助手后端 RAG 接口已完成（关键词检索模式），并与小程序端完成联调
- 管理员后台已强化：支持审核/举报关键字搜索、批量审核操作、全量数据导出（用户/帖子/评论/举报/申诉/日志等）
- 设置页面已重构：拆分为账号安全、隐私、通知、界面外观、关于等子页面，并采用列表式菜单布局
- 移动端管理员功能已补齐：实现了内容审核、举报管理、图片审核的移动端子页面及概览数据实时对接
- 后端服务已启动并运行在 127.0.0.1:8080，修复了 AI 接口的参数调用 bug
- 通知中心这批改动当前仍是本地工作区变更，尚未部署到现网、尚未推送到 Git

## Repository Layout

```text
XDUWhisperBox/
├── backend/            # Python backend, SQLite repository, upload storage helpers
├── flutter_app/        # Flutter client for Web / mobile targets
├── miniprogram/        # Native WeChat Mini Program client
├── docs/               # Project docs and specifications
├── scripts/            # Local build/deploy/ops scripts
├── deploy/             # Deployment configs, including Tencent Cloud assets
├── CONTEXT.md          # Global AI assistant handoff context
└── AGENTS.md           # Codex-specific project instructions
```

Do not place Flutter-specific files such as `pubspec.yaml` at the repository root. Flutter commands should run from `flutter_app/`.

## Tech Stack

### Frontend

- Flutter Web
- Dart SDK: `>=3.3.0 <4.0.0`
- `flutter_riverpod: ^2.6.1`
- `http: ^1.2.2`
- `shared_preferences: ^2.3.2`
- `cupertino_icons: ^1.0.8`
- `flutter_lints: ^4.0.0`

### Backend

- Python 3
- Standard-library HTTP service: `http.server + ThreadingHTTPServer`
- SQLite persistence through `backend/sql_repository.py`
- Local object storage defaults to `backend/storage/objects`
- Optional S3-compatible object storage: `boto3 >=1.34,<2.0`

### Deployment

- Local development: Flutter Web + `python3 backend/server.py`
- Current internal-test server: Tencent Cloud Ubuntu 22.04
- Nginx + systemd deployment scripts live under `scripts/` and `deploy/tencent/`
- Production Web builds should use same-origin API by default: `--dart-define=API_BASE_URL=/api`

## Context Anchors

1. `backend/server.py`
   - Core backend entry point
   - HTTP APIs, authentication, business logic, and static Web hosting live here

2. `backend/sql_repository.py`
   - SQLite schema, initialization, JSON import, transactions, and persistence logic
   - Check this first for schema or data-persistence changes

3. `flutter_app/lib/widgets/home_shell.dart`
   - Main shell after user login
   - Bottom navigation, message badges, notification entry, and page switching start here

4. `flutter_app/lib/features/admin/admin_console_page.dart`
   - Main admin console
   - Content review, report handling, image review, account-deletion review, system config, and announcements live here

5. `flutter_app/lib/repositories/app_repositories.dart`
   - Frontend repository assembly point
   - API client, user-facing repositories, and admin repositories are wired here

6. `flutter_app/lib/core/network/api_endpoints.dart`
   - Shared frontend API path definitions

7. `miniprogram/`
   - Native WeChat Mini Program implementation
   - API wrappers should stay under `miniprogram/api/`, common request/auth helpers under `miniprogram/utils/`

## Architecture Conventions

- Frontend code should go through the `Repository` layer; do not build ad hoc HTTP calls directly in pages
- Core page state should prefer Riverpod `StateNotifier`
- Shared API paths belong in `flutter_app/lib/core/network/api_endpoints.dart`
- Shared loading/error UI should reuse existing `AsyncPageState` patterns where available
- Backend should continue the single-file `server.py` style for HTTP handlers and helpers; do not introduce a new web framework without explicit direction
- Add backend serialization helpers using the existing `serialize_*` naming style
- Add backend creation/publishing helpers using the existing `create_*` / `publish_*` naming style

## Async and State Rules

- Page initialization async loading should use `initState + Future.microtask(...)` or a controller `loadInitial()` pattern
- User-triggered async operations need explicit busy state to prevent duplicate clicks
- Prefer optimistic frontend state updates for interactive changes, then refresh or roll back on failure

## Product and Logic Rules

- Posts should appear immediately after publishing; do not add a frontend flow where posts wait for review before becoming visible
- Anonymous posting is allowed, but the admin console must still expose the real account to admins
- Normal user login and admin login are separate entry points with separate tokens
- Do not edit generated `build/web/*` output by hand
- Do not treat runtime data as source code:
  - `backend/data/treehole.db`
  - `backend/storage/objects`

## UI and Copy Rules

- Keep the current light theme and visual direction unless the task explicitly calls for redesign
- UI copy should stay Chinese, concise, and direct
- This project does not use a Flutter routing framework; continue using `Navigator` / `MaterialPageRoute`

## Current Unfinished Tasks

1. Deploy the current notification-center changes to the Tencent Cloud production/internal-test environment
2. Push the current notification-center changes to GitHub
3. **Mobile Admin (Next):** Implement the remaining placeholder functions (User Management, User Level upgrade review, System Config).
4. Medium-term production work still needed:
   - Domain + HTTPS
   - ICP filing
   - Backup / rollback
   - Logging and alerting
5. **Mini Program Migration (Ongoing, audited 2026-05-20):**
   - 已完成并确认：
     - 原生微信小程序结构已初始化：`miniprogram/`。
     - 登录/注册/邮箱验证已接后端：`pages/profile/auth/index`、`pages/profile/register/index`。
     - 本地真机调试配置已存在：`miniprogram/config/env.js` 支持 `auto` / `devtools` / `lan` / `prod`。
     - 小程序请求已统一走 `miniprogram/utils/request.js`，除公开认证接口外默认要求 token。
     - 树洞列表、搜索、发布、详情、评论、点赞、收藏、头像上传、通知中心、通知偏好、AI 问答已接入现有后端 API。
   - **仍未完成 / 需优先补齐：**
     - **个人活动页缺失：** `我的发布`、`我的评论`、`我的举报` 还没有页面、入口和 API 封装。后端已有 `/api/posts/mine`、`/api/comments/mine`、`/api/reports/mine`，可直接补小程序端。
     - **合规说明页缺失：** `用户协议`、`隐私政策`、`社区规范/举报说明`、`致谢页` 尚无小程序页面，也未注册到 `miniprogram/app.json`。
     - **设置页仍不完整：** 当前只支持头像、账号信息展示、通知偏好和退出登录；尚未接个人资料编辑、隐私开关（`allowStrangerDm` / `showContactable`）、账号注销申请、一级用户升级申请。后端已有 `PATCH /api/users/me`、`PATCH /api/users/privacy`、`POST /api/users/me/cancellation-request`、`POST /api/users/me/level-upgrade-request`。
     - **私信与社交链路缺失：** 小程序没有会话列表、聊天页、直接私信、屏蔽/解除屏蔽、关注/粉丝/好友、他人公开主页。后端已有 `/api/messages/conversations*`、`/api/users/{id}/follow`、`/api/users/me/following|followers|friends` 等接口。
     - **帖子详情交互不完整：** 当前详情页只提供点赞和一级评论发布；缺收藏/取消收藏、举报、分享、删除/编辑自己帖子、阅读量上报、评论点赞/回复/删除/举报、嵌套回复展示、点击非匿名作者进入公开主页、私信作者。
     - **列表分页还未真正实现：** `pages/campus/index.wxml` 绑定了 `onReachBottom`，但 `pages/campus/index.js` 未实现该 handler，也未递增 `page`；后端 `/api/posts` 当前忽略 `page/limit`，所以小程序 feed/search/favorites/notifications 还没有可靠的无限滚动分页。
     - **校园/资讯模块仍偏占位：** `miniprogram/api/campus.js#getColleges()` 仍是本地 Mock；`pages/campus/index.js#goToNewsDetail()` 仅弹窗展示公告，尚无新闻/公告详情页。
     - **意见反馈未入库：** `pages/profile/feedback/index.js` 只写入本地 `feedbackDrafts`，没有提交后端或管理员后台可处理的反馈记录。
     - **AI 助手仍是轻量版：** 小程序聊天已接 `/api/ai/chat`，但历史只存在本地 `aiHistory`；后端 `_ai_handler.py` 仍是关键词知识库/随机兜底，不是持久化会话、流式回复或真正私有知识库 RAG。
     - **发布前置条件：** `prod` 已指向 `https://www.seediantreehole.cn`，但小程序预览/提审前仍需确认 HTTPS、备案、微信后台 request 合法域名和线上后端部署状态。
   - **Next:** 先补 `我的发布/我的评论/我的举报` 与设置页隐私/注销/升级入口；随后补私信社交链路和帖子详情完整操作。

## Operational Safety

- Do not stage, commit, push, or deploy unless the user explicitly asks
- Before touching deployment or secret-adjacent files, inspect the current state carefully
- Do not log, print, or expose API keys, private keys, database credentials, tokens, or other secrets
- Preserve unrelated local changes; this workspace may be dirty

## How To Use This File

When starting a new AI-assisted session, ask the assistant to read `CONTEXT.md` first so it understands the current architecture, active changes, and project conventions.
