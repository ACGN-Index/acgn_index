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

### Changed

- Android `applicationId` 与 `namespace` 改为 `io.github.acgnindex.acgn_index`。

[Unreleased]: https://github.com/ACGN-Index/ACGN-Index/commits/main
