# AGENTS.md

## Project Mission

西电树洞是一个面向西电校内用户的匿名社区 Web 应用，当前形态是 `Flutter Web + Python 后端` 的可内测版本。

当前阶段：

- 前台已具备登录/注册、发帖、评论、搜索、收藏、举报、私信、个人中心、头像上传、管理员后台等主流程
- 后端已从 JSON 迁移到 SQLite Repository/DAO + 事务
- 图片上传、图片审核、账号注销审核、管理员后台、真实邮箱验证码、私信持久化已完成
- 通知中心已在本地代码完成：评论/回复/点赞/收藏/举报结果/系统公告通知、未读数、已读逻辑
- 通知中心这批改动当前仍是本地工作区变更，尚未部署到现网、尚未推送到 Git

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
- 标准库 HTTP 服务：`http.server + ThreadingHTTPServer`
- SQLite：通过 `backend/sql_repository.py` 管理 schema / 事务 / JSON 迁移
- 本地对象存储：默认 `backend/storage/objects`
- 可选 S3 兼容对象存储：`boto3 >=1.34,<2.0`

### Deployment

- 本地开发：Flutter Web + `python3 backend/server.py`
- 当前内测服务器：腾讯云 Ubuntu 22.04
- Nginx + systemd 部署脚本已在 `scripts/` 和 `deploy/tencent/`

## Context Anchors

1. `backend/server.py`
   - 核心后端入口
   - 所有 HTTP API、鉴权、业务逻辑、静态 Web 托管都在这里

2. `backend/sql_repository.py`
   - SQLite schema、初始化、JSON 导入、全量持久化逻辑
   - 涉及表结构或数据持久化时先看这里

3. `lib/widgets/home_shell.dart`
   - 用户登录后的主壳层
   - 底部导航、消息红点、通知入口、主页面切换都从这里进

4. `lib/features/admin/admin_console_page.dart`
   - 管理员后台主界面
   - 内容审核、举报处理、图片审核、注销审核、系统配置、系统公告都在这里

5. `lib/repositories/app_repositories.dart`
   - 前端 Repository 总装配点
   - API Client、普通用户接口、管理员接口都从这里接入

## Conventions

### Architecture

- 前端优先走 `Repository` 分层，不要在页面里直接拼 HTTP 请求
- 核心页面状态优先用 `Riverpod StateNotifier` 管理
- 公共接口路径统一放在 `lib/core/network/api_endpoints.dart`
- 公共加载/错误态优先复用 `AsyncPageState`
- 后端继续沿用单体 `server.py` 风格；新增 API 直接扩展现有 handler 和 helper，不引入新框架

### Async / State

- 页面初始化的异步加载，优先放在 `initState + Future.microtask(...)` 或 controller 的 `loadInitial()`
- 交互型异步操作要有显式 busy 状态，避免重复点击
- 前端状态更新倾向“先乐观更新，失败再 refresh 回滚”

### Naming

- 页面文件：`*_page.dart`
- 仓库层：`*_repository.dart`
- 状态控制器：`*_controller.dart`
- 数据模型：`*_item.dart` / `*_models.dart`
- 后端新增序列化函数命名保持：`serialize_*`
- 后端新增创建函数命名保持：`create_*` / `publish_*`

### Product / Logic Rules

- 发帖后应立即展示，不走“发布后等待审核再可见”的前台逻辑
- 允许匿名发帖，但管理员后台必须能看到真实账号
- 普通用户登录和管理员登录是两套独立入口、独立 token
- 生产 Web 构建默认使用同源 API：`--dart-define=API_BASE_URL=/api`
- 不要手改 `build/web/*`；这些是构建产物
- 不要把运行时数据文件当源码改：
  - `backend/data/treehole.db`
  - `backend/storage/objects`

### UI / Copy

- 保持当前浅色主题和现有视觉方向，不要无理由大改风格
- 页面文案保持中文、简洁、直接
- 当前项目不使用路由框架；页面跳转继续使用 `Navigator` / `MaterialPageRoute`

## Unfinished Tasks

1. 将当前“通知中心”改动部署到腾讯云现网
2. 将当前“通知中心”改动推送到 GitHub
3. 通知中心上线后，下一优先级是继续增强管理员后台
   - 批量审核
   - 更强的筛选 / 排序 / 搜索
   - 数据导出
4. 中期仍需补生产化能力
   - 域名 + HTTPS
   - 备案
   - 备份 / 回滚
   - 日志与告警
