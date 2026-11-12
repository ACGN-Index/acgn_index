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
    'login',
    'capabilities',
  };
  static const Set<String> _metaKeys = <String>{
    'id',
    'name',
    'type',
    'baseUrl',
    'version',
    'author',
    'lang',
    'description',
    'adult',
    'notice',
    'allowedHosts',
  };
  static const Set<String> _requestKeys = <String>{'headers', 'timeoutMs', 'encoding', 'retry'};
  static const Set<String> _loginKeys = <String>{
    'mode',
    'url',
    'successUrlPattern',
    'cookieNames',
    'headers',
  };
  static const Set<String> _capabilityBaseKeys = <String>{
    'url',
    'method',
    'body',
    'headers',
    'list',
    'fields',
  };
  static const Map<RuleCapability, Set<String>> _capabilityExtraKeys =
      <RuleCapability, Set<String>>{
        RuleCapability.search: <String>{'mode', 'index', 'filter', 'pageSize', 'pagination'},
        RuleCapability.detail: <String>{},
        RuleCapability.toc: <String>{'fanOutFrom', 'group'},
        RuleCapability.content: <String>{'mode', 'resolve'},
      };
  static const Set<String> _indexKeys = <String>{'url', 'method', 'body', 'list', 'ttlSeconds'};
  static const Set<String> _paginationKeys = <String>{'totalItems', 'pageSize'};
  static const Set<String> _groupKeys = <String>{'id', 'title'};
  static const Set<String> _resolveKeys = <String>{'url', 'method', 'body', 'fields'};
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
    'multiple',
    'template',
    'prefix',
    'suffix',
    'absolute',
    'htmlToText',
    'default',
    'fallback',
    'items',
    'fields',
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
    _checkLogin(json, issues);
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

    if (!meta.containsKey('type')) {
      issues.add(const RuleIssue(path: 'meta.type', message: '缺少必填字段 type'));
    } else {
      final rawType = meta.stringOrNull('type');
      if (rawType == null) {
        issues.add(const RuleIssue(path: 'meta.type', message: 'type 必须是字符串'));
      } else if (MediaType.tryParse(rawType) == null) {
        issues.add(
          RuleIssue(
            path: 'meta.type',
            message:
                '未知内容类型 "$rawType"，可用值：'
                '${MediaType.values.map((type) => type.wireName).join(', ')}',
          ),
        );
      }
    }

    final adult = meta['adult'];
    if (adult != null && adult is! bool) {
      issues.add(const RuleIssue(path: 'meta.adult', message: 'adult 必须是布尔值'));
    }
    final notice = meta['notice'];
    if (notice != null && notice is! String) {
      issues.add(const RuleIssue(path: 'meta.notice', message: 'notice 必须是字符串'));
    }
    final allowedHosts = meta['allowedHosts'];
    if (allowedHosts != null) {
      if (allowedHosts is! List<Object?>) {
        issues.add(
          const RuleIssue(path: 'meta.allowedHosts', message: 'allowedHosts 必须是字符串数组'),
        );
      } else {
        for (var index = 0; index < allowedHosts.length; index++) {
          final host = allowedHosts[index];
          if (host is! String || host.trim().isEmpty) {
            issues.add(
              RuleIssue(
                path: 'meta.allowedHosts[$index]',
                message: 'allowedHosts 只能包含非空字符串',
              ),
            );
          }
        }
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
    final retry = request['retry'];
    if (retry != null && (retry is! int || retry < 0 || retry > 2)) {
      issues.add(const RuleIssue(path: 'request.retry', message: 'retry 必须是 0–2 的整数'));
    }
  }

  void _checkLogin(Map<String, Object?> json, List<RuleIssue> issues) {
    if (!json.containsKey('login')) {
      return;
    }
    final login = _asMap(json['login'], 'login', issues);
    if (login == null) {
      return;
    }
    _checkUnknownKeys(login, _loginKeys, 'login', issues);

    final rawMode = login.stringOrNull('mode');
    final mode = rawMode ?? 'webview';
    if (mode != 'webview' && mode != 'headers') {
      issues.add(
        RuleIssue(path: 'login.mode', message: 'mode 仅支持 webview / headers，实际为 $rawMode'),
      );
    }

    final url = login.stringOrNull('url');
    if (mode == 'webview' && (url == null || url.trim().isEmpty)) {
      issues.add(const RuleIssue(path: 'login.url', message: 'webview 登录必须声明 login.url'));
    }
    if (url != null && url.trim().isNotEmpty) {
      _checkLoginUrl(json, url, issues);
    }

    final pattern = login.stringOrNull('successUrlPattern');
    if (pattern != null && pattern.trim().isNotEmpty) {
      try {
        RegExp(pattern);
      } on FormatException {
        issues.add(
          const RuleIssue(path: 'login.successUrlPattern', message: 'successUrlPattern 不是合法正则'),
        );
      }
    }

    final cookieNames = login['cookieNames'];
    if (cookieNames != null) {
      if (cookieNames is! List<Object?>) {
        issues.add(
          const RuleIssue(path: 'login.cookieNames', message: 'cookieNames 必须是字符串数组'),
        );
      } else {
        for (var index = 0; index < cookieNames.length; index++) {
          final name = cookieNames[index];
          if (name is! String || name.trim().isEmpty) {
            issues.add(
              RuleIssue(
                path: 'login.cookieNames[$index]',
                message: 'cookieNames 只能包含非空字符串',
              ),
            );
          }
        }
      }
    }

    final headers = _asMap(login['headers'], 'login.headers', issues);
    if (headers != null) {
      for (final entry in headers.entries) {
        if (entry.value is! String) {
          issues.add(
            RuleIssue(path: 'login.headers.${entry.key}', message: '登录请求头必须是字符串'),
          );
        }
      }
    }
  }

  void _checkLoginUrl(Map<String, Object?> json, String url, List<RuleIssue> issues) {
    final meta = json['meta'];
    final rawBaseUrl = meta is Map<Object?, Object?> ? meta['baseUrl'] : null;
    final baseUrl = rawBaseUrl is String ? rawBaseUrl : '';
    final rendered = url.replaceAll('{{baseUrl}}', baseUrl);
    final parsed = Uri.tryParse(rendered);
    final base = Uri.tryParse(baseUrl);
    final resolved = parsed == null ? null : (parsed.hasScheme ? parsed : base?.resolveUri(parsed));
    if (resolved == null ||
        resolved.host.isEmpty ||
        (resolved.scheme != 'http' && resolved.scheme != 'https')) {
      issues.add(
        const RuleIssue(path: 'login.url', message: 'login.url 必须是 http(s) 地址或相对路径'),
      );
      return;
    }
    if (!_loginHostAllowed(json, resolved.host)) {
      issues.add(
        const RuleIssue(
          path: 'login.url',
          message: 'login.url 的主机必须属于 meta.baseUrl 或 meta.allowedHosts',
        ),
      );
    }
  }

  bool _loginHostAllowed(Map<String, Object?> json, String host) {
    final normalized = host.toLowerCase();
    final meta = json['meta'];
    if (meta is! Map<Object?, Object?>) {
      return false;
    }
    final rawBaseUrl = meta['baseUrl'];
    final baseHost = rawBaseUrl is String ? Uri.tryParse(rawBaseUrl)?.host.toLowerCase() ?? '' : '';
    if (baseHost.isNotEmpty && _matchesAllowedHost(normalized, baseHost)) {
      return true;
    }
    final allowedHosts = meta['allowedHosts'];
    if (allowedHosts is! List<Object?>) {
      return false;
    }
    for (final item in allowedHosts) {
      if (item is! String || item.trim().isEmpty) {
        continue;
      }
      final parsed = Uri.tryParse(item);
      final candidate = parsed != null && parsed.host.isNotEmpty
          ? parsed.host.toLowerCase()
          : item.toLowerCase();
      if (candidate.isNotEmpty && _matchesAllowedHost(normalized, candidate)) {
        return true;
      }
    }
    return false;
  }

  bool _matchesAllowedHost(String host, String allowed) =>
      host == allowed || host.endsWith('.$allowed');

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
      final capability = RuleCapability.tryParse(entry.key);
      if (capability == null) {
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
        _checkCapability(rule, path, capability, issues);
      }
    }
  }

  void _checkCapability(
    Map<String, Object?> rule,
    String path,
    RuleCapability? capability,
    List<RuleIssue> issues,
  ) {
    final knownKeys = <String>{
      ..._capabilityBaseKeys,
      ...?_capabilityExtraKeys[capability],
    };
    _checkUnknownKeys(rule, knownKeys, path, issues);

    final method = rule.stringOrNull('method');
    if (method != null && !_supportedMethods.contains(method.toUpperCase())) {
      issues.add(
        RuleIssue(path: '$path.method', message: 'method 仅支持 GET / POST，实际为 $method'),
      );
    }

    final headers = _asMap(rule['headers'], '$path.headers', issues);
    if (headers != null) {
      for (final entry in headers.entries) {
        if (entry.value is! String) {
          issues.add(RuleIssue(path: '$path.headers.${entry.key}', message: '请求头必须是字符串'));
        }
      }
    }

    switch (capability) {
      case RuleCapability.search:
        _checkSearchCapability(rule, path, issues);
      case RuleCapability.toc:
        _checkTocCapability(rule, path, issues);
      case RuleCapability.content:
        _checkContentCapability(rule, path, issues);
      case RuleCapability.detail:
      case null:
        _requireNonEmptyString(rule, 'url', '$path.url', issues);
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

  void _checkSearchCapability(
    Map<String, Object?> rule,
    String path,
    List<RuleIssue> issues,
  ) {
    final rawMode = rule.stringOrNull('mode');
    final mode = rawMode == null ? SearchMode.query : SearchMode.tryParse(rawMode);
    if (mode == null) {
      issues.add(
        RuleIssue(path: '$path.mode', message: 'mode 仅支持 query / index，实际为 $rawMode'),
      );
      return;
    }

    final index = _asMap(rule['index'], '$path.index', issues);
    if (mode == SearchMode.localIndex) {
      if (index == null) {
        issues.add(RuleIssue(path: '$path.index', message: 'index 模式必须声明 index 对象'));
      } else {
        _checkUnknownKeys(index, _indexKeys, '$path.index', issues);
        _requireNonEmptyString(index, 'url', '$path.index.url', issues);
        final indexList = _asMap(index['list'], '$path.index.list', issues);
        if (indexList == null) {
          issues.add(
            RuleIssue(path: '$path.index.list', message: 'index 模式必须声明列表选择器'),
          );
        } else {
          _checkField(indexList, '$path.index.list', issues);
        }
        final ttlSeconds = index['ttlSeconds'];
        if (ttlSeconds != null && (ttlSeconds is! int || ttlSeconds <= 0)) {
          issues.add(RuleIssue(path: '$path.index.ttlSeconds', message: 'ttlSeconds 必须是正整数'));
        }
      }
      if (!rule.containsKey('filter')) {
        issues.add(RuleIssue(path: '$path.filter', message: 'index 模式必须声明 filter 谓词'));
      }
    } else {
      _requireNonEmptyString(rule, 'url', '$path.url', issues);
      if (index != null) {
        issues.add(
          RuleIssue(
            path: '$path.index',
            message: '仅 index 模式使用 index 配置',
            severity: RuleIssueSeverity.warning,
          ),
        );
      }
    }

    final filter = _asMap(rule['filter'], '$path.filter', issues);
    if (filter != null) {
      _checkField(filter, '$path.filter', issues);
    }

    final pageSize = rule['pageSize'];
    if (pageSize != null && (pageSize is! int || pageSize <= 0)) {
      issues.add(RuleIssue(path: '$path.pageSize', message: 'pageSize 必须是正整数'));
    }

    final pagination = _asMap(rule['pagination'], '$path.pagination', issues);
    if (pagination != null) {
      _checkUnknownKeys(pagination, _paginationKeys, '$path.pagination', issues);
      final paginationSize = pagination['pageSize'];
      if (paginationSize != null && (paginationSize is! int || paginationSize <= 0)) {
        issues.add(
          RuleIssue(path: '$path.pagination.pageSize', message: 'pageSize 必须是正整数'),
        );
      }
      final totalItems = _asMap(
        pagination['totalItems'],
        '$path.pagination.totalItems',
        issues,
      );
      if (totalItems != null) {
        _checkField(totalItems, '$path.pagination.totalItems', issues);
      }
    }
  }

  void _checkTocCapability(Map<String, Object?> rule, String path, List<RuleIssue> issues) {
    final fanOutFrom = rule['fanOutFrom'];
    final hasFanOut = fanOutFrom is String && fanOutFrom.trim().isNotEmpty;
    if (fanOutFrom != null && !hasFanOut) {
      issues.add(RuleIssue(path: '$path.fanOutFrom', message: 'fanOutFrom 必须是非空字符串'));
    }

    final group = _asMap(rule['group'], '$path.group', issues);
    if (group != null) {
      _checkUnknownKeys(group, _groupKeys, '$path.group', issues);
      _requireNonEmptyString(group, 'id', '$path.group.id', issues);
      _requireNonEmptyString(group, 'title', '$path.group.title', issues);
      if (!hasFanOut) {
        issues.add(RuleIssue(path: '$path.group', message: 'group 必须与 fanOutFrom 一起使用'));
      }
    }

    final hasUrl = (rule.stringOrNull('url') ?? '').trim().isNotEmpty;
    final hasList = rule['list'] != null;
    if (!hasUrl && !hasFanOut) {
      issues.add(RuleIssue(path: '$path.url', message: '缺少必填字段 url'));
    } else if (!hasUrl && hasList) {
      issues.add(RuleIssue(path: '$path.url', message: '声明 list 时必须提供 url'));
    }
  }

  void _checkContentCapability(
    Map<String, Object?> rule,
    String path,
    List<RuleIssue> issues,
  ) {
    final mode = ContentMode.tryParse(rule.stringOrNull('mode') ?? '');
    // 视频源可以只由目录条目提供地址（`{{chapter.url}}`），此时不发请求。
    final rawFields = rule['fields'];
    final hasInlineVideoUrl =
        rawFields is Map<Object?, Object?> &&
        (rawFields.containsKey('url') || rawFields.containsKey('urls'));
    final url = rule.stringOrNull('url')?.trim() ?? '';
    final inlineVideo = mode == ContentMode.video && hasInlineVideoUrl;
    if (url.isEmpty && inlineVideo) {
      if (rule.containsKey('resolve')) {
        issues.add(
          RuleIssue(
            path: '$path.resolve',
            message: 'url 为空时不发请求，resolve 也不再可用',
          ),
        );
      }
    } else {
      _requireNonEmptyString(rule, 'url', '$path.url', issues);
    }
    if (!rule.containsKey('mode')) {
      issues.add(RuleIssue(path: '$path.mode', message: '缺少必填字段 mode'));
    } else {
      final rawMode = rule.stringOrNull('mode');
      if (rawMode == null || mode == null) {
        issues.add(
          RuleIssue(
            path: '$path.mode',
            message: 'mode 仅支持 video / images / text / file，实际为 ${rawMode ?? 'null'}',
          ),
        );
      }
    }

    final resolve = _asMap(rule['resolve'], '$path.resolve', issues);
    if (resolve != null) {
      _checkUnknownKeys(resolve, _resolveKeys, '$path.resolve', issues);
      _requireNonEmptyString(resolve, 'url', '$path.resolve.url', issues);
      final resolveFields = _asMap(resolve['fields'], '$path.resolve.fields', issues);
      if (resolveFields != null) {
        for (final entry in resolveFields.entries) {
          final fieldPath = '$path.resolve.fields.${entry.key}';
          final field = _asMap(entry.value, fieldPath, issues);
          if (field != null) {
            _checkField(field, fieldPath, issues);
          }
        }
      }
    }
  }

  void _checkField(Map<String, Object?> field, String path, List<RuleIssue> issues) {
    _checkUnknownKeys(field, _fieldKeys, path, issues);

    final declaredSources = <String>[];
    final primarySources = <String>[];
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
      if (key != 'js') {
        primarySources.add(key);
      }
    }

    if (field.containsKey('items')) {
      if (declaredSources.isNotEmpty) {
        issues.add(RuleIssue(path: path, message: 'items 不能与取值来源同时声明'));
      }
      final items = _asMap(field['items'], '$path.items', issues);
      if (items != null) {
        _checkField(items, '$path.items', issues);
      }
      final fields = _asMap(field['fields'], '$path.fields', issues);
      if (fields == null || fields.isEmpty) {
        issues.add(
          RuleIssue(
            path: '$path.fields',
            message: 'items 必须声明非空 fields',
            severity: RuleIssueSeverity.warning,
          ),
        );
      } else {
        for (final entry in fields.entries) {
          final fieldPath = '$path.fields.${entry.key}';
          final child = _asMap(entry.value, fieldPath, issues);
          if (child != null) {
            _checkField(child, fieldPath, issues);
          }
        }
      }
    } else {
      if (declaredSources.isEmpty) {
        issues.add(
          RuleIssue(
            path: path,
            message: '必须声明 selector / xpath / jsonPath / js / const 之一，或声明 items',
          ),
        );
      } else if (primarySources.length > 1) {
        issues.add(
          RuleIssue(
            path: path,
            message: '只能声明一种主取值来源（js 可作为后处理附加），当前声明了 ${declaredSources.join(', ')}',
          ),
        );
      }
      if (field.containsKey('fields')) {
        issues.add(RuleIssue(path: '$path.fields', message: 'fields 只能与 items 一起使用'));
      }
    }

    final fallback = _asMap(field['fallback'], '$path.fallback', issues);
    if (fallback != null) {
      _checkField(fallback, '$path.fallback', issues);
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
    for (final key in const <String>['absolute', 'html', 'multiple', 'htmlToText']) {
      final value = field[key];
      if (value != null && value is! bool) {
        issues.add(RuleIssue(path: '$path.$key', message: '$key 必须是布尔值'));
      }
    }
    final template = field['template'];
    if (template != null && template is! String) {
      issues.add(RuleIssue(path: '$path.template', message: 'template 必须是字符串'));
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
