import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/utils/json_utils.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/validation_result.dart';

/// 对规则包原始 JSON 做结构与语义校验。
///
/// 校验发生在解析之前，因此可以一次性收集全部问题而不中断，供规则编辑器逐条高亮。
/// 约定：[ValidationResult.isValid] 为 true 才可以交给 `RulePack.fromJson`。
class RulePackValidator {
  const RulePackValidator({
    this.supportedSchemaVersions = const <int>{kSupportedSchemaVersion},
  });

  final Set<int> supportedSchemaVersions;

  static const Set<String> _topLevelKeys = <String>{
    'schemaVersion',
    'meta',
    'request',
    'capabilities',
  };
  static const Set<String> _metaKeys = <String>{
    'id',
    'name',
    'baseUrl',
    'version',
    'author',
    'lang',
    'description',
    'types',
  };
  static const Set<String> _requestKeys = <String>{'headers', 'timeoutMs', 'encoding'};
  static const Set<String> _capabilityKeys = <String>{'url', 'method', 'body', 'list', 'fields'};
  static const Set<String> _fieldKeys = <String>{
    'selector',
    'xpath',
    'jsonPath',
    'js',
    'const',
    'attr',
    'html',
    'regex',
    'group',
    'prefix',
    'suffix',
    'absolute',
    'default',
  };
  static const Set<String> _fieldSourceKeys = <String>{
    'selector',
    'xpath',
    'jsonPath',
    'js',
    'const',
  };
  static const Set<String> _supportedMethods = <String>{'GET', 'POST'};
  static const Set<String> _requiredMetaKeys = <String>{'id', 'name', 'baseUrl', 'version'};

  ValidationResult validate(Map<String, Object?> json) {
    final issues = <RuleIssue>[];
    _checkUnknownKeys(json, _topLevelKeys, '', issues);
    _checkSchemaVersion(json, issues);
    _checkMeta(json, issues);
    _checkRequest(json, issues);
    _checkCapabilities(json, issues);
    return ValidationResult(issues);
  }

  void _checkSchemaVersion(Map<String, Object?> json, List<RuleIssue> issues) {
    final value = json['schemaVersion'];
    if (value == null) {
      issues.add(const RuleIssue(path: 'schemaVersion', message: '缺少 schemaVersion 字段'));
      return;
    }
    if (value is! int) {
      issues.add(const RuleIssue(path: 'schemaVersion', message: 'schemaVersion 必须是整数'));
      return;
    }
    if (!supportedSchemaVersions.contains(value)) {
      issues.add(
        RuleIssue(
          path: 'schemaVersion',
          message: '不支持的规则版本 $value，当前支持 ${supportedSchemaVersions.join(', ')}',
        ),
      );
    }
  }

  void _checkMeta(Map<String, Object?> json, List<RuleIssue> issues) {
    final meta = _asMap(json['meta'], 'meta', issues);
    if (meta == null) {
      if (!json.containsKey('meta')) {
        issues.add(const RuleIssue(path: 'meta', message: '缺少 meta 字段'));
      }
      return;
    }
    _checkUnknownKeys(meta, _metaKeys, 'meta', issues);
    for (final key in _requiredMetaKeys) {
      _requireNonEmptyString(meta, key, 'meta.$key', issues);
    }

    final baseUrl = meta.stringOrNull('baseUrl');
    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      final uri = Uri.tryParse(baseUrl);
      final isValid =
          uri != null && uri.host.isNotEmpty && (uri.scheme == 'http' || uri.scheme == 'https');
      if (!isValid) {
        issues.add(
          const RuleIssue(path: 'meta.baseUrl', message: 'baseUrl 必须是绝对 http(s) 地址'),
        );
      }
    }

