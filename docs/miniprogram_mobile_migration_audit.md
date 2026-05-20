# 移动端主 App 到微信小程序迁移完整性审计报告

审计日期：2026-05-20  
审计目标：排查 Flutter 移动端主 App 的前端页面、功能、交互特性是否已完整迁移到微信小程序，并给出可执行的补齐清单。

## 1. 审计范围

本次审计覆盖以下前端代码：

| 范围 | 代码位置 | 说明 |
| --- | --- | --- |
| Flutter 移动端主 App | `flutter_app/lib/mobile/**` | 主 App 路由、页面、移动端交互和状态逻辑 |
| Flutter 共享业务仓库 | `flutter_app/lib/repositories/**`、`flutter_app/lib/models/**` | 主 App 已暴露和使用的业务能力 |
| 微信小程序 | `miniprogram/**` | 小程序页面、API 封装、交互实现 |

后端接口只作为功能可用性依据检查，本报告重点是前端迁移完整性。

## 2. 总体结论

小程序当前已经迁移了社区信息流、帖子详情、发帖、登录注册、我的页面、收藏、我的发布/评论/举报、私信会话、关系列表、通知、设置、反馈和基础法律说明等核心路径。

但若目标是“完全复刻移动端主 App 的全部功能和特性以及页面”，当前小程序仍未达到完整迁移。主要缺口集中在：

1. 移动端管理后台整组页面缺失。
2. 发帖高级能力缺失，包括私密可见性、置顶申请、Markdown 内容、发帖状态选择、评论/私信开关等。
3. 帖子详情高级交互缺失，包括评论排序、表情输入、Markdown 渲染、图片画廊、关注作者、带描述举报、评论复制、评论深链定位。
4. 私信功能只覆盖基础收发，缺少回复、撤回、选择/批量操作、发送失败重试、消息详情、转发、私信请求处理等。
5. 搜索只覆盖帖子，缺少用户搜索和用户结果跳转。
6. 设置体系被压缩为一个页面，缺少独立资料编辑页、背景图上传、显示/深色模式、关于/版本更新、致谢细节、重置密码入口。
7. 身份认证缺少重置密码页。
8. 小程序新增了校园新闻/学院/AI 助手等能力，这些属于小程序扩展功能，主 App 迁移对齐时需要单独定边界。

## 3. 路由与页面覆盖矩阵

