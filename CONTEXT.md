# Project Context (XDUWhisperBox)

This file is the main handoff context for AI coding assistants working in this repository. Read it before making changes.

## Project Mission

西电树洞是一个面向西电校内用户的匿名社区 Web 应用，当前形态是 `Flutter Web + Python 后端` 的可内测版本，仓库也包含正在对齐主 App 的微信小程序端。

### Current state

- 前台主流程已具备登录/注册、发帖、评论、搜索、收藏、举报、私信、个人中心、头像上传、管理员后台等能力
- 后端已完成 JSON 到 SQLite Repository/DAO + 事务的迁移
- 图片上传、图片审核、账号注销审核、真实邮箱验证码、私信持久化都已完成
- 通知中心的评论/回复/点赞/收藏/举报结果/系统公告通知、未读数、已读逻辑已进入代码库
- AI 助手后端 RAG 接口已完成，并与小程序端联调
- 管理员后台已强化，包含审核/举报关键字搜索、批量审核、数据导出等能力
- 微信小程序最近几轮推送已重点对齐主 App 的 UI 与交互，包括首页顶部入口、帖子卡片、发帖页、帖子详情页、设置页和通知设置页

## Recent Pushes

最近几次推送主要覆盖这些内容：

1. 小程序首页顶部图标与布局收紧，贴近主 App
2. 小程序帖子卡片样式对齐主 App
3. 小程序顶部栏布局修正
4. 小程序发帖页重做为主 App 同款结构，包含默认项、匿名、置顶、可见性、图片预览和底部工具栏
5. 小程序帖子详情页重做为主 App 同款结构，修正时间显示、关注按钮位置、评论排序入口、回复条和按钮逻辑
6. 小程序设置相关页面继续复用主 App 的卡片与列表样式
7. 新增小程序通知设置页

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

6. `flutter_app/lib/mobile/features/post/create_post_page.dart`
   - Flutter mobile reference for the create-post flow

7. `flutter_app/lib/mobile/features/post/post_detail_page.dart`
   - Flutter mobile reference for post detail layout and interactions

8. `miniprogram/app.wxss`
   - Shared mini program visual tokens and reusable card/list styles

9. `miniprogram/pages/campus/create-post/index.*`
   - Mini program create-post page aligned to the mobile App

10. `miniprogram/pages/campus/post-detail/index.*`
    - Mini program post detail page aligned to the mobile App

11. `miniprogram/pages/profile/notification-settings/index.*`
    - Mini program notification settings page

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
- Mini program pages should keep visual parity with the mobile App where the task requires it

## Current Unfinished Tasks

1. Deploy the current notification-center changes to the Tencent Cloud environment if that deployment is still pending
2. Keep closing the remaining mobile-admin placeholders and parity gaps
3. Continue the mini program vs mobile App parity work for any remaining mismatches in layout, default values, and interaction logic
4. Medium-term production work still needed:
   - Domain + HTTPS
   - ICP filing
   - Backup / rollback
   - Logging and alerting

## Workspace Note

- The workspace may still contain unrelated local edits. Preserve them unless the task explicitly asks to change them.

