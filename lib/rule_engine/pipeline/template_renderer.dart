import 'package:acgn_index/core/errors/app_exception.dart';

final RegExp _templatePattern = RegExp(r'\{\{\s*([A-Za-z0-9_.]+)\s*\}\}');

/// 渲染 `{{name}}` 模板；未声明的变量视为规则错误。
String renderTemplate(String template, Map<String, Object?> variables) {
  return template.replaceAllMapped(_templatePattern, (match) {
    final key = match.group(1)!;
    if (!variables.containsKey(key)) {
      throw RuleFormatException('模板变量 {{$key}} 未声明');
    }
    return variables[key]?.toString() ?? '';
  });
}

/// 模板中是否包含变量占位符。
bool hasTemplateVariable(String value) => _templatePattern.hasMatch(value);
