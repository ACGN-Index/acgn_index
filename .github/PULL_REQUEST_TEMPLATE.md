## 变更说明

<!-- 做了什么、为什么这么做 -->

## 关联 Issue

<!-- Closes #123 -->

## 自检

- [ ] `dart run tool/bootstrap.dart` 成功，且未提交生成物（`*.g.dart` / `lib/l10n/generated/`）
- [ ] `dart format --output=none --set-exit-if-changed .` 无差异
- [ ] `flutter analyze --fatal-infos` 0 issue
- [ ] `flutter test` 全绿，新增逻辑有对应测试
- [ ] 用户可见文案走 l10n，无硬编码中文
- [ ] 未破坏分层依赖（`docs/architecture.md`）
- [ ] 若改动规则 schema：已同步 `docs/rule-spec.md`、校验器、示例规则与 `schemaVersion`
- [ ] 新增依赖已说明用途，许可证与 GPL-3.0 兼容
- [ ] 未包含真实站点规则或受版权保护内容

## 截图 / 录屏（UI 变更）

<!-- 可选 -->
