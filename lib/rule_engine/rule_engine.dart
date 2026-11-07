/// 规则引擎对外 API。
///
/// 本模块是纯 Dart，禁止 import `package:flutter/*` 以及 `data`/`features` 层，
/// 以便独立单测并被未来的 CLI 规则工具复用。
library;

export 'models/capability_rule.dart';
export 'models/field_rule.dart';
export 'models/rule_pack.dart';
export 'models/validation_result.dart';
export 'pipeline/rule_pack_validator.dart';
export 'sandbox/js_runtime.dart';
