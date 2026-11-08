import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/utils/html_text.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/pipeline/json_path.dart';
import 'package:acgn_index/rule_engine/pipeline/template_renderer.dart';
import 'package:acgn_index/rule_engine/sandbox/js_runtime.dart';
import 'package:html/dom.dart' as dom;
import 'package:xml/xml.dart' as xml;
import 'package:xml/xpath.dart';

/// 字段求值上下文：当前页面或条目的文档节点 + 模板变量。
class RuleEvalContext {
  const RuleEvalContext({
    required this.pack,
    required this.pageUri,
    this.json,
    this.htmlDocument,
    this.htmlElement,
    this.xmlNode,
    this.variables = const <String, Object?>{},
  });

  final RulePack pack;
  final Uri pageUri;
  final Object? json;
  final dom.Document? htmlDocument;
  final dom.Element? htmlElement;
  final xml.XmlNode? xmlNode;
  final Map<String, Object?> variables;

  RuleEvalContext withEntry(Object? entry) => RuleEvalContext(
    pack: pack,
    pageUri: pageUri,
    json: entry is dom.Element || entry is xml.XmlNode ? null : entry,
    htmlElement: entry is dom.Element ? entry : null,
    xmlNode: entry is xml.XmlNode ? entry : null,
    variables: variables,
  );

  RuleEvalContext withVariables(Map<String, Object?> extra) => RuleEvalContext(
    pack: pack,
    pageUri: pageUri,
    json: json,
    htmlDocument: htmlDocument,
    htmlElement: htmlElement,
    xmlNode: xmlNode,
    variables: <String, Object?>{...variables, ...extra},
  );
}

/// 按 [FieldRule] 的取值链求值。
class FieldEvaluator {
  const FieldEvaluator({this.jsRuntime});

  /// 可选的 JS 沙箱；没有配置时遇到 `js` 规则会抛
  /// [UnsupportedCapabilityException]。
  final JsRuntime? jsRuntime;

  /// 取列表选择器的全部原始条目，供 search / toc 等列表能力使用。
  List<Object?> resolveItems(FieldRule rule, RuleEvalContext context) {
    final script = rule.script;
    if (script != null && rule.primarySource == null) {
      final result = _evaluateScript(script, _contextValue(context), context);
      if (result is List<Object?>) {
        return result;
      }
      return result == null ? const <Object?>[] : <Object?>[result];
    }
    return _resolveSource(rule, context).toList(growable: false);
  }

  Object? evaluate(FieldRule rule, RuleEvalContext context) {
    if (rule.isObjectList) {
      return _evaluateObjectList(rule, context);
    }
    final script = rule.script;
    if (script != null && rule.primarySource == null) {
      final result = _evaluateScript(script, _contextValue(context), context);
      final values = _finalizeScriptResult(rule, result, context);
      if (values.isNotEmpty) {
        return rule.multiple ? values : values.first;
      }
      return _fallbackValue(rule, context);
    }
    final rawValues = _resolveSource(rule, context);
    if (rule.multiple) {
      final values = <String>[];
      for (final raw in rawValues) {
        final value = _postProcess(rule, raw, context);
        if (value != null) {
          values.add(value);
        }
      }
      if (values.isNotEmpty) {
        return values;
      }
    } else {
      for (final raw in rawValues) {
        final value = _postProcess(rule, raw, context);
        if (value != null) {
          return value;
        }
      }
    }
    return _fallbackValue(rule, context);
  }

  List<Map<String, String>> _evaluateObjectList(FieldRule rule, RuleEvalContext context) {
    final items = rule.items;
    if (items == null) {
      return const <Map<String, String>>[];
    }
    final result = <Map<String, String>>[];
    for (final entry in resolveItems(items, context)) {
      final entryContext = context.withEntry(entry);
      final values = <String, String>{};
      for (final field in rule.fields.entries) {
        final value = evaluate(field.value, entryContext);
        final text = _joinValue(value);
        if (text.isNotEmpty) {
          values[field.key] = text;
        }
      }
      if (values.isNotEmpty) {
        result.add(values);
      }
    }
    return result;
  }