| 主 App 路由/页面 | 主 App 能力 | 小程序对应页面 | 覆盖状态 | 主要差距 |
| --- | --- | --- | --- | --- |
| `/auth/login` | 登录 | `pages/profile/auth/index` | 已覆盖 | 登录入口在“我的”下，页面形态不同 |
| `/auth/register` | 注册 | `pages/profile/register/index` | 已覆盖 | 基础注册/验证已迁移 |
| `/auth/verify` | 邮箱验证 | `pages/profile/register/index` | 部分覆盖 | 与注册页合并，缺少独立验证路由形态 |
| `/auth/reset-password` | 重置密码 | 无 | 缺失 | 小程序没有找回/重置密码页面和入口 |
| `/` | 社区首页信息流 | `pages/campus/index` | 部分覆盖 | 小程序首页混合“社区/新闻/学院”，社区页缺少主 App 顶部频道图标选择、排序切换、通知徽标、滚动隐藏发布按钮等交互细节 |
| `/messages` | 会话列表 | `pages/profile/conversations/index` | 部分覆盖 | 基础会话列表和删除已迁移，缺少主 App 消息页的完整状态联动 |
| `/profile` | 我的主页 | `pages/profile/index` | 部分覆盖 | 小程序有入口聚合，个人头图、资料卡表现、设置分组和主 App 有差异 |
| `/search` | 搜索帖子和用户 | `pages/campus/search/index` | 部分覆盖 | 小程序仅搜索帖子，缺少用户搜索 Tab 和用户结果跳转 |
| `/favorites` | 收藏帖子 | `pages/profile/favorites/index` | 基本覆盖 | 需继续核对空态、加载态和帖子卡片字段一致性 |
| `/post/create` | 创建帖子 | `pages/campus/create-post/index` | 部分覆盖 | 缺少私密、置顶、Markdown、状态选择、评论/私信开关、标签选择器等 |
| `/post/:id` | 帖子详情 | `pages/campus/post-detail/index` | 部分覆盖 | 缺少评论排序、表情、Markdown、图片画廊、关注作者、带描述举报、评论复制、评论定位 |
| `/chat/:conversationId` | 私信聊天 | `pages/profile/chat/index` | 部分覆盖 | 缺少回复、撤回、重试、详情、选择、批量、转发等 |
| `/user/:id`、`/users/:userId` | 公开主页 | `pages/profile/public-user/index` | 部分覆盖 | 已支持关注/私信，缺少用户帖子列表和更完整的主页信息呈现 |
| `/notifications` | 通知中心 | `pages/profile/notifications/index` | 部分覆盖 | 已支持列表、全部已读、单条已读和跳帖，缺少评论锚点和更细路由 |
| `/profile/edit` | 编辑资料 | `pages/profile/settings/index` | 部分覆盖 | 小程序合并到设置页，缺少背景图上传和独立编辑体验 |
| `/profile/settings` | 设置主页 | `pages/profile/settings/index` | 部分覆盖 | 主 App 分层设置，小程序单页聚合 |
| `/profile/settings/privacy` | 隐私设置 | `pages/profile/settings/index` | 基本覆盖 | 主要开关已迁移，页面层级不同 |
| `/profile/settings/account` | 账号安全 | `pages/profile/settings/index` | 部分覆盖 | 缺少重置密码入口；注销和升级申请已迁移 |
| `/profile/settings/display` | 显示设置 | 无 | 缺失 | 缺少主题/深色模式设置 |
| `/profile/settings/about` | 关于与更新 | `pages/profile/legal/index?type=about` 近似 | 部分覆盖 | 缺少版本号、检查更新、更新弹窗、关于页完整信息 |
| `/profile/settings/notifications` | 通知偏好 | `pages/profile/settings/index` | 基本覆盖 | 六类通知开关已迁移，页面层级不同 |
| `/profile/posts` | 我的发布 | `pages/profile/my-posts/index` | 基本覆盖 | 已支持列表、状态更新、删除 |
| `/profile/comments` | 我的评论 | `pages/profile/my-comments/index` | 部分覆盖 | 可跳帖子和删除，缺少评论定位到具体楼层 |
| `/profile/reports` | 我的举报 | `pages/profile/my-reports/index` | 部分覆盖 | 列表已迁移，缺少举报详情页 |
| `/profile/help-feedback` | 帮助与反馈 | `pages/profile/feedback/index` | 部分覆盖 | 小程序只保留反馈提交，缺少帮助入口、举报说明和我的举报联动 |
| `/profile/acknowledgements` | 致谢页 | `pages/profile/legal/index?type=acknowledgements` | 部分覆盖 | 内容已简化，缺少主 App 细节呈现 |
| `/legal/terms` | 用户协议 | `pages/profile/legal/index?type=user-agreement` | 基本覆盖 | 内容为小程序内置简版 |
| `/legal/privacy` | 隐私政策 | `pages/profile/legal/index?type=privacy-policy` | 基本覆盖 | 内容为小程序内置简版 |
| `/legal/guidelines` | 社区规范 | `pages/profile/legal/index?type=community-guidelines` | 基本覆盖 | 与举报说明合并 |
| `/legal/report` | 举报说明 | `pages/profile/legal/index?type=community-guidelines` | 部分覆盖 | 缺少独立举报说明页面 |
| `/admin/login` | 管理员登录 | 无 | 缺失 | 小程序未提供管理员入口 |
| `/admin` | 管理控制台 | 无 | 缺失 | 概览卡片、待办入口缺失 |
| `/admin/reviews` | 帖子审核 | 无 | 缺失 | 审核列表和通过/驳回操作缺失 |
| `/admin/reports` | 举报处理 | 无 | 缺失 | 举报处理和标记误报等操作缺失 |
| `/admin/images` | 图片审核 | 无 | 缺失 | 图片审核列表和审核操作缺失 |

## 4. 功能模块详细审计

