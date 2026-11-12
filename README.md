# ACGN Index

[![CI](https://github.com/ACGN-Index/acgn_index/actions/workflows/ci.yml/badge.svg)](https://github.com/ACGN-Index/acgn_index/actions/workflows/ci.yml)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B.svg)](https://flutter.dev)

基于**自定义规则**的番剧、漫画、小说采集与阅读客户端。

站点结构用 JSON 规则包描述，站点改版时改规则而不是改代码。APP 只负责解析规则、抓取公开页面、渲染阅读界面——**不托管、不分发任何内容**。

## 特性（规划）

| 能力 | 状态 |
| --- | --- |
| 规则包模型 / 校验 / 示例 | ✅ 已就绪 |
| 规则求值器与抓取流水线（搜索/详情/目录/正文） | ✅ 已就绪 |
| 发现、跨规则搜索、详情页 | 🚧 M2（详情页已接入） |
| 书架、阅读进度 | 🚧 M2 |
| 漫画阅读器 / 小说阅读器 | 🚧 M3 |
| 番剧播放 | 🚧 M4 |
| 下载与离线 | 🚧 M5 |
| 备份与恢复（本地 / WebDAV） | 🚧 M6 |
| 规则登录（WebView / 手动请求头） | ✅ 已就绪 |
| 规则编辑器与规则分享 | 🚧 M7 |

平台：Android、Windows、Linux（iOS/macOS 目录保留但未验证）。

发现页点击作品进入详情页，目录中的章节按需抓取正文后打开漫画 / 小说 / 视频查看器；漫画与小说一次加载当前章节，返回详情页可继续选章。

## 快速开始

需要 Flutter `3.47.2`（stable）。生成物不入库，克隆后先跑一次：

```bash
dart run tool/bootstrap.dart   # pub get → gen-l10n → build_runner
flutter run -d windows         # 或 -d <android-device-id>
```

WebView 登录依赖 `flutter_inappwebview`：Windows 构建机需要把 NuGet CLI 加入 `PATH`，运行需要 WebView2 Runtime（Windows 11 通常已内置）；Linux 运行环境需要 WPE WebKit 及其依赖（libwpe / libsecret / wayland-server 等，详见插件文档）。

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

### 内置规则集

首次启动会自动写入以下规则（可在「规则」页启用/停用）：

| 规则 | 类型 | 能力 | 默认 |
| --- | --- | --- | --- |
| Bangumi 番组计划（资料） | 动漫 | 搜索 / 详情 / 剧集表 | 启用 |
| Bangumi 番组计划（漫画资料） | 漫画 | 搜索 / 详情 | 启用 |
| LNovel（日轻中文文本） | 小说 | 索引搜索 / 详情 / 分卷目录 / 正文 | 关闭 |
| 轻小说文库（社区 EPUB 分卷） | 小说 | 索引搜索 / 分卷 / EPUB | 关闭 |
| GiriGiriLove（视频） | 动漫 | 搜索 / 详情 / 剧集表 / HLS 直链播放 | 关闭 |
| MX动漫（视频） | 动漫 | 搜索 / 详情 / 剧集表 / HLS 直链播放 | 关闭 |
| TvTFun（资料 + 目录） | 动漫 | 搜索 / 详情 / 剧集表 | 关闭 |

后三条改写自 [Predidit/KazumiRules](https://github.com/Predidit/KazumiRules)（MIT）中的在用规则，原规则依赖 WebView + JS Hook 抓取播放地址，这里改写为本项目的规则 schema：能直接从接口或播放页拿到 HLS 直链的写 `content.mode=video`，拿不到的只保留资料与剧集表（章节点击会提示「该源仅提供资料」）。全部默认关闭，需在「规则」页手动启用。

只包含公开接口的元数据与目录解析，不含内容托管；第三方来源默认关闭，是否启用由用户决定。规则页右下角可打开**规则编辑器**：可视化表单与 JSON 双模式编辑，支持新建、格式化、校验（逐条列出路径）并保存自己的规则。

需要登录的站点可在规则编辑器的「登录」分区声明登录方式（WebView 网页登录或手动请求头），并在规则列表或编辑器顶部打开登录页完成登录；Cookie / Token 只保存在本机，不会写入或导出规则包。

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
