import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/core/utils/json_utils.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';

/// 当前代码实现支持的规则 schema 版本。
///
/// 升级规则时：新增字段保持向后兼容 → 版本号不变；破坏性变更 → 版本号 +1，
/// 并在 `docs/rule-spec.md` 的"版本演进"章节登记迁移方式。
const int kSupportedSchemaVersion = 1;

/// 请求层默认值，可被单个规则包覆盖。
class RequestRule {
  const RequestRule({
    this.headers = const <String, String>{},
    this.timeoutMs = 15000,
    this.encoding = 'utf-8',
    this.retry = 0,
  });

  factory RequestRule.fromJson(Map<String, Object?> json) => RequestRule(
    headers: json.stringMapOrNull('headers') ?? const <String, String>{},
    timeoutMs: json.intOrNull('timeoutMs') ?? 15000,
    encoding: json.stringOrNull('encoding') ?? 'utf-8',
    retry: json.intOrNull('retry') ?? 0,
  );

  final Map<String, String> headers;
  final int timeoutMs;
  final String encoding;

  /// 网络错误后的重试次数，0–2。
  final int retry;

  Duration get timeout => Duration(milliseconds: timeoutMs);

  Map<String, Object?> toJson() => <String, Object?>{
    'headers': headers,
    'timeoutMs': timeoutMs,
    'encoding': encoding,
    'retry': retry,
  };
}

/// 规则元信息。`id` 是规则源的唯一标识，一经发布不应修改。
///
/// 一个规则包只服务一类内容（[type]）。
class RuleMeta {
  const RuleMeta({
    required this.id,
    required this.name,
    required this.type,
    required this.baseUrl,
    required this.version,
    required this.author,
    required this.lang,
    this.description = '',
    this.adult = false,
    this.notice = '',
    this.allowedHosts = const <String>[],
  });

  factory RuleMeta.fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json.stringOrNull(key);
      if (value == null || value.trim().isEmpty) {
        throw RuleFormatException('meta.$key 不能为空');
      }
      return value;
    }

    final rawType = json.stringOrNull('type');
    final type = MediaType.tryParse(rawType);
    if (type == null) {
      throw RuleFormatException('meta.type 必须是 anime / comic / novel，实际为 ${rawType ?? 'null'}');
    }
    return RuleMeta(
      id: required('id'),
      name: required('name'),
      type: type,
      baseUrl: required('baseUrl'),
      version: required('version'),
      author: json.stringOrNull('author') ?? '',
      lang: json.stringOrNull('lang') ?? 'zh',
      description: json.stringOrNull('description') ?? '',
      adult: json.boolOrNull('adult') ?? false,
      notice: json.stringOrNull('notice') ?? '',
      allowedHosts: (json.listOrNull('allowedHosts') ?? const <Object?>[])
          .whereType<String>()
          .toList(growable: false),
    );
  }

  final String id;
  final String name;
  final MediaType type;
  final String baseUrl;
  final String version;
  final String author;

  /// 规则面向的内容语言，如 `zh`、`ja`、`en`。
  final String lang;

  final String description;

  /// 是否面向成人内容，发现页据此过滤。
  final bool adult;

  /// 来源与合规说明，内置规则集使用。
  final String notice;

  /// 除 `baseUrl` 之外允许请求的主机，用于索引与下载跨域的场景。
  final List<String> allowedHosts;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'type': type.wireName,
    'baseUrl': baseUrl,
    'version': version,
    'author': author,
    'lang': lang,
    if (description.isNotEmpty) 'description': description,
    if (adult) 'adult': true,
    if (notice.isNotEmpty) 'notice': notice,
    if (allowedHosts.isNotEmpty) 'allowedHosts': allowedHosts,
  };
}

/// 一个数据源的可序列化描述，是规则的唯一运行时形态。
///
/// 解析前请先用 `RulePackValidator` 校验原始 JSON：`fromJson` 只保证结构可解析，
/// 不保证语义合法。
class RulePack {
  const RulePack({
    required this.schemaVersion,
    required this.meta,
    this.request = const RequestRule(),
    this.capabilities = const <RuleCapability, CapabilityRule>{},
  });

  factory RulePack.fromJson(Map<String, Object?> json) {
    final schemaVersion = json.intOrNull('schemaVersion');
    if (schemaVersion == null) {
      throw const RuleFormatException('缺少 schemaVersion 字段');
    }
    if (schemaVersion != kSupportedSchemaVersion) {
      throw RuleFormatException(
        '不支持的规则版本 $schemaVersion，当前支持 $kSupportedSchemaVersion；请重新导入或升级规则',
      );
    }
    final metaJson = json.mapOrNull('meta');
    if (metaJson == null) {
      throw const RuleFormatException('缺少 meta 字段');
    }
    final capabilitiesJson = json.mapOrNull('capabilities');
    final capabilities = <RuleCapability, CapabilityRule>{};
    if (capabilitiesJson != null) {
      for (final entry in capabilitiesJson.entries) {
        final capability = RuleCapability.tryParse(entry.key);
        if (capability == null) {
          throw RuleFormatException('未知能力: ${entry.key}');
        }
        capabilities[capability] = CapabilityRule.fromJson(
          capability,
          asJsonMap(entry.value, path: 'capabilities.${entry.key}'),
        );
      }
    }
    final requestJson = json.mapOrNull('request');
    return RulePack(
      schemaVersion: schemaVersion,
      meta: RuleMeta.fromJson(metaJson),
      request: requestJson == null ? const RequestRule() : RequestRule.fromJson(requestJson),
      capabilities: capabilities,
    );
  }

  /// 从规则文件内容解析。JSON 语法错误同样转成 [RuleFormatException]，
  /// 让调用方只需处理一种失败类型。
  static RulePack parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw RuleFormatException('规则文件不是合法 JSON：${error.message}');
    }
    return RulePack.fromJson(asJsonMap(decoded, path: 'rulePack'));
  }

  final int schemaVersion;
  final RuleMeta meta;
  final RequestRule request;
  final Map<RuleCapability, CapabilityRule> capabilities;

  String get id => meta.id;

  MediaType get type => meta.type;

  bool supports(RuleCapability capability) => capabilities.containsKey(capability);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'meta': meta.toJson(),
    'request': request.toJson(),
    'capabilities': <String, Object?>{
      for (final entry in capabilities.entries) entry.key.wireName: entry.value.toJson(),
    },
  };
}