### 4.1 认证与账号入口

主 App：登录、注册、邮箱验证、重置密码，并在账号安全页提供重置密码入口。  
小程序：登录、注册、邮箱验证已落在 `pages/profile/auth/index` 和 `pages/profile/register/index`。

缺口：

- 缺少 `reset-password` 页面、API 封装和入口。
- 登录后遇到未验证邮箱时可跳注册验证页，但没有独立验证页状态机。
- 设置页账号安全中没有“修改/重置密码”入口。

迁移建议：

- 新增 `pages/profile/reset-password/index`。
- 在登录页、设置页账号安全分组增加入口。
- 对齐主 App 的 `/auth/password/reset` 请求参数和错误提示。

### 4.2 首页、频道与信息流

主 App 首页特性：

- 顶部频道图标选择。
- 最新/热度排序切换。
- 通知入口和未读徽标。
- 下拉刷新、触底加载。
- 滚动时底部导航和发帖按钮联动隐藏。
- 帖子置顶排序在前端有二次排序逻辑。

小程序现状：

- `pages/campus/index` 有社区、新闻、学院三个 Tab。
- 社区列表支持分页、下拉刷新和进入详情。
- 搜索和发布入口需要从页面 WXML 继续确认 UI 是否显式存在，JS 侧主逻辑以列表为主。

缺口：

- 社区首页未暴露频道筛选、排序切换和通知徽标。
- 置顶帖子、状态、图片、匿名、互动计数字段虽有格式化工具支持，首页列表是否完整呈现需要继续逐项验收。
- 主 App 的社区首页是纯社区体验，小程序首页混入校园新闻/学院信息，信息架构已经发生变化。

迁移建议：

- 在 `pages/campus/index` 增加频道选择、排序切换、通知入口和发布按钮状态联动。
- 复用 `miniprogram/api/posts.js` 的 `getPosts`，补齐 `channel`、`sort`、`hasImage`、`allowDm`、`status` 参数。
- 首页帖子卡片字段与 Flutter `PostCard` 做逐字段对齐。

### 4.3 搜索

主 App：

- 支持帖子搜索。
- 支持用户搜索，用户结果可进入公开主页。
- 有帖子/用户结果区域。

小程序：

- `pages/campus/search/index` 支持关键词、频道、排序、历史记录。
- 搜索结果只调用 `/api/posts`。

缺口：

- 缺少用户搜索。
- 缺少帖子/用户切换。
- 缺少用户结果的关注状态、头像、简介、进入主页入口。

迁移建议：

- 在 `miniprogram/api/user.js` 增加 `searchUsers(keyword)`。
- `pages/campus/search/index` 增加帖子/用户分段控件。
- 用户结果跳转 `pages/profile/public-user/index?id=...`。

### 4.4 发帖

主 App 发帖能力：

- 标题、正文、频道。
- 多图选择和上传。
- 标签选择器和标签 Chips。
- 匿名发布和匿名名生成。
- 帖子状态选择。
- 私密发布。
- 一级用户置顶申请。
- `allowComment`、`allowDm`。
- `contentFormat` 和 `markdownSource` 字段。

小程序现状：

- `pages/campus/create-post/index` 支持标题、正文、频道、标签文本、多图上传、匿名发布、匿名名。
- 提交时固定 `status: 'ongoing'`、`visibility: 'public'`。

缺口：

- 缺少私密发布开关。
- 缺少置顶申请入口和时长选择。
- 缺少发帖状态选择。
- 缺少评论开关和私信开关。
- 缺少 Markdown 模式和 `markdownSource`。
- 标签是文本输入，未迁移主 App 的标签选择器体验。
- 匿名名没有主 App 的随机生成交互。

迁移建议：

- 扩展 `createPost` payload：`allowComment`、`allowDm`、`visibility`、`status`、`contentFormat`、`markdownSource`、`pinDurationMinutes`。
- 增加一级用户判断和置顶申请 UI。
- 把标签输入升级为预设标签选择 + 自定义标签。

### 4.5 帖子详情与评论

主 App 帖子详情能力：

