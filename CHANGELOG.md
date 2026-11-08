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

### Changed

- Android `applicationId` 与 `namespace` 改为 `io.github.acgnindex.acgn_index`。
- 目录结构去掉 `features/*/presentation` 层级，页面与页面级 provider 直接放在 feature 目录下。
- 默认启动页改为「发现」。
- Drift `SourceRecords` 增加 `type` / `origin` / `readOnly` / `notice` / `priority`，数据库 schema 升到 2 并带迁移。

[Unreleased]: https://github.com/ACGN-Index/acgn_index/commits/main
