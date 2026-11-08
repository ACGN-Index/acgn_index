import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/utils/json_utils.dart';

/// 字段取值来源。一个 [FieldRule] 必须且只能声明一种来源。
enum FieldSource {
  constant('const'),
  css('selector'),
  xpath('xpath'),
  jsonPath('jsonPath'),
  javaScript('js');

  const FieldSource(this.jsonKey);

  final String jsonKey;
}

/// 单个字段的取值规则。
///
/// 求值链：
/// `selector`(CSS) / `xpath` / `jsonPath` / `js` / `const`
/// → [attribute] 或 [extractHtml] 或 [htmlToText]
/// → `regex` 第 [regexGroup] 组
/// → `js`
/// → [template]（`{{value}}` / `{{ctx.xxx}}`）
/// → [prefix]/[suffix]
/// → [absolute]
/// → [fallback] 或 [defaultValue]。
///
/// 声明 [items] 时不使用取值来源：父规则负责选出对象数组，[fields] 逐项求值。
class FieldRule {
  const FieldRule({
    this.selector,
    this.xpath,
    this.jsonPath,
    this.script,
    this.constant,
    this.attribute,
    this.extractHtml = false,
    this.regex,
    this.regexGroup = 1,
    this.multiple = false,
    this.template,
    this.prefix = '',
    this.suffix = '',
    this.absolute = false,
    this.htmlToText = false,
    this.defaultValue,
    this.fallback,
    this.items,
    this.fields = const <String, FieldRule>{},
  });

  factory FieldRule.fromJson(Map<String, Object?> json) {
    final selector = json.stringOrNull('selector');
    final xpath = json.stringOrNull('xpath');
    final jsonPath = json.stringOrNull('jsonPath');
    final script = json.stringOrNull('js');
    final constant = json.stringOrNull('const');
    final itemsJson = json.mapOrNull('items');
    final sources = <String?>[selector, xpath, jsonPath, script, constant].nonNulls;
    if (sources.length > 1) {
      throw const RuleFormatException(
        '字段规则只能声明 selector / xpath / jsonPath / js / const 之一',
      );
    }
    if (sources.isEmpty && itemsJson == null) {
      throw const RuleFormatException(
        '字段规则必须声明 selector / xpath / jsonPath / js / const 之一，或声明 items',
      );
    }
    if (sources.isNotEmpty && itemsJson != null) {
      throw const RuleFormatException('items 不能与 selector / xpath / jsonPath / js / const 同时声明');
    }

    final fieldsJson = json.mapOrNull('fields') ?? const <String, Object?>{};
    final fields = <String, FieldRule>{};
    for (final entry in fieldsJson.entries) {
      fields[entry.key] = FieldRule.fromJson(
        asJsonMap(entry.value, path: 'fields.${entry.key}'),
      );
    }
    final fallbackJson = json.mapOrNull('fallback');

    return FieldRule(
      selector: selector,
      xpath: xpath,
      jsonPath: jsonPath,
      script: script,
      constant: constant,
      attribute: json.stringOrNull('attr'),
      extractHtml: json.boolOrNull('html') ?? false,
      regex: json.stringOrNull('regex'),
      regexGroup: json.intOrNull('group') ?? 1,
      multiple: json.boolOrNull('multiple') ?? false,
      template: json.stringOrNull('template'),
      prefix: json.stringOrNull('prefix') ?? '',
      suffix: json.stringOrNull('suffix') ?? '',
      absolute: json.boolOrNull('absolute') ?? false,
      htmlToText: json.boolOrNull('htmlToText') ?? false,
      defaultValue: json.stringOrNull('default'),
      fallback: fallbackJson == null ? null : FieldRule.fromJson(fallbackJson),
      items: itemsJson == null ? null : FieldRule.fromJson(itemsJson),
      fields: fields,
    );
  }

  final String? selector;
  final String? xpath;
  final String? jsonPath;
  final String? script;
  final String? constant;

  /// 取属性名；为空时取文本节点。
  final String? attribute;

  /// 取 `innerHtml` 而不是文本。
  final bool extractHtml;

  final String? regex;

  /// 正则捕获组序号，默认 1（第 0 组为整段匹配）。
  final int regexGroup;

  /// 取全部匹配结果（DOM 多节点 / JSON 数组），保持原始顺序。
  final bool multiple;

  /// 结果模板，支持 `{{value}}` 与 `{{ctx.xxx}}`。
  final String? template;

  /// 把 HTML 片段按块级标签切成纯文本段落。
  final bool htmlToText;

  final String prefix;
  final String suffix;

  /// 把相对地址解析为绝对地址（基于规则包的 `baseUrl`）。
  final bool absolute;

  final String? defaultValue;

  /// 前一步为空时改用的规则。
  final FieldRule? fallback;

  /// 对象数组的条目选择规则；与取值来源互斥。
  final FieldRule? items;

  /// [items] 每个条目的子字段。
  final Map<String, FieldRule> fields;

  /// 是否为对象数组字段（`items` + `fields`）。
  bool get isObjectList => items != null;

  /// 声明的取值来源数量；对象数组字段为 0。
  int get sourceCount => <String?>[selector, xpath, jsonPath, script, constant].nonNulls.length;

  FieldSource? get source {
    if (selector != null) return FieldSource.css;
    if (xpath != null) return FieldSource.xpath;
    if (jsonPath != null) return FieldSource.jsonPath;
    if (script != null) return FieldSource.javaScript;
    if (constant != null) return FieldSource.constant;
    return null;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    if (selector != null) 'selector': selector,
    if (xpath != null) 'xpath': xpath,
    if (jsonPath != null) 'jsonPath': jsonPath,
    if (script != null) 'js': script,
    if (constant != null) 'const': constant,
    if (items != null) 'items': items!.toJson(),
    if (fields.isNotEmpty)
      'fields': <String, Object?>{
        for (final entry in fields.entries) entry.key: entry.value.toJson(),
      },
    if (attribute != null) 'attr': attribute,
    if (extractHtml) 'html': true,
    if (regex != null) 'regex': regex,
    if (regexGroup != 1) 'group': regexGroup,
    if (multiple) 'multiple': true,
    if (template != null) 'template': template,
    if (prefix.isNotEmpty) 'prefix': prefix,
    if (suffix.isNotEmpty) 'suffix': suffix,
    if (absolute) 'absolute': true,
    if (htmlToText) 'htmlToText': true,
    if (fallback != null) 'fallback': fallback!.toJson(),
    if (defaultValue != null) 'default': defaultValue,
  };
}