  Iterable<Object?> _resolveSource(FieldRule rule, RuleEvalContext context) {
    final constant = rule.constant;
    if (constant != null) {
      return <Object?>[renderTemplate(constant, _templateVariables(context, null))];
    }
    final jsonPath = rule.jsonPath;
    if (jsonPath != null) {
      if (context.json == null) {
        throw const RuleFormatException('jsonPath 需要 JSON 响应上下文');
      }
      return evaluateJsonPath(context.json, jsonPath);
    }
    final selector = rule.selector;
    if (selector != null) {
      final element = context.htmlElement;
      if (element != null) {
        return element.querySelectorAll(selector).cast<Object?>();
      }
      final document = context.htmlDocument;
      if (document != null) {
        return document.querySelectorAll(selector).cast<Object?>();
      }
      throw const RuleFormatException('selector 需要 HTML 响应上下文');
    }
    final xpath = rule.xpath;
    if (xpath != null) {
      final node = context.xmlNode;
      if (node == null) {
        throw const RuleFormatException('xpath 需要 XML 响应上下文');
      }
      return node.xpath(xpath).cast<Object?>();
    }
    throw const RuleFormatException('字段规则缺少取值来源');
  }

  String? _postProcess(FieldRule rule, Object? raw, RuleEvalContext context) {
    var value = _extract(raw, rule);
    if (value == null) {
      return null;
    }
    if (rule.htmlToText) {
      value = htmlToPlainText(value);
    }
    value = _applyRegex(rule, value);
    if (value == null) {
      return null;
    }
    final script = rule.script;
    if (script != null) {
      final result = _evaluateScript(script, value, context);
      value = _scriptResultToString(result);
      if (value == null) {
        return null;
      }
    }
    return _applyTemplateAndSuffix(rule, value, context);
  }

  List<String> _finalizeScriptResult(
    FieldRule rule,
    Object? result,
    RuleEvalContext context,
  ) {
    final rawValues = rule.multiple && result is List<Object?> ? result : <Object?>[result];
    final values = <String>[];
    for (final raw in rawValues) {
      var value = _scriptResultToString(raw);
      if (value == null) {
        continue;
      }
      if (rule.htmlToText) {
        value = htmlToPlainText(value);
      }
      value = _applyRegex(rule, value);
      if (value == null) {
        continue;
      }
      final finalValue = _applyTemplateAndSuffix(rule, value, context);
      if (finalValue != null) {
        values.add(finalValue);
      }
    }
    return values;
  }

  String? _applyRegex(FieldRule rule, String value) {
    final regex = rule.regex;
    if (regex == null) {
      return value;
    }
    final match = RegExp(regex).firstMatch(value);
    if (match == null) {
      return null;
    }
    return rule.regexGroup == 0 ? match.group(0) : match.group(rule.regexGroup);
  }

  String? _applyTemplateAndSuffix(
    FieldRule rule,
    String value,
    RuleEvalContext context,
  ) {
    var result = value;
    final template = rule.template;
    if (template != null) {
      result = renderTemplate(template, _templateVariables(context, result));
    }
    if (rule.prefix.isNotEmpty) {
      result = '${rule.prefix}$result';
    }
    if (rule.suffix.isNotEmpty) {
      result = '$result${rule.suffix}';
    }
    if (rule.absolute && result.trim().isNotEmpty) {
      result = context.pageUri.resolve(result.trim()).toString();
    }
    return result.trim().isEmpty ? null : result;
  }

  Object? _fallbackValue(FieldRule rule, RuleEvalContext context) {
    final fallback = rule.fallback;
    if (fallback != null) {
      final fallbackValue = evaluate(fallback, context);
      if (_hasValue(fallbackValue)) {
        return fallbackValue;
      }
    }
    return rule.defaultValue ?? (rule.multiple ? const <String>[] : null);
  }

