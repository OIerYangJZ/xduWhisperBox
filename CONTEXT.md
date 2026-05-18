# Project Context (XDUWhisperBox)

This file (`CONTEXT.md`) is the central handoff context for AI coding assistants working on this repository. Read it before making code changes.

## Project Mission

西电树洞是一个面向西电校内用户的匿名社区 Web 应用，当前形态是 `Flutter Web + Python 后端` 的可内测版本。仓库也包含正在开发中的微信小程序端，复用同一套后端 API。

当前阶段：

- 前台已具备登录/注册、发帖、评论、搜索、收藏、举报、私信、个人中心、头像上传、管理员后台等主流程
- 后端已从 JSON 迁移到 SQLite Repository/DAO + 事务
- 图片上传、图片审核、账号注销审核、管理员后台、真实邮箱验证码、私信持久化已完成
- 通知中心已在本地代码完成：评论/回复/点赞/收藏/举报结果/系统公告通知、未读数、已读逻辑
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
3. After notification center rollout, continue strengthening the admin console:
   - Batch review
   - Stronger filtering / sorting / search
   - Data export
4. Medium-term production work still needed:
   - Domain + HTTPS
   - ICP filing
   - Backup / rollback
   - Logging and alerting
5. **Mini Program Migration (Ongoing):**
   - Successfully initialized Native WeChat Mini Program structure (`miniprogram/`).
   - Implemented Profile Page & Email/StudentID Login (`pages/profile/index`, `pages/profile/auth/index`).
   - Implemented Campus Community Feed (`pages/campus/index`) and Post Detail + Comments (`pages/campus/post-detail/index`).
   - Implemented AI Assistant Chat UI (`pages/ai/index`, `pages/ai/chat/index`) with mock API waiting for backend RAG integration.
   - API wrappers created in `miniprogram/api/` and `utils/request.js`.
   - **Next:** Implement Create Post flow, handle local media uploads for avatars/posts, and complete News/College Tabs.

## Operational Safety

- Do not stage, commit, push, or deploy unless the user explicitly asks
- Before touching deployment or secret-adjacent files, inspect the current state carefully
- Do not log, print, or expose API keys, private keys, database credentials, tokens, or other secrets
- Preserve unrelated local changes; this workspace may be dirty

## How To Use This File

When starting a new AI-assisted session, ask the assistant to read `CONTEXT.md` first so it understands the current architecture, active changes, and project conventions.
