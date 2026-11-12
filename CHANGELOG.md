# Changelog

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 与 [语义化版本](https://semver.org/lang/zh-CN/)。

## [Unreleased]

### Added

- 项目初始化：Flutter 3.47 + Riverpod + go_router + Drift 骨架，四个主页面（书架/发现/规则/设置）。
- 规则引擎模型与校验器：`RulePack` / `RuleMeta` / `RequestRule` / `CapabilityRule` / `FieldRule`，规则 schema v1。
- `JsRuntime` 抽象，作为 JS 表达式沙箱的安全边界。
- Drift 数据库与 `RuleSourceRepository`（规则源持久化）。
- 中文本地化（gen-l10n）与 Material 3 主题。
- 工程规范：`docs/architecture.md`、`docs/conventions.md`、`docs/rule-spec.md`。
- GitHub Actions CI（format / analyze / test）、Issue 与 PR 模板。
- `tool/bootstrap.dart` 一键生成 l10n 与 Drift 代码。
- 查看器基建：视频（media_kit + 弹幕）、漫画（缩放翻页）、小说（排版 / 阅读进度 / 阅读设置）三个全屏页面，挂在 `/viewer/*` 根路由。
- 新增依赖：`media_kit` / `media_kit_video` / `media_kit_libs_video`（全平台播放）、`photo_view`（漫画缩放）。
- 规则模型扩展（仍为 schema v1）：单值 `meta.type`、`content.mode`（video/images/text/file）、`search.mode=index` 本地过滤、`toc.fanOutFrom` 按卷扇出、`FieldRule` 的 `multiple` / `template` / `fallback` / `items` / `htmlToText`、能力级 `headers`、`content.resolve` 与 `meta.allowedHosts`。
- 内置规则集（`assets/rules/builtin`）：Bangumi 动漫资料、Bangumi 漫画资料（默认启用），LNovel 日轻文本、轻小说文库 EPUB 分卷（默认关闭）。
- `BuiltinRuleSeeder`：启动时校验并写入内置规则，只读、保留用户启用状态、版本更高才更新。
- 规则页改版：内置 / 已导入分区、类型徽标、来源说明与启用开关。
- 规则编辑器：右下角悬浮按钮进入，支持 JSON 语法高亮输入、格式化、校验（逐条列出路径）、保存；内置规则只读并可另存副本。
- 规则编辑器可视化模式：按基础信息 / 请求 / 搜索 / 详情 / 目录 / 正文分区编辑，字段规则支持 CSS / XPath / JSONPath / JS / 常量 / 对象数组与后处理选项，能力的启停、索引、分页、分卷与二段请求均可表单配置，并与 JSON 模式实时双向同步。
- 规则 `search` 求值流水线：模板渲染、JSONPath 子集、CSS / XPath / JSONPath 字段求值、Dio HTTP 客户端、host 白名单与 `query` / `index` 分页。
- M1 抓取流水线补齐：`RuleDetailPipeline`、`RuleTocPipeline`（平铺目录 / `fanOutFrom` 分卷扇出 / 分组）、`RuleContentPipeline`（`resolve` 二段请求与 video / images / text / file 四种正文）。
- JS 字段求值：`flutter_js`（QuickJS）运行时注入 `value` / `ctx`，支持表达式与函数形式；`FieldRule` 允许一个主来源附加 `js` 后处理。
- 作品详情页：发现页卡片进入 `/work`，展示详情与分组目录，章节按需抓取并打开漫画 / 小说 / 视频查看器；EPUB/TXT 文件模式复制下载地址。
- 详情页内容来源：所有详情页按来源分组展示其它启用且具备正文能力的同类型规则，参考 Kazumi 的播放来源面板：每个来源有独立检索词、状态与结果，可改词 / 换别名 / 重试；标题无命中时按 `detail.aliases` 兜底；选中后在当前页替换作品。
- `WorkRepository` 编排详情 / 目录 / 正文，`mapRuleContent` 把引擎结果映射为现有查看器实体。
- 发现页：聚合所有启用规则的搜索结果，展示作品封面网格、类型 / 成人徽标，支持类型 / 来源筛选、下拉刷新与部分规则失败提示。
- 内置规则集新增 3 条改写自 [KazumiRules](https://github.com/Predidit/KazumiRules)（MIT）的视频规则：GiriGiriLove、MX动漫（可从公开接口 / 播放页取到 HLS 直链并播放），TvTFun（仅资料与剧集表）；全部默认关闭，`index.json` 清单版本升到 `1.1.0`。
- `content` 视频能力支持省略请求地址：`fields.url` / `fields.urls` 已声明时直接用 `{{chapter.url}}` 等目录字段构造播放源，不再发起额外请求。
- 规则登录：`login` 声明（`webview` / `headers`）、WebView 登录页抓取 Cookie、手动 Cookie / 请求头、登录状态展示与退出登录；本地凭据自动注入搜索 / 详情 / 目录 / 正文以及封面 / 图片 / 视频 / 文件请求头，凭据不写入规则包。
- 新增依赖：`flutter_inappwebview`（beta，覆盖 Android / Windows / Linux 等平台的 WebView 登录）。
- Drift `SourceAuthRecords` 本地登录凭据表，数据库 schema 升到 3；删除规则时一并清理凭据。
- 发现页下滑分页：`DiscoverFeedRepository.loadMore` 按 `RulePageCursor`（规则 + 页码）继续拉取，滚动到距底部 600px 内自动追加下一页，底部展示加载中 / 加载失败重试 / 没有更多内容。
- 跨规则搜索页 `/search`：发现页右上角搜索入口打开，关键词防抖 400ms 并发检索所有启用规则的 `search` 接口，结果按规则分组展示并支持下滑分页，组内作品可进入详情页。

### Changed

- Android `applicationId` 与 `namespace` 改为 `io.github.acgnindex.acgn_index`。
- 目录结构去掉 `features/*/presentation` 层级，页面与页面级 provider 直接放在 feature 目录下。
- 默认启动页改为「发现」。
- 发现页由占位页改为作品网格，首屏按空关键词聚合启用规则的搜索结果。
- `DiscoverItem` 增加 `extra`，保留搜索结果字段供目录 `fanOutFrom` 使用。
- Drift `SourceRecords` 增加 `type` / `origin` / `readOnly` / `notice` / `priority`，数据库 schema 升到 2 并带迁移。
- Windows 构建为 `flutter_inappwebview_windows` 增加 MSVC coroutine 兼容宏，兼容新版 Visual Studio。
- 发现页作品网格改为按可用宽度自适应列数：窄屏（手机）至少 3 列，卡片变窄时间距、内边距与字号同步收紧，宽屏列数随宽度增长。
- 发现页右上角的刷新按钮改为搜索入口（下拉刷新保持不变）；作品网格的列数计算抽到 `DiscoverGridMetrics`，与搜索页共用。

[Unreleased]: https://github.com/ACGN-Index/acgn_index/commits/main