- Markdown 内容渲染。
- 图片网格和图片画廊。
- 点赞、收藏、举报、删除。
- 关注作者。
- 私信作者。
- 评论热度/时间排序。
- 评论回复树。
- 表情输入。
- 评论点赞、删除、复制。
- 初始评论 ID 深链定位。
- 举报支持原因和描述。

小程序现状：

- `pages/campus/post-detail/index` 支持帖子详情、点赞、收藏、分享、举报、删除、评论、回复、评论点赞、评论举报、评论删除、作者主页、私信作者。
- 图片以 `mode="widthFix"` 直接展示。
- 举报为 ActionSheet 选择原因，`description` 固定为空字符串。

缺口：

- 缺少 Markdown 渲染。
- 缺少图片预览/画廊交互。
- 缺少评论排序。
- 缺少表情输入面板。
- 缺少关注作者按钮。
- 缺少举报描述输入。
- 缺少评论复制。
- 缺少评论深链定位。
- 评论回复参数名需要与后端确认：小程序提交 `replyToId`，Flutter 仓库提交 `parentId`。

迁移建议：

- 增加 `commentSort` 状态并调用 `getPostComments(postId, { sort })`。
- 评论输入栏增加表情面板。
- 图片增加 `wx.previewImage`。
- 举报改为“原因 + 描述”弹层。
- 引入 Markdown 解析展示方案，覆盖纯文本和 Markdown 两种格式。

### 4.6 我的页面、资料和设置

主 App：

- 我的主页包含背景图、头像、昵称、统计和功能入口。
- 独立资料编辑页支持头像和背景图上传。
- 独立隐私设置、通知设置、账号安全、显示设置、关于、致谢。
- 显示设置支持系统/浅色/深色主题。
- 关于页支持版本号和 Android 更新检查。

小程序：

- `pages/profile/index` 是入口聚合页。
- `pages/profile/settings/index` 合并资料、头像、隐私、通知、账号安全、注销、等级升级、退出登录。

缺口：

- 缺少背景图上传。
- 缺少独立资料编辑页。
- 缺少显示设置/深色模式。
- 缺少关于页版本信息和更新检查。
- 缺少重置密码入口。
- 致谢页内容简化。

说明：

- Android 更新检查属于 App 分发能力，小程序没有相同机制。若产品要求“体验复刻”，可在小程序关于页展示版本信息、基础更新说明和小程序版本来源；不建议照搬 Android APK 更新逻辑。

### 4.7 我的发布、评论、举报、收藏

小程序已迁移：

- 收藏：`pages/profile/favorites/index`。
- 我的发布：`pages/profile/my-posts/index`，支持状态更新和删除。
- 我的评论：`pages/profile/my-comments/index`，支持跳帖子和删除。
- 我的举报：`pages/profile/my-reports/index`，支持列表和跳转帖子目标。

缺口：

- 我的评论跳转无法定位到具体评论。
- 我的举报缺少详情页。
- 举报记录内容字段、处理结果、处理时间的展示需要与 Flutter `ReportItem` 逐项对齐。
- 收藏列表和帖子卡片字段需要继续做视觉/字段验收。

迁移建议：

- 帖子详情支持 `commentId` 参数后，我的评论和通知可跳到具体评论。
- 新增 `pages/profile/report-detail/index` 或在列表项展开详情。

### 4.8 公开主页与社交关系

主 App：

- 公开主页支持用户信息、关注/取消关注、发起私信。
- 仓库支持关注、粉丝、好友、用户搜索、用户帖子列表。

小程序：

- `pages/profile/public-user/index` 支持公开资料、关注/取消关注、私信。
- `pages/profile/social-list/index` 支持关注、粉丝、好友列表和发私信。

缺口：

- 公开主页缺少用户帖子列表。
- 用户搜索缺失，导致公开主页发现路径少一条。
- 公开主页视觉和字段密度需要对齐主 App，例如背景图、统计、简介、关系状态。

迁移建议：

- 在公开主页接入 `/api/posts?authorId=...`。
- 用户搜索完成后统一跳转公开主页。
- 对齐头像、背景图、简介、关注状态、私信权限等字段。

### 4.9 私信和会话

主 App 聊天能力：

