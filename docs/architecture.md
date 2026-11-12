# 架构说明

## 分层与依赖方向

```
┌───────────────────────────────────────────────┐
│ features/*            UI + 页面级状态          │
├───────────────────────────────────────────────┤
│ data/*                Drift / Dio / 仓储实现    │
│        ↓ 依赖                                    │
│ domain/*              实体 + 仓储接口           │
│        ↓ 依赖                                    │
│ rule_engine/*         规则模型 / 校验 / 求值     │
│        ↓ 依赖                                    │
│ core/*                纯值对象、异常、日志、工具  │
└───────────────────────────────────────────────┘
```

硬性规则：

1. 依赖只能自上而下，禁止反向 import。
2. `core` 与 `rule_engine` **不得** import `package:flutter/*`（`core/logging` 例外：它需要 `debugPrint`）。
3. `domain` 不得 import `data` 或 `features`；仓储接口在 `domain`，实现在 `data`。
4. `features` 之间不得互相 import 页面或状态；共享内容下沉到 `core` 或 `domain`。
5. `rule_engine` 是纯 Dart 模块，只依赖 `core`，保证可脱离 Flutter 单测、可被将来的规则 CLI 复用。

> 上述规则由 code review 保证。`analysis_options.yaml` 已开启 `strict-*` 与严格 lint，能自动挡住大部分越界写法。

## 目录职责

| 目录 | 职责 |
| --- | --- |
| `lib/app` | 组合根：主题、路由、根组件。只有这里知道所有页面的存在 |
| `lib/core/constants` | 全局常量（版本号、超时、文件名） |
| `lib/core/errors` | `sealed AppException` 家族，UI 据此分派错误文案 |
| `lib/core/logging` | 统一日志与敏感值脱敏 |
| `lib/core/models` | 跨层共享的纯值对象（如 `MediaType`） |
| `lib/core/utils` | JSON 读取、HTML 文本切段等无状态工具 |
| `lib/core/widgets` | 无业务语义的通用组件（空状态等） |
| `lib/data/db` | Drift 表定义、DAO、迁移 |
| `lib/data/builtin` | 内置规则集的校验与播种（`BuiltinRuleSeeder`） |
| `lib/data/network` | 规则 HTTP 客户端（Dio 实现）、登录凭据注入、WebView Cookie 读写 |
| `lib/data/sandbox` | `JsRuntime` 的 QuickJS 实现（`flutter_js`） |
| `lib/data/repositories` | 仓储实现：规则源、发现聚合、详情/章节编排 |
| `lib/data/providers.dart` | 数据层的 Riverpod 组合根 |
| `lib/domain/entities` | 领域实体（不可变），含详情页的 `WorkView` / `ViewerLaunch` |
| `lib/domain/repositories` | 仓储抽象接口 |
| `lib/rule_engine/models` | 规则包 schema 建模 + 序列化，以及详情 / 目录 / 正文产出模型 |
| `lib/rule_engine/pipeline` | 规则校验、模板渲染、字段求值、HTTP 抓取与四类能力流水线 |
| `lib/rule_engine/sandbox` | JS 运行时抽象与安全边界 |
| `lib/features/<feature>` | 页面与页面级 provider（feature 目录下直接放页面） |
| `lib/features/discover` | 发现页：聚合启用规则的搜索结果、类型/来源筛选、作品网格 |
| `lib/features/detail` | 作品详情：详情字段、分组目录、章节按需抓取并打开查看器 |
| `lib/features/viewer` | 视频 / 漫画 / 小说查看器：播放后端抽象、弹幕引擎、阅读设置 |
| `lib/features/sources` | 规则源列表、规则编辑器（可视化表单 / JSON 双模式、校验、保存）与规则登录页（WebView / 手动请求头） |
| `lib/l10n` | ARB 源文件（生成物在 `lib/l10n/generated`，不入库） |

## 数据流