    final typesValue = meta['types'];
    if (typesValue == null) {
      issues.add(
        const RuleIssue(
          path: 'meta.types',
          message: '未声明 types，该规则不会出现在任何内容分类中',
          severity: RuleIssueSeverity.warning,
        ),
      );
      return;
    }
    final types = typesValue is List<Object?> ? typesValue : const <Object?>[];
    if (types.isEmpty) {
      issues.add(
        const RuleIssue(
          path: 'meta.types',
          message: 'types 为空，该规则不会出现在任何内容分类中',
          severity: RuleIssueSeverity.warning,
        ),
      );
    }
    for (final item in types) {
      if (item is! String || MediaType.tryParse(item) == null) {
        issues.add(
          RuleIssue(
            path: 'meta.types',
            message: '未知内容类型 "$item"，可用值：${MediaType.values.map((t) => t.wireName).join(', ')}',
          ),
        );
      }
    }
  }

  void _checkRequest(Map<String, Object?> json, List<RuleIssue> issues) {
    final request = _asMap(json['request'], 'request', issues);
    if (request == null) {
      return;
    }
    _checkUnknownKeys(request, _requestKeys, 'request', issues);
    final timeoutMs = request['timeoutMs'];
    if (timeoutMs != null && (timeoutMs is! int || timeoutMs <= 0)) {
      issues.add(const RuleIssue(path: 'request.timeoutMs', message: 'timeoutMs 必须是正整数'));
    }
    final headers = request['headers'];
    if (headers != null && headers is! Map<Object?, Object?>) {
      issues.add(const RuleIssue(path: 'request.headers', message: 'headers 必须是对象'));
    }
  }

  void _checkCapabilities(Map<String, Object?> json, List<RuleIssue> issues) {
    final capabilities = _asMap(json['capabilities'], 'capabilities', issues);
    if (capabilities == null) {
      if (!json.containsKey('capabilities')) {
        issues.add(const RuleIssue(path: 'capabilities', message: '缺少 capabilities 字段'));
      }
      return;
    }
    if (capabilities.isEmpty) {
      issues.add(const RuleIssue(path: 'capabilities', message: '至少要声明一种能力'));
      return;
    }
    for (final entry in capabilities.entries) {
      final path = 'capabilities.${entry.key}';
      if (RuleCapability.tryParse(entry.key) == null) {
        issues.add(
          RuleIssue(
            path: path,
            message:
                '未知能力 "${entry.key}"，可用值：'
                '${RuleCapability.values.map((c) => c.wireName).join(', ')}',
            severity: RuleIssueSeverity.warning,
          ),
        );
      }
      final rule = _asMap(entry.value, path, issues);
      if (rule != null) {
        _checkCapability(rule, path, issues);
      }
    }
  }

  void _checkCapability(Map<String, Object?> rule, String path, List<RuleIssue> issues) {
    _checkUnknownKeys(rule, _capabilityKeys, path, issues);
    _requireNonEmptyString(rule, 'url', '$path.url', issues);

    final method = rule.stringOrNull('method');
    if (method != null && !_supportedMethods.contains(method.toUpperCase())) {
      issues.add(
        RuleIssue(path: '$path.method', message: 'method 仅支持 GET / POST，实际为 $method'),
      );
    }

    final list = _asMap(rule['list'], '$path.list', issues);
    if (list != null) {
      _checkField(list, '$path.list', issues);
    }

    final fields = _asMap(rule['fields'], '$path.fields', issues);
    if (fields == null) {
      return;
    }
    if (fields.isEmpty) {
      issues.add(
        RuleIssue(
          path: '$path.fields',
          message: 'fields 为空，该能力不会产出任何数据',
          severity: RuleIssueSeverity.warning,
        ),
      );
    }
    for (final entry in fields.entries) {
      final fieldPath = '$path.fields.${entry.key}';
      final field = _asMap(entry.value, fieldPath, issues);
      if (field != null) {
        _checkField(field, fieldPath, issues);
      }
    }
  }

  void _checkField(Map<String, Object?> field, String path, List<RuleIssue> issues) {
    _checkUnknownKeys(field, _fieldKeys, path, issues);

    final declaredSources = <String>[];
    for (final key in _fieldSourceKeys) {
      final value = field[key];
      if (value == null) {
        continue;
      }
      if (value is! String || value.isEmpty) {
        issues.add(RuleIssue(path: '$path.$key', message: '$key 必须是非空字符串'));
        continue;
      }
      declaredSources.add(key);
    }
    if (declaredSources.isEmpty) {
      issues.add(
        RuleIssue(
          path: path,
          message: '必须声明 selector / xpath / jsonPath / js / const 之一',
        ),
      );
    } else if (declaredSources.length > 1) {
      issues.add(
        RuleIssue(
          path: path,
          message: '只能声明一种取值来源，当前声明了 ${declaredSources.join(', ')}',
        ),
      );
    }

    final regex = field.stringOrNull('regex');
    if (regex != null) {
      try {
        RegExp(regex);
      } on FormatException catch (error) {
        issues.add(
          RuleIssue(path: '$path.regex', message: '不是合法的正则表达式：${error.message}'),
        );
      }
    }

    final group = field['group'];
    if (group != null && (group is! int || group < 0)) {
      issues.add(RuleIssue(path: '$path.group', message: 'group 必须是非负整数'));
    }
    final absolute = field['absolute'];
    if (absolute != null && absolute is! bool) {
      issues.add(RuleIssue(path: '$path.absolute', message: 'absolute 必须是布尔值'));
    }
    final extractHtml = field['html'];
    if (extractHtml != null && extractHtml is! bool) {
      issues.add(RuleIssue(path: '$path.html', message: 'html 必须是布尔值'));
    }
  }

  void _requireNonEmptyString(
    Map<String, Object?> json,
    String key,
    String path,
    List<RuleIssue> issues,
  ) {
    if (!json.containsKey(key)) {
      issues.add(RuleIssue(path: path, message: '缺少必填字段 $key'));
      return;
    }
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      issues.add(RuleIssue(path: path, message: '$key 必须是非空字符串'));
    }
  }

  void _checkUnknownKeys(
    Map<String, Object?> json,
    Set<String> knownKeys,
    String path,
    List<RuleIssue> issues,
  ) {
    for (final key in json.keys) {
      if (knownKeys.contains(key)) {
        continue;
      }
      issues.add(
        RuleIssue(
          path: path.isEmpty ? key : '$path.$key',
          message: '未知字段 "$key"，当前版本会忽略它',
          severity: RuleIssueSeverity.warning,
        ),
      );
    }
  }

  Map<String, Object?>? _asMap(Object? value, String path, List<RuleIssue> issues) {
    if (value == null) {
      return null;
    }
    try {
      return asJsonMap(value, path: path);
    } on AppException catch (error) {
      issues.add(RuleIssue(path: path, message: error.message));
      return null;
    }
  }
}
