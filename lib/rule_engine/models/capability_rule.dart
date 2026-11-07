import 'package:acgn_index/core/utils/json_utils.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';

/// 规则包可声明的四种能力。
enum RuleCapability {
  search('search'),
  detail('detail'),
  toc('toc'),
  content('content');

  const RuleCapability(this.wireName);

  final String wireName;

  static RuleCapability? tryParse(String? value) =>
      values.where((capability) => capability.wireName == value).firstOrNull;
}

/// 一种能力的实现：请求模板 + 列表选择器 + 字段提取规则。
///
/// [url] 与 [body] 支持模板变量：`{{baseUrl}}`、`{{key}}`、`{{page}}`、
/// `{{id}}`、`{{url}}`、`{{chapterUrl}}`。
class CapabilityRule {
  const CapabilityRule({
    required this.url,
    this.method = 'GET',
    this.body,
    this.list,
    this.fields = const <String, FieldRule>{},
  });

  factory CapabilityRule.fromJson(Map<String, Object?> json) {
    final fieldsJson = json.mapOrNull('fields') ?? const <String, Object?>{};
    final fields = <String, FieldRule>{};
    for (final entry in fieldsJson.entries) {
      fields[entry.key] = FieldRule.fromJson(
        asJsonMap(entry.value, path: 'fields.${entry.key}'),
      );
    }
    final listJson = json.mapOrNull('list');
    return CapabilityRule(
      url: json.stringOrNull('url') ?? '',
      method: (json.stringOrNull('method') ?? 'GET').toUpperCase(),
      body: json.stringOrNull('body'),
      list: listJson == null ? null : FieldRule.fromJson(listJson),
      fields: fields,
    );
  }

  final String url;
  final String method;
  final String? body;

  /// 列表页的条目选择器（搜索结果的每一项、目录的每一话）。
  final FieldRule? list;

  /// 从条目/详情页提取的字段，键名由能力语义约定（如 `id`、`title`、`cover`）。
  final Map<String, FieldRule> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'method': method,
    if (body != null) 'body': body,
    if (list != null) 'list': list!.toJson(),
    if (fields.isNotEmpty)
      'fields': <String, Object?>{
        for (final entry in fields.entries) entry.key: entry.value.toJson(),
      },
  };
}