```
规则文件(.acgn.json)
   │  RulePackValidator.validate(rawJson)   ← 不抛异常，收集全部问题
   ▼
RulePack.fromJson(rawJson)                   ← 结构解析，非法即抛
   ▼
RuleSourceRepository.save(RuleSource)        ← 原文 + 冗余列写入 Drift
   ▼
RuleAuthRepository.save(RuleAuth)            ← 登录凭据单独写入本地表，不进入规则 JSON
   ▼
[features/sources] 列表  →  [features/discover] 读取所有启用规则
   ▼
AuthenticatedRuleHttpClient                  ← 按 ruleId 注入本地 Cookie / 认证请求头
   ▼
RuleSearchPipeline.search(pack, keyword: '') ← 模板 → HTTP → JSON/HTML/XML 解析 → 字段求值
   ▼
DiscoverFeed（作品 + 失败规则）→ 作品网格 + 类型/来源筛选
   ▼
点击作品 → RuleWorkRepository.loadWork(item)
   ├─ RuleDetailPipeline.fetch(pack, id, url) → WorkDetail
   └─ RuleTocPipeline.fetch(pack, detail, searchResult) → TocResult
   ▼
点击章节 → RuleContentPipeline.fetch(pack, chapter) → RuleContent
   ▼
ViewerLaunch → 漫画 / 小说 / 视频查看器（文件模式复制下载地址）
```

规则原文是唯一事实来源；`name`/`baseUrl`/`version` 只是为列表查询冗余的列，写入时必须与 JSON 同步（见 `DriftRuleSourceRepository.save`）。

## 发现页

`features/discover` 通过 `DiscoverFeedRepository` 聚合所有启用规则：

1. 只处理 `pack.supports(RuleCapability.search)` 的规则，按 `priority` + 名称排序；
2. 每条规则以空关键词请求第一页（`query` 模式请求搜索接口；`index` 模式拉索引，空关键词时跳过 `filter`）；
3. 单条规则失败只记录 `AppLogger` 并计入 `DiscoverFeed.failures`，不影响其它规则；
4. 类型 / 来源筛选在已加载结果上本地完成，不重复请求；
5. 卡片点击进入 `/work` 详情页，搜索结果的全部字段通过 `DiscoverItem.extra` 透传，供 `toc.fanOutFrom: search.volumes` 使用。

规则求值流水线位于 `lib/rule_engine/pipeline`：

| 组件 | 职责 |
| --- | --- |
| `FieldEvaluator` | `const` / CSS / XPath / JSONPath / JS 取值与后处理（regex / template / fallback） |
| `RuleRequestBuilder` | 模板渲染、URL 解析与 host 白名单检查 |
| `RuleSearchPipeline` | `query` / `index` 两种搜索与分页 |
| `RuleDetailPipeline` | 单作品详情字段 |
| `RuleTocPipeline` | 平铺目录，或按 `detail.volumes` / `search.volumes` 逐组扇出 |
| `RuleContentPipeline` | `resolve` 二段请求 + 图片 / 文本 / 视频 / 文件正文 |

JS 字段由组合根注入 `JsRuntime`：生产实现是 `data/sandbox/flutter_js_runtime.dart`（QuickJS，懒加载），单元测试用假实现。`value` / `ctx` 是唯一注入的绑定；没有配置运行时时遇到 `js` 规则会判规则失败。

## 详情页与章节加载

`features/detail` 通过 `WorkRepository` 加载数据：

1. 按 `DiscoverItem.ruleId` 找到规则源；规则不存在时报 `StorageException`。
2. 有 `detail` 能力则走 `RuleDetailPipeline`，否则用搜索项字段兜底。
3. 有 `toc` 能力则走 `RuleTocPipeline`，把 `WorkDetail` 与 `SearchResult`（含 `extra`）传入以支持两种 `fanOutFrom`。
4. 章节点击时调用 `RuleContentPipeline` 抓取当前章节，再由 `mapRuleContent` 映射为 `ComicViewerLaunch` / `NovelViewerLaunch` / `VideoViewerLaunch` / `FileViewerLaunch`。

漫画与小说一次只加载当前章节，查看器内不预取全书；视频把正文的每条线路映射为一集。EPUB/TXT 等文件模式没有内置阅读器，详情页复制下载地址并提示用户。

### 内容来源检索

所有详情页都会做一次跨源检索，交互参考 Kazumi 的播放来源面板：`ContentSourceRepository` 从已启用、同 `MediaType`、同时具备 `search` 与 `content` 的其他规则中按 `priority` 搜索作品标题，并把结果**按来源分组**返回（每组的 `ok` / `noResult` / `failed` 状态互不影响）。