- 会话列表删除。
- 聊天消息收发。
- 回复消息。
- 本地乐观发送。
- 发送失败重试。
- 长按操作层。
- 选择模式和批量撤回。
- 单条撤回。
- 消息详情。
- 转发选择器。
- 屏蔽/解除屏蔽。
- 删除会话。
- 进入对方主页。
- 私信请求创建、接受、拒绝。

小程序现状：

- `pages/profile/conversations/index` 支持会话列表、进入聊天、删除会话。
- `pages/profile/chat/index` 支持拉取消息、发送文本、屏蔽/解除屏蔽。

缺口：

- 缺少回复 UI 和 `replyToId`。
- 缺少撤回接口封装和操作。
- 缺少发送失败重试。
- 缺少本地乐观发送状态。
- 缺少长按操作、选择模式、批量操作。
- 缺少消息详情。
- 缺少转发。
- 缺少私信请求列表、接受、拒绝。
- 缺少聊天页进入对方主页。

迁移建议：

- 扩展 `miniprogram/api/messages.js`：`recallMessage`、`fetchDmRequests`、`handleDmRequest`、`createDmRequest`。
- 聊天页增加消息长按菜单：回复、复制、撤回、详情、转发。
- 会话页增加私信请求入口。

### 4.10 通知中心

主 App：

- 通知中心与首页徽标联动。
- 可标记已读。
- 通知跳转帖子/评论等目标。

小程序：

- `pages/profile/notifications/index` 支持列表、全部已读、单条已读、跳转帖子。

缺口：

- 缺少评论级定位。
- 首页社区 Tab 缺少通知徽标入口。
- 部分通知类型的目标路由需要补齐，例如关系、私信、举报结果详情。

迁移建议：

- 通知项解析 `commentId`、`relatedType`、`relatedId`，按类型跳转。
- 首页和我的页统一使用未读数状态。

### 4.11 管理后台

主 App 移动端包含完整管理端：

- 管理员登录。
- 管理控制台。
- 帖子审核。
- 举报处理。
- 图片审核。
- 待处理数量概览。

小程序：

- `app.json` 中没有任何 admin 页面。
- `miniprogram/api` 中未看到 admin API 封装。

缺口：

- 管理后台整组功能缺失。

迁移建议：

- 若小程序需要完全复刻主 App，应新增 `pages/admin/**` 页面组。
- 若产品上决定小程序不承载管理后台，需要在迁移目标中把“管理后台”标记为平台边界外功能，并另建管理端说明，避免“完全复刻”验收口径冲突。

### 4.12 小程序额外能力

小程序额外包含：

- 校园新闻/公告。
- 学院信息。
- AI 助手和本地历史。

这些能力在 Flutter 移动端路由表中没有对应主 App 页面。它们属于小程序增量功能，迁移审计时建议单独归档，避免和主 App 复刻清单混在一起。

## 5. API 复用和缺口矩阵

| 能力 | 主 App 使用情况 | 小程序现状 | 状态 |
| --- | --- | --- | --- |
| `/api/posts` 列表 | 支持频道、关键词、图片、私信、状态、排序 | 已封装，首页只用分页；搜索用关键词/频道/排序 | 部分复用 |
| `/api/posts/:id` 详情 | 已使用 | 已使用 | 已复用 |
| 创建帖子 | 主 App 传完整 `CreatePostInput` | 小程序只传基础字段，固定公开和进行中 | 部分复用 |
| 图片上传 | 主 App 支持发帖图和资料背景图 | 小程序支持发帖图和头像 | 部分复用 |
| 我的上传 | 主 App 有 `fetchMyUploads` | 小程序未封装 | 缺失 |
| 评论排序 | 主 App 传 `sort` | 小程序接口可传，但页面未暴露排序 | 部分复用 |
| 帖子置顶申请 | 主 App 有 `postPinRequest` | 小程序未封装 | 缺失 |
| 用户搜索 | 主 App 有 `searchUsers` | 小程序未封装 | 缺失 |
| 公开主页 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 关注/取消关注 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 背景图上传 | 主 App 已使用 | 小程序未实现 | 缺失 |
| 通知偏好 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 账号注销申请 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 等级升级申请 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 举报详情 | 主 App 有 `reportById` | 小程序未封装 | 缺失 |
| 会话列表/消息 | 主 App 已使用 | 小程序已使用 | 已复用 |
| 消息回复 | 主 App 发送支持 `replyToId` | 小程序未传 | 缺失 |
| 消息撤回 | 主 App 有 recall | 小程序未封装 | 缺失 |
| 私信请求 | 主 App 有请求列表/处理/创建 | 小程序未封装 | 缺失 |
| Android 更新 | 主 App 有 release 检查 | 小程序无对应 | 平台差异 |
| 管理后台接口 | 主 App admin 页面使用 | 小程序未封装 | 缺失 |

