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

### Changed

- Android `applicationId` 与 `namespace` 改为 `io.github.acgnindex.acgn_index`。
- 目录结构去掉 `features/*/presentation` 层级，页面与页面级 provider 直接放在 feature 目录下。

[Unreleased]: https://github.com/ACGN-Index/acgn_index/commits/main
