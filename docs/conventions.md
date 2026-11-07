# 项目规范

本文件是代码与协作的唯一规范来源。`CONTRIBUTING.md` 只讲流程，规则细节以本文为准。

## 1. 环境与生成物

- Flutter `3.47.2`（stable）/ Dart `3.13.2`。版本以 `pubspec.yaml` 的 `environment.sdk` 与 CI 为准。
- 生成物（`*.g.dart`、`*.freezed.dart`、`lib/l10n/generated/`）**不入库**。
- 克隆或改动生成源后必须执行：

  ```bash
  dart run tool/bootstrap.dart
  ```

  它依次执行 `pub get` → `gen-l10n` → `build_runner build --delete-conflicting-outputs`。

## 2. 格式与静态检查

- `dart format` 是唯一格式权威，行宽 **100**（配置在 `analysis_options.yaml` 的 `formatter.page_width`），保留尾随逗号。
- `flutter analyze --fatal-infos` 必须 0 issue；warning/info 也不放行。
- 已开启 `strict-casts`、`strict-inference`、`strict-raw-types`。

## 3. 命名

| 对象 | 规则 | 示例 |
| --- | --- | --- |
| 文件/目录 | `snake_case` | `rule_source_repository.dart` |
| 类/枚举 | `PascalCase` | `RulePackValidator` |
| 变量/方法 | `lowerCamelCase` | `watchAll()` |
| 常量 | `lowerCamelCase` 或 `k` 前缀（schema 常量） | `kSupportedSchemaVersion` |
| Riverpod provider | 名词 + `Provider` 后缀 | `ruleSourceRepositoryProvider` |
| Drift 表 | 复数 `XxxTable` 语义名，行类型为单数 | `SourceRecords` → `SourceRecord` |
| 规则 JSON 键 | `lowerCamelCase`，一经发布不可重命名 | `baseUrl`、`schemaVersion` |

## 4. 分层依赖

见 [architecture.md](architecture.md)。新增文件前先确认它属于哪一层：

- 页面与页面状态 → `features/<feature>/presentation`
- 可复用的业务规则 → `domain`
- 外部 IO（网络、数据库、文件） → `data`
- 规则解析/求值 → `rule_engine`
- 无状态工具、值对象 → `core`

## 5. 错误处理与日志

- 底层用 `sealed AppException` 表达失败；调用方必须穷举或显式透传。
- 禁止空 `catch`；`catch` 捕获具体类型并记录 `AppLogger`。
- 生产代码禁止 `print`（`avoid_print` 已开启）。
- 日志中的 cookie、token、Authorization 头必须经 `AppLogger.redact` 处理。
- 用户可见文案一律走 l10n（`lib/l10n/app_zh.arb`），禁止在 widget 里硬编码中文。

## 6. 测试

- 测试目录镜像 `lib/`（`lib/rule_engine/x.dart` → `test/rule_engine/x_test.dart`）。
- 必须写单测的部分：规则模型与校验、仓储映射、任何纯函数业务逻辑。
- widget 测试覆盖主流程（启动、tab 切换、关键交互）；不追求覆盖率数字，但新增逻辑应带对应测试。
- 测试不得访问网络与真实数据库文件；Drift 用 `NativeDatabase.memory()`。

## 7. Git 工作流

- 分支：`feat/<scope>-<summary>`、`fix/...`、`docs/...`、`chore/...`；不直接推 `main`。
- 提交信息遵循 Conventional Commits：

  ```
  <type>(<scope>): <subject>

  <body>

  Co-authored-by: ...
  ```

  `type` ∈ `feat|fix|docs|refactor|test|chore|build|ci|perf`；
  `scope` ∈ `rule-engine|data|ui|sources|reader|docs|ci`。
- 一个 PR 只做一件事；提交前必须本地通过 `dart run tool/bootstrap.dart`、`dart format --output=none --set-exit-if-changed .`、`flutter analyze --fatal-infos`、`flutter test`。

## 8. 依赖政策

- 新增运行时依赖需要：明确用途、说明为何不能自己实现、确认全平台可用（Android + Windows + Linux）。
- 许可证必须与 GPL-3.0 **兼容**：允许 MIT/BSD/Apache-2.0/LGPL；**禁止**引入 GPL 不兼容或商业闭源组件。
- 优先使用仍在维护的包；注意 pub.dev 上标注 EOL/obsolete 的包（例如 `sqlite3_flutter_libs` 已由 `package:sqlite3` 3.x 内置能力取代）。
- 新增依赖用 `flutter pub add`（不手写版本号），并在 PR 描述里列出。

## 9. 文档职责

| 文档 | 内容 |
| --- | --- |
| `README.md` | 面向用户：是什么、怎么跑、免责声明 |
| `CONTRIBUTING.md` | 面向贡献者：流程、环境、PR/Issue |
| `docs/architecture.md` | 分层、数据流、扩展点、决策记录 |
| `docs/conventions.md` | 本文件：编码与协作规则 |
| `docs/rule-spec.md` | 规则包规范（**唯一权威**） |
| `CHANGELOG.md` | Keep a Changelog 格式 |

改动规则 schema 时，`docs/rule-spec.md`、校验器、示例规则、`schemaVersion` 必须同时改。

## 10. 规则合规政策

- 本仓库**不收录**任何真实站点的规则包，仅保留指向 `example.invalid` 的 Mock 示例。
- 不接受携带抓取真实站点的 PR；用户自行导入规则由用户承担合规责任。
- 应用本身不托管、不分发内容，只提供规则解析与阅读能力。
- 涉及版权投诉，见 `README.md` 的免责声明。
