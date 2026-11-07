# 贡献指南

感谢参与 ACGN Index。请先阅读 [行为准则](CODE_OF_CONDUCT.md) 与 [项目规范](docs/conventions.md)。

## 环境准备

1. 安装 Flutter `3.47.2`（stable）与对应平台的构建工具链（Android SDK / Visual Studio Build Tools / clang）。
2. 克隆后执行一次性初始化：

   ```bash
   dart run tool/bootstrap.dart
   ```

3. 提交前自检（与 CI 一致）：

   ```bash
   dart format --output=none --set-exit-if-changed .
   flutter analyze --fatal-infos
   flutter test
   ```

生成物（`*.g.dart`、`lib/l10n/generated/`）已被忽略：改了 Drift 表或 ARB 后记得重新跑 `bootstrap`，并**不要**把生成文件提交进 PR。

## 分支与提交

- 分支名：`feat/<scope>-<summary>`、`fix/<scope>-<summary>`、`docs/...`、`chore/...`。
- 默认分支是 `main`，请通过 PR 合入，不要直接推送。
- 提交信息遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

  ```
  feat(rule-engine): 支持 JSONPath 取值

  - 新增 FieldRule.jsonPath
  - 校验器补充对应错误

  Co-authored-by: Name <email>
  ```

  `type`：`feat|fix|docs|refactor|test|chore|build|ci|perf`
  `scope`：`rule-engine|data|ui|sources|reader|docs|ci`

## PR 检查清单

- [ ] `dart run tool/bootstrap.dart` 成功，且未提交生成物
- [ ] `dart format` 无差异
- [ ] `flutter analyze --fatal-infos` 0 issue
- [ ] `flutter test` 全绿；新增逻辑带对应测试
- [ ] 用户可见文案走 l10n，未硬编码中文
- [ ] 分层依赖未被破坏（见 `docs/architecture.md`）
- [ ] 如改动规则 schema，已同步 `docs/rule-spec.md`、校验器与示例规则
- [ ] 新增依赖已说明理由，且许可证与 GPL-3.0 兼容

## 新增依赖

- 用 `flutter pub add <pkg>` / `flutter pub add dev:<pkg>`，不要手写版本号。
- 优先仍在维护的包；注意 pub.dev 上的 EOL/obsolete 标注。
- 许可证必须与 GPL-3.0 兼容；不引入闭源或 GPL 不兼容组件。
- 在 PR 描述中列出新增依赖及用途。

## 规则提交政策

- 本仓库**不收录**任何真实站点的规则包，PR 中只有 `example.invalid` 的 Mock 示例会被接受。
- 不要提交抓取受版权保护内容的规则、绕过付费墙/DRM 的规则。
- 规则格式变更请同时提 Issue 讨论，避免与他人工作冲突。

## Issue

- Bug 报告请提供平台、版本、复现步骤与日志（注意脱敏）。
- 规则相关问题请附规则包 JSON 片段（同样脱敏），并说明期望与实际结果。
