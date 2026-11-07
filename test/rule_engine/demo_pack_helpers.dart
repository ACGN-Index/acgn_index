import 'dart:convert';
import 'dart:io';

/// 读取 `assets/rules/demo_rule_pack.json`，测试与规则工具共用。
Map<String, Object?> loadDemoPack() =>
    jsonDecode(File('assets/rules/demo_rule_pack.json').readAsStringSync()) as Map<String, Object?>;

/// 深拷贝，便于在测试中安全地改动示例规则。
Map<String, Object?> cloneDemoPack() =>
    jsonDecode(jsonEncode(loadDemoPack())) as Map<String, Object?>;