1. 标题相关（规范化后相等 / 包含）的结果优先，每个来源最多 3 条；标题全部无命中时依次尝试 `detail.aliases`（最多 2 个）。
2. 单个来源可以独立「修改检索词」「使用别名」「重新检索」，走 `refreshProvider`，只替换该来源而保留其它分组。
3. 当前规则没有 `content` 时区块默认展开（资料源需要引导用户去别处看正文）；有 `content` 时默认折叠为一行摘要，避免挤占目录。
4. 选中结果后在当前详情页替换作品并重新加载，不新增路由；新来源具备 `content`，目录随即变为可点击。

## 规则登录

规则包可选的 `login` 字段描述登录方式（`webview` / `headers`），真实凭据由用户在应用内完成登录后写入本地 `SourceAuthRecords` 表：

1. `features/sources` 的规则编辑器 / 规则列表打开 `/rule-login`；
2. `webview` 模式通过 `flutter_inappwebview` 打开登录页，用 `CookieManager` 抓取 Cookie（失败时回退 `document.cookie`），并可用 `successUrlPattern` 判定成功；
3. `headers` 模式或 WebView 不可用时，用户手动填写 Cookie / 请求头；
4. 保存时校验登录地址 host 属于 `baseUrl` / `allowedHosts`，凭据按 `pack.meta.id` 写入本地库；
5. `AuthenticatedRuleHttpClient` 在每次请求中按 `ruleId` 注入凭据；发现页封面、详情封面、漫画图片、视频 / 文件地址的请求头在仓储层同样合并凭据。

凭据永远不进入 `rulePackJson`，导出规则不会泄漏；日志输出前必须脱敏。删除规则时 `SourceDao.deleteById` 会在同一事务中清理对应凭据。

平台支持由 `flutter_inappwebview` 提供（Android / iOS / macOS / Windows / Linux）。Windows 构建需要 NuGet CLI，Linux 需要 WPE WebKit 及其依赖（libwpe / libsecret / wayland-server 等）。

## 内置规则集

`assets/rules/builtin/` 存放内置规则包，`index.json` 是清单（`id` / `file` / `enabledByDefault`）。`BuiltinRuleSeeder` 在启动时：

1. 读取清单，逐个包先用 `RulePackValidator` 校验，不通过只记日志并跳过；
2. 库里没有则写入（`origin=builtin`、`readOnly=true`、`priority` 取清单顺序）；
3. 已存在且是内置包时，仅当清单版本更高才覆盖，并保留用户的启用状态；
4. 同 id 但来自用户导入的规则不会被覆盖。

内置包只读，规则页可启用/停用；想改内容时用规则编辑器「另存为新规则」。

