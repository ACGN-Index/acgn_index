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
| `lib/core/utils` | JSON 读取辅助等无状态工具 |
| `lib/core/widgets` | 无业务语义的通用组件（空状态等） |
| `lib/data/db` | Drift 表定义、DAO、迁移 |
| `lib/data/repositories` | 仓储接口的 Drift/Dio 实现 |
| `lib/data/providers.dart` | 数据层的 Riverpod 组合根 |
| `lib/domain/entities` | 领域实体（不可变） |
| `lib/domain/repositories` | 仓储抽象接口 |
| `lib/rule_engine/models` | 规则包 schema 建模 + 序列化 |
| `lib/rule_engine/pipeline` | 校验、后续的求值/抓取流水线 |
| `lib/rule_engine/sandbox` | JS 运行时抽象与安全边界 |
| `lib/features/*/presentation` | 页面与页面级 provider |
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
[features/sources] 列表  →  [features/discover] 选择规则搜索
   ▼
RulePack.capabilities[search] → 求值器（M1）→ HTML/JSON → 作品列表
```

规则原文是唯一事实来源；`name`/`baseUrl`/`version` 只是为列表查询冗余的列，写入时必须与 JSON 同步（见 `DriftRuleSourceRepository.save`）。

## 状态管理

- 使用 Riverpod 3，**不启用** `riverpod_generator`：手写 provider 让依赖关系显式可见，也避免与 Drift 的 codegen 叠加。
- Provider 组织：`lib/data/providers.dart` 暴露基础设施（数据库、仓储）；页面级 provider 放在对应 `presentation` 目录。
- `Provider` 默认不自动销毁；只有确实跟页面生命周期绑定的数据才加 `isAutoDispose: true`。
- 需要跨页共享可写状态时用 `Notifier`，不要用 `StateProvider`。

## 路由

`go_router` + `StatefulShellRoute.indexedStack`：四个主 tab 各自保留导航栈。路由实例由 `appRouterProvider` 创建，测试用新的 `ProviderScope` 即可拿到干净的路由状态。

新增页面：在 `lib/features/<feature>/presentation` 下建页面，路径常量加到 `AppRoutes`，再挂到对应分支（需要脱离底部导航的全屏页时，挂到根 `routes` 而不是 branch）。

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