## 6. 优先级迁移清单

### P0：影响“完整复刻”验收的硬缺口

1. 补齐管理后台页面组，或产品上明确排除管理后台。
2. 补齐重置密码页面和入口。
3. 发帖补齐私密、置顶、状态、评论/私信开关、Markdown。
4. 帖子详情补齐评论排序、Markdown、图片预览、举报描述、关注作者、评论复制、评论深链。
5. 私信补齐回复、撤回、失败重试、消息操作菜单、私信请求。
6. 搜索补齐用户搜索。

验收标准：

- Flutter 路由表中的每个用户可见页面，在小程序中都有对应页面、明确替代页或书面排除说明。
- 主 App 仓库层已使用的前端能力，小程序页面侧有对应入口和交互。
- 页面操作可在微信开发者工具和真机上完成端到端验证。

### P1：体验一致性和信息架构差异

1. 首页频道、排序、通知徽标、发布入口行为对齐。
2. 我的主页背景图和资料展示对齐。
3. 设置页拆分为资料、隐私、通知、账号安全、显示、关于等页面，或在单页内给出等价信息架构。
4. 我的举报增加详情。
5. 公开主页增加用户帖子列表。
6. 通知跳转支持评论锚点和更多目标类型。

验收标准：

- 主要路径的操作步数、信息层级和反馈方式接近主 App。
- 相同业务字段在两端展示名称一致。

### P2：平台差异整理和增强能力归档

1. 小程序 AI、新闻、学院能力单独归档为增量功能。
2. Android 更新能力在小程序关于页用版本信息说明替代。
3. 法律、致谢、社区规范内容与主 App 同步。
4. 完成 UI 细节走查：加载态、空态、错误态、按钮禁用态、触控尺寸、长文本换行。

验收标准：

- 文档中明确哪些能力为小程序新增，哪些为平台替代。
- 视觉和交互差异可接受，并有产品确认。

## 7. 建议落地文件清单

| 任务 | 建议修改位置 |
| --- | --- |
| 重置密码 | `miniprogram/pages/profile/reset-password/**`、`miniprogram/api/auth.js`、`miniprogram/app.json` |
| 用户搜索 | `miniprogram/pages/campus/search/**`、`miniprogram/api/user.js` |
| 发帖高级字段 | `miniprogram/pages/campus/create-post/**`、`miniprogram/api/posts.js` |
| 帖子详情高级交互 | `miniprogram/pages/campus/post-detail/**` |
| Markdown 渲染 | `miniprogram/components/**` 或 `miniprogram/utils/**` |
| 图片画廊 | `miniprogram/pages/campus/post-detail/index.js`、`index.wxml` |
| 私信高级能力 | `miniprogram/pages/profile/chat/**`、`miniprogram/pages/profile/conversations/**`、`miniprogram/api/messages.js` |
| 私信请求 | `miniprogram/pages/profile/message-requests/**`、`miniprogram/api/messages.js` |
| 背景图上传 | `miniprogram/pages/profile/settings/**`、`miniprogram/api/uploads.js`、`miniprogram/api/user.js` |
| 显示设置 | `miniprogram/pages/profile/display-settings/**`、全局主题状态 |
| 关于/版本/致谢 | `miniprogram/pages/profile/about/**` 或扩展 `legal` 页面 |
| 举报详情 | `miniprogram/pages/profile/report-detail/**`、`miniprogram/api/user.js` |
| 管理后台 | `miniprogram/pages/admin/**`、`miniprogram/api/admin.js` |

