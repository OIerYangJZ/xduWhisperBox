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
5. **Mini Program Migration (Audited & Cleaned 2026-05-22):**
   - **已完成并确认：**
     - 完成小程序端的功能排查与清理审计，生成了详细审计报告 [miniprogram_audit_results.md](file:///Users/yangjinsey/.gemini/antigravity/brain/330c931c-7d93-4df0-bd79-de025d5e3bbd/miniprogram_audit_results.md)。
     - 彻底删除了小程序端的管理员后台模块及相关 API 文件（`miniprogram/pages/admin/` 与 `miniprogram/api/admin.js`）。
     - 删除了已整合进主页的冗余资讯与板块页面（`miniprogram/pages/campus/community/` 与 `miniprogram/pages/campus/news/`）并清理了 `app.json` 中的路由。
     - 接通并验证了孤立页面：学院详情页（`pages/campus/college/index`）与 AI 对话历史页（`pages/ai/history/index`）。
     - 登录/注册/邮箱验证/重置密码已实现。
     - 首页对齐已完成：支持频道选择、排序切换、未读通知徽标、发布状态及按钮联动。
     - 帖子详情已支持 Markdown 渲染、画廊、评论排序、表情、复制、深链定位。
     - 搜索已支持帖子搜索和用户搜索。
     - 举报处理结果详情页（`pages/profile/report-detail/index`）已补齐。
     - 他人公开主页已支持拉取并展示“TA 的发布”帖子列表。
     - 设置页已完成拆分重构：拆分为资料编辑、隐私与通知、账号安全、显示设置（多语言及主题）、关于、意见反馈等独立子页面。
     - 个人中心已支持自定义背景图展示，修复了资料更新/背景更换时接口字段置空的 Bug。
     - 支持多语言切换（简/繁/英）与深浅色（主题）模式，并适配微信深色模式。
     - 移除了小程序端发帖的 Markdown 开关（默认为 Plain 文本发帖，Markdown 发帖只允许在 Web 端存在，小程序和 App 仅支持展示他人帖子 Markdown 渲染）。
     - 私信会话列表及对话功能已完善，支持对话回复、撤回、转发，并针对无历史消息的新聊天对话页新增了“只能发1条消息（对方回复或关注后解锁）”的警示横幅。
   - **小程序端功能与体验差距清单：**
     - **微信生态对齐**：缺少微信原生一键登录（`wx.login` / 获取 OpenID）及微信账号绑定机制，用户需使用学号+密码手动登录。
     - **Markdown 渲染能力受限**：简易 Markdown 解析器仅支持 `#` 标题、引用、粗体和列表，缺少对行内代码、代码块、链接、斜体等排版格式的渲染，排版稍显单薄。
     - **私信体验差距**：会话列表中不支持像 Flutter 移动端那样的左滑侧滑删除，目前仅支持弹出 Modal 二次确认框删除。

## Operational Safety

- Do not stage, commit, push, or deploy unless the user explicitly asks
- Before touching deployment or secret-adjacent files, inspect the current state carefully
- Do not log, print, or expose API keys, private keys, database credentials, tokens, or other secrets
- Preserve unrelated local changes; this workspace may be dirty

## How To Use This File

When starting a new AI-assisted session, ask the assistant to read `CONTEXT.md` first so it understands the current architecture, active changes, and project conventions.
