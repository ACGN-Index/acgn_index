# ACGN Index

[![CI](https://github.com/ACGN-Index/ACGN-Index/actions/workflows/ci.yml/badge.svg)](https://github.com/ACGN-Index/ACGN-Index/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B.svg)](https://flutter.dev)

基于**自定义规则**的番剧、漫画、小说采集与阅读客户端。

站点结构用 JSON 规则包描述，站点改版时改规则而不是改代码。APP 只负责解析规则、抓取公开页面、渲染阅读界面——**不托管、不分发任何内容**。

## 特性（规划）

| 能力 | 状态 |
| --- | --- |
| 规则包模型 / 校验 / 示例 | ✅ 已就绪 |
| 规则求值器与抓取流水线（搜索/详情/目录/正文） | 🚧 M1 |
| 发现、跨规则搜索、详情页 | 🚧 M2 |
| 书架、阅读进度 | 🚧 M2 |
| 漫画阅读器 / 小说阅读器 | 🚧 M3 |
| 番剧播放 | 🚧 M4 |
| 下载与离线 | 🚧 M5 |
| 备份与恢复（本地 / WebDAV） | 🚧 M6 |
| 规则编辑器与规则分享 | 🚧 M7 |

平台：Android、Windows、Linux（iOS/macOS 目录保留但未验证）。

## 快速开始

需要 Flutter `3.47.2`（stable）。生成物不入库，克隆后先跑一次：

```bash
dart run tool/bootstrap.dart   # pub get → gen-l10n → build_runner
flutter run -d windows         # 或 -d <android-device-id>
```

提交前自检：

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test
```

## 规则

规则包是一个 JSON 文件（`.acgn.json`），声明 `search` / `detail` / `toc` / `content` 四种能力，字段取值支持 CSS 选择器、XPath、JSONPath、正则与 JS 表达式。

- 规范：[docs/rule-spec.md](docs/rule-spec.md)
- 示例：[assets/rules/demo_rule_pack.json](assets/rules/demo_rule_pack.json)（指向 `example.invalid`，仅用于开发测试）

## 项目结构

```
lib/
├── app/           主题、路由、根组件
├── core/          值对象、异常、日志、通用组件
├── domain/        实体与仓储接口
├── data/          Drift / 仓储实现
├── rule_engine/   规则模型、校验、沙箱（纯 Dart）
└── features/      各功能模块的页面
```

设计说明见 [docs/architecture.md](docs/architecture.md)，编码规范见 [docs/conventions.md](docs/conventions.md)。

## 免责声明

- 本项目仅提供规则解析与阅读工具，**不提供、不托管、不传播任何受版权保护的内容**。
- 仓库内不含任何真实站点规则。用户自行编写或导入的规则由用户自行承担合规责任；请遵守目标站点服务条款与当地法律法规。
- 若权利人认为本项目相关内容侵犯其权益，请通过仓库 Issue 联系我们，我们会及时处理。

## 贡献

见 [CONTRIBUTING.md](CONTRIBUTING.md) 与 [行为准则](CODE_OF_CONDUCT.md)。**不接受**抓取真实站点的规则包 PR。

## 许可证

本项目采用 [GNU General Public License v3.0](LICENSE) 发布，版权归 `acgn_index contributors` 所有。
