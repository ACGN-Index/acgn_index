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
/// 求值链（M1 实现）：
/// `selector`(CSS) → [attribute] 或 [extractHtml] → [regex] 第 [regexGroup] 组
/// → [script] → [prefix]/[suffix] → [absolute] → [defaultValue]。
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
    this.prefix = '',
    this.suffix = '',
    this.absolute = false,
    this.defaultValue,
  });

  factory FieldRule.fromJson(Map<String, Object?> json) {
    final selector = json.stringOrNull('selector');
    final xpath = json.stringOrNull('xpath');
    final jsonPath = json.stringOrNull('jsonPath');
    final script = json.stringOrNull('js');
    final constant = json.stringOrNull('const');
    final sources = <String?>[selector, xpath, jsonPath, script, constant].nonNulls;
    if (sources.length != 1) {
      throw const RuleFormatException(
        '字段规则必须且只能声明 selector / xpath / jsonPath / js / const 之一',
      );
    }
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
      prefix: json.stringOrNull('prefix') ?? '',
      suffix: json.stringOrNull('suffix') ?? '',
      absolute: json.boolOrNull('absolute') ?? false,
      defaultValue: json.stringOrNull('default'),
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

  final String prefix;
  final String suffix;

  /// 把相对地址解析为绝对地址（基于规则包的 `baseUrl`）。
  final bool absolute;

  final String? defaultValue;

  /// 声明的取值来源数量，合法值恒为 1。
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
    if (attribute != null) 'attr': attribute,
    if (extractHtml) 'html': true,
    if (regex != null) 'regex': regex,
    if (regexGroup != 1) 'group': regexGroup,
    if (prefix.isNotEmpty) 'prefix': prefix,
    if (suffix.isNotEmpty) 'suffix': suffix,
    if (absolute) 'absolute': true,
    if (defaultValue != null) 'default': defaultValue,
  };
}