  Object? _evaluateScript(String script, Object? value, RuleEvalContext context) {
    final runtime = jsRuntime;
    if (runtime == null) {
      throw UnsupportedCapabilityException('未配置 JS 运行时，无法执行：$script');
    }
    try {
      return runtime.evaluate(
        script,
        bindings: <String, Object?>{'value': value, 'ctx': _scriptContext(context)},
      );
    } on AppException {
      rethrow;
    } on Object catch (error, stackTrace) {
      throw RuleFormatException('JS 执行失败：$error', cause: error, stackTrace: stackTrace);
    }
  }

  Object? _contextValue(RuleEvalContext context) {
    final json = context.json;
    if (json != null) {
      return json;
    }
    final element = context.htmlElement;
    if (element != null) {
      return <String, Object?>{
        'text': element.text,
        'html': element.innerHtml,
        'attributes': element.attributes,
      };
    }
    final document = context.htmlDocument;
    if (document != null) {
      return document.body?.text;
    }
    return context.xmlNode?.innerText;
  }

  Map<String, Object?> _scriptContext(RuleEvalContext context) {
    final result = <String, Object?>{};
    for (final entry in context.variables.entries) {
      result[entry.key] = entry.value;
      if (entry.key.startsWith('ctx.')) {
        result[entry.key.substring(4)] = entry.value;
      }
    }
    result['baseUrl'] = context.pack.meta.baseUrl;
    result['pageUri'] = context.pageUri.toString();
    result['json'] = context.json;
    return result;
  }

  String? _scriptResultToString(Object? result) {
    if (result == null) {
      return null;
    }
    if (result is String) {
      return result;
    }
    if (result is bool) {
      return result ? 'true' : 'false';
    }
    if (result is Map<Object?, Object?> || result is List<Object?>) {
      return jsonEncode(result);
    }
    return result.toString();
  }

  String? _extract(Object? raw, FieldRule rule) {
    if (raw == null) {
      return null;
    }
    if (rule.extractHtml) {
      return _htmlOf(raw);
    }
    final attribute = rule.attribute;
    if (attribute != null) {
      return _attributeOf(raw, attribute);
    }
    return _textOf(raw);
  }

  String? _textOf(Object? raw) {
    if (raw is dom.Element) {
      return raw.text.trim();
    }
    if (raw is dom.Node) {
      return raw.text?.trim();
    }
    if (raw is xml.XmlNode) {
      final value = raw.value;
      if (value != null) {
        return value.trim();
      }
      return raw.innerText.trim();
    }
    if (raw is String) {
      return raw.trim();
    }
    if (raw is Map<Object?, Object?> || raw is List<Object?>) {
      return jsonEncode(raw);
    }
    return raw.toString();
  }

  String? _htmlOf(Object? raw) {
    if (raw is dom.Element) {
      return raw.innerHtml;
    }
    if (raw is xml.XmlNode) {
      return raw.toXmlString();
    }
    return _textOf(raw);
  }

  String? _attributeOf(Object? raw, String name) {
    if (raw is dom.Element) {
      return raw.attributes[name] ?? raw.attributes[name.toLowerCase()];
    }
    if (raw is xml.XmlElement) {
      return raw.getAttribute(name);
    }
    if (raw is Map<Object?, Object?>) {
      return raw[name]?.toString();
    }
    return null;
  }

  Map<String, Object?> _templateVariables(RuleEvalContext context, String? value) {
    final result = <String, Object?>{
      ...context.variables,
      'baseUrl': context.pack.meta.baseUrl,
      'value': ?value,
    };
    for (final entry in context.variables.entries) {
      if (!entry.key.startsWith('ctx.')) {
        result['ctx.${entry.key}'] = entry.value;
      }
    }
    result['ctx.baseUrl'] = context.pack.meta.baseUrl;
    result['ctx.pageUri'] = context.pageUri.toString();
    return result;
  }

  String _joinValue(Object? value) {
    if (value is List<Object?>) {
      return value.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).join(',');
    }
    return value?.toString() ?? '';
  }

  bool _hasValue(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is String) {
      return value.isNotEmpty;
    }
    if (value is List<Object?>) {
      return value.isNotEmpty;
    }
    return true;
  }
}