## 8. 真机与开发者工具验收建议

建议按以下路径做真机测试：

1. 登录、注册、邮箱验证、重置密码。
2. 首页切频道、切排序、刷新、触底加载、进入通知、进入搜索、进入发帖。
3. 发帖：纯文本、Markdown、多图、匿名、非匿名、私密、置顶申请、不同状态、关闭私信、关闭评论。
4. 帖子详情：点赞、收藏、分享、举报带描述、关注作者、私信作者、图片预览、评论排序、评论回复、表情、复制、删除、从通知/我的评论定位评论。
5. 搜索：帖子搜索、用户搜索、搜索历史、结果跳转。
6. 我的：收藏、我的发布、我的评论、我的举报、关注/粉丝/好友、公开主页、私信。
7. 私信：会话删除、发送、回复、撤回、失败重试、屏蔽、解除屏蔽、消息详情、私信请求。
8. 设置：头像、背景图、资料、隐私、通知、账号安全、等级升级、注销、显示设置、退出登录。
9. 管理后台：管理员登录、审核帖子、处理举报、审核图片、查看待办数量。
10. 小程序独有能力：AI、新闻、学院信息，确认其与主 App 复刻目标的边界。

## 9. 风险点

1. 微信小程序对文件上传、图片预览、长按菜单、剪贴板、分享和隐私接口有平台限制，需要真机验证。
2. Markdown 渲染可能引入第三方组件，需要注意包体积和富文本安全。
3. 聊天高级能力涉及本地乐观状态、失败重试和撤回时序，需要和后端返回字段保持一致。
4. 管理后台放入小程序会涉及权限暴露和审核风险，应先确认产品和运营口径。
5. 小程序新增 AI/校园模块会改变信息架构，若目标是主 App 复刻，需要同时维护“复刻功能”和“增量功能”两份验收清单。

## 10. 审计结论

当前小程序具备社区主流程的基础可用性，但还没有完整复刻 Flutter 移动端主 App。若以“全部页面、全部功能、全部关键交互”作为验收口径，应至少完成 P0 清单后再进入体验对齐和真机验收阶段。

建议下一步先确认管理后台是否纳入小程序。如果纳入，迁移工作量会明显增加；如果排除，需要在产品文档和验收标准中明确写出平台边界。随后按 P0 顺序补齐认证、发帖、帖子详情、私信、搜索这五条用户主路径。

## 11. UI 一致性要求

如果目标升级为“功能完整 + UI 与主 App 完全一致”，验收标准需要再加一层：

1. 页面结构一致：导航层级、分组顺序、入口位置、信息密度与主 App 保持同构。
2. 视觉语言一致：颜色、字号、图标风格、圆角、间距、分割线、卡片层级、阴影策略保持统一。
3. 组件状态一致：加载、空态、错误态、禁用态、选中态、长按菜单、弹窗、底部操作栏的呈现一致。
4. 交互节奏一致：切换页面、刷新、提交、删除、撤回、关注、收藏、点赞的反馈时机一致。
5. 列表排布一致：帖子卡片、评论层级、个人页条目、设置项、会话项、通知项的字段顺序一致。
6. 内容展示一致：头像、背景图、昵称、匿名名、时间、标签、状态、计数器、图片缩略图的摆放一致。
7. 页面粒度一致：主 App 有独立页面的，小程序也要保留独立页面；合并页面只适合作为临时过渡，不适合作为最终验收口径。

对应的检查方式建议改成逐页核对：

- 以 Flutter 主 App 的每个路由为基准页。
- 记录小程序对应页的结构差异、组件差异和交互差异。
- 对所有高频页面输出截图对照表，再做真机抽检。
- 对所有差异项给出“已对齐 / 允许替代 / 需补齐”三类结论。

这意味着当前小程序不仅要补功能，还要对主页、帖子详情、发帖页、聊天页、设置页、公开主页、通知页做逐屏 UI 对齐。当前版本离这个目标还有明显差距，尤其是首页、帖子详情、发帖页和聊天页。