其中 `builtin.kazumi.*` 三条改写自 [KazumiRules](https://github.com/Predidit/KazumiRules)（MIT）的在用规则。原规则用 WebView + JS Hook 抓取播放地址，改写时按本站 schema 重写为 JSONPath / CSS 取值：能直接从公开接口或播放页拿到 HLS 直链的写 `content.mode=video`（GiriGiriLove 的地址直接来自目录条目，故 `content.url` 留空），拿不到的只保留 `search` / `detail` / `toc`。三条全部默认关闭。

## 状态管理

- 使用 Riverpod 3，**不启用** `riverpod_generator`：手写 provider 让依赖关系显式可见，也避免与 Drift 的 codegen 叠加。
- Provider 组织：`lib/data/providers.dart` 暴露基础设施（数据库、仓储）；页面级 provider 放在对应 feature 目录。
- `Provider` 默认不自动销毁；只有确实跟页面生命周期绑定的数据才加 `isAutoDispose: true`。
- 需要跨页共享可写状态时用 `Notifier`，不要用 `StateProvider`。

## 路由

`go_router` + `StatefulShellRoute.indexedStack`：四个主 tab 各自保留导航栈。路由实例由 `appRouterProvider` 创建，测试用新的 `ProviderScope` 即可拿到干净的路由状态。

新增页面：在 `lib/features/<feature>` 下建页面，路径常量加到 `AppRoutes`，再挂到对应分支（需要脱离底部导航的全屏页时，挂到根 `routes` 而不是 branch）。

## 查看器

三种内容各有一个全屏路由，挂在根 `routes` 上（不经过底部导航）；内容通过 `GoRouterState.extra` 传入 `domain/entities` 下的实体，类型不符时页面展示「缺少内容参数」。

| 路由 | 页面 | 入参 |
| --- | --- | --- |
| `/viewer/video` | `VideoViewerPage` | `VideoViewerContent`：分集播放源 + 弹幕 |
| `/viewer/comic` | `ComicViewerPage` | `ComicViewerContent`：章节 + 图片列表 |
| `/viewer/novel` | `NovelViewerPage` | `NovelViewerContent`：章节 + 段落 |

- 视频播放依赖 `VideoPlaybackController` 接口，默认实现是 media_kit（libmpv）；页面只读接口状态，测试用 `videoPlaybackControllerFactoryProvider` 覆盖为假实现。
- 弹幕拆成两层：`DanmakuEngine` 负责时间轴与轨道分配（纯逻辑、可单测），`DanmakuOverlay` 用 Ticker + CustomPaint 渲染，并与播放器位置周期性校正。
- 小说阅读设置（字号 / 行距 / 背景）与章节阅读进度持久化在 SharedPreferences；漫画用 `photo_view` 负责缩放与翻页。

## 错误处理

- 底层抛 `sealed AppException` 家族；`RuleFormatException` / `NetworkException` / `StorageException` / `UnsupportedCapabilityException`。
- `catch` 必须指定类型并使用 `error` 或日志记录，禁止 `catch (_) {}`。
- UI 只展示 l10n 文案，不直接展示异常 `toString()`；调试信息进日志。

## 扩展点

| 需求 | 做法 |
| --- | --- |
| 新增内容类型 | 扩展 `MediaType`（新增 `wireName`），同步 `docs/rule-spec.md` 与阅读器分发逻辑 |
| 新增规则能力 | 扩展 `RuleCapability`，在 `RulePackValidator` 增加该能力的必填字段校验，规则 `schemaVersion` +1 |
| 新增字段提取方式 | 扩展 `FieldRule` 的 source 键 + 校验器 + 求值器，`schemaVersion` +1 |
| 更换 JS 引擎 | 实现 `JsRuntime`，在组合根替换 `JsRuntimeFactory` |
| 新增存储表 | 在 `lib/data/db` 加表 + DAO，提升 `AppDatabase.schemaVersion` 并写迁移 |

## 关键决策记录

| 决策 | 理由 | 代价 |
| --- | --- | --- |
| 规则引擎独立成纯 Dart 模块 | 可单测、可复用、强制隔离 UI 依赖 | 需要在 `domain` 与引擎之间做映射 |
| JSON 声明式 + JS 表达式沙箱 | 站点结构差异大，纯选择器覆盖不了；JS 提供兜底表达力 | 需要沙箱与域名白名单，安全边界必须严守 |
| Drift 而非 NoSQL | 规则、进度、下载需要关系查询与迁移 | 需要 `build_runner` codegen |
| 生成物不入库 | 避免合并冲突和评审噪音 | 新环境必须先跑 `dart run tool/bootstrap.dart`，CI 也会跑 |
| `MediaType` 放在 `core/models` | 被 `rule_engine`、`domain`、`features` 共同使用，放在任一侧都会造成反向依赖 | 与直觉的"实体放 domain"略有偏差 |
| 播放器用 `media_kit` 而非官方 `video_player` | 官方插件不覆盖 Windows/Linux，而本项目需要全平台 | 需随包分发 libmpv，安装包变大 |
| 弹幕自研而非引入第三方包 | 需要与播放器时钟严格同步的轨道排版，且第三方包维护状态不一 | 需要自己维护排版与回收逻辑 |
| WebView 选用 `flutter_inappwebview` | 覆盖 Android / Windows / Linux，能读取 HttpOnly Cookie，避免为各平台各写一套 WebView | 依赖 beta 版本以启用 Linux 支持；Windows 构建需要 NuGet CLI；Linux 需要 WPE WebKit 依赖 |
| 登录凭据与规则包分离 | 规则可分享，凭据只属于本机用户；避免导出规则时泄漏 Token | 需要额外的本地表与请求注入层 |
