import 'package:acgn_index/core/errors/app_exception.dart';
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

/// 搜索取值方式：远程关键词，或拉取索引后本地过滤。
enum SearchMode {
  query('query'),
  localIndex('index');

  const SearchMode(this.wireName);

  final String wireName;

  static SearchMode? tryParse(String? value) =>
      values.where((mode) => mode.wireName == value).firstOrNull;
}

/// `content` 的产出形态，由内容类型决定。
enum ContentMode {
  video('video'),
  images('images'),
  text('text'),
  file('file');

  const ContentMode(this.wireName);

  final String wireName;

  static ContentMode? tryParse(String? value) =>
      values.where((mode) => mode.wireName == value).firstOrNull;
}

/// 一种能力的公共部分：请求模板 + 列表选择器 + 字段提取规则。
///
/// [url] 与 [body] 支持模板变量：`{{baseUrl}}`、`{{key}}`、`{{page}}`、
/// `{{pageSize}}`、`{{offset}}`、`{{keywordNormalized}}`、`{{id}}`、`{{url}}`、
/// `{{chapter.id}}`、`{{chapter.url}}`、`{{chapter.extra.*}}`、`{{group.*}}`、
/// `{{resolve.*}}`。
sealed class CapabilityRule {
  const CapabilityRule({
    required this.url,
    this.method = 'GET',
    this.body,
    this.headers = const <String, String>{},
    this.list,
    this.fields = const <String, FieldRule>{},
  });

  factory CapabilityRule.fromJson(RuleCapability capability, Map<String, Object?> json) {
    final common = _CommonFields.fromJson(json);
    return switch (capability) {
      RuleCapability.search => SearchCapabilityRule._(common, json),
      RuleCapability.detail => DetailCapabilityRule._(common),
      RuleCapability.toc => TocCapabilityRule._(common, json),
      RuleCapability.content => ContentCapabilityRule._(common, json),
    };
  }

  final String url;
  final String method;
  final String? body;

  /// 该能力请求附带的默认请求头，会与规则包级请求头合并。
  final Map<String, String> headers;

  /// 列表页的条目选择器（搜索结果的每一项、目录的每一话）。
  final FieldRule? list;

  /// 从条目/详情页提取的字段，键名由能力语义约定（如 `id`、`title`、`cover`）。
  final Map<String, FieldRule> fields;

  Map<String, Object?> toJson();

  Map<String, Object?> _commonJson() => <String, Object?>{
    'url': url,
    'method': method,
    if (body != null) 'body': body,
    if (headers.isNotEmpty) 'headers': headers,
    if (list != null) 'list': list!.toJson(),
    if (fields.isNotEmpty)
      'fields': <String, Object?>{
        for (final entry in fields.entries) entry.key: entry.value.toJson(),
      },
  };
}

/// 搜索能力：远程关键词（`query`）或索引本地过滤（`index`）。
final class SearchCapabilityRule extends CapabilityRule {
  const SearchCapabilityRule({
    required super.url,
    super.method,
    super.body,
    super.headers,
    super.list,
    super.fields,
    this.mode = SearchMode.query,
    this.index,
    this.filter,
    this.pageSize = 20,
    this.pagination,
  });

  SearchCapabilityRule._(_CommonFields common, Map<String, Object?> json)
    : this(
        url: common.url,
        method: common.method,
        body: common.body,
        headers: common.headers,
        list: common.list,
        fields: common.fields,
        mode: _searchMode(json),
        index: _mapOrNull(json, 'index', SearchIndexRule.fromJson),
        filter: _fieldOrNull(json, 'filter'),
        pageSize: json.intOrNull('pageSize') ?? 20,
        pagination: _mapOrNull(json, 'pagination', SearchPagination.fromJson),
      );

  final SearchMode mode;

  /// `mode == index` 时的索引拉取配置。
  final SearchIndexRule? index;

  /// 索引模式的匹配谓词，`value` 为条目、`ctx.keyword` 为关键词。
  final FieldRule? filter;

  final int pageSize;
  final SearchPagination? pagination;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._commonJson(),
    'mode': mode.wireName,
    if (index != null) 'index': index!.toJson(),
    if (filter != null) 'filter': filter!.toJson(),
    'pageSize': pageSize,
    if (pagination != null) 'pagination': pagination!.toJson(),
  };
}

/// 详情能力：单一作品的字段提取。
final class DetailCapabilityRule extends CapabilityRule {
  const DetailCapabilityRule({
    required super.url,
    super.method,
    super.body,
    super.headers,
    super.list,
    super.fields,
  });

  DetailCapabilityRule._(_CommonFields common)
    : this(
        url: common.url,
        method: common.method,
        body: common.body,
        headers: common.headers,
        list: common.list,
        fields: common.fields,
      );

  @override
  Map<String, Object?> toJson() => _commonJson();
}

/// 目录能力：平铺目录，或按 [fanOutFrom] 指向的 detail 多值字段逐组请求。
final class TocCapabilityRule extends CapabilityRule {
  const TocCapabilityRule({
    required super.url,
    super.method,
    super.body,
    super.headers,
    super.list,
    super.fields,
    this.fanOutFrom,
    this.group,
  });

  TocCapabilityRule._(_CommonFields common, Map<String, Object?> json)
    : this(
        url: common.url,
        method: common.method,
        body: common.body,
        headers: common.headers,
        list: common.list,
        fields: common.fields,
        fanOutFrom: json.stringOrNull('fanOutFrom'),
        group: _mapOrNull(json, 'group', TocGroupRule.fromJson),
      );

  /// 例如 `detail.volumes`：按该字段的每个条目发起一次目录请求。
  final String? fanOutFrom;

  /// `fanOutFrom` 条目中哪两个键作为分组 id 与标题。
  final TocGroupRule? group;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._commonJson(),
    if (fanOutFrom != null) 'fanOutFrom': fanOutFrom,
    if (group != null) 'group': group!.toJson(),
  };
}

/// 正文能力：按 [mode] 产出视频源、漫画图片、小说段落或文件。
final class ContentCapabilityRule extends CapabilityRule {
  const ContentCapabilityRule({
    required super.url,
    super.method,
    super.body,
    super.headers,
    super.list,
    super.fields,
    this.mode,
    this.resolve,
  });

  ContentCapabilityRule._(_CommonFields common, Map<String, Object?> json)
    : this(
        url: common.url,
        method: common.method,
        body: common.body,
        headers: common.headers,
        list: common.list,
        fields: common.fields,
        mode: ContentMode.tryParse(json.stringOrNull('mode')),
        resolve: _mapOrNull(json, 'resolve', ResolveRule.fromJson),
      );

  /// 必填，但允许为空以便校验器给出可读错误。
  final ContentMode? mode;

  /// 可选的第二段请求，其字段以 `{{resolve.*}}` 注入。
  final ResolveRule? resolve;

  @override
  Map<String, Object?> toJson() => <String, Object?>{
    ..._commonJson(),
    if (mode != null) 'mode': mode!.wireName,
    if (resolve != null) 'resolve': resolve!.toJson(),
  };
}

/// 索引拉取配置（`search.mode == index`）。
class SearchIndexRule {
  const SearchIndexRule({
    required this.url,
    this.method = 'GET',
    this.body,
    this.list,
    this.ttlSeconds = 3600,
  });

  factory SearchIndexRule.fromJson(Map<String, Object?> json) => SearchIndexRule(
    url: json.stringOrNull('url') ?? '',
    method: (json.stringOrNull('method') ?? 'GET').toUpperCase(),
    body: json.stringOrNull('body'),
    list: _fieldOrNull(json, 'list'),
    ttlSeconds: json.intOrNull('ttlSeconds') ?? 3600,
  );

  final String url;
  final String method;
  final String? body;
  final FieldRule? list;
  final int ttlSeconds;

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'method': method,
    if (body != null) 'body': body,
    if (list != null) 'list': list!.toJson(),
    'ttlSeconds': ttlSeconds,
  };
}

/// 远程搜索的分页信息，用于计算 `hasMore`。
class SearchPagination {
  const SearchPagination({this.totalItems, this.pageSize = 20});

  factory SearchPagination.fromJson(Map<String, Object?> json) => SearchPagination(
    totalItems: _fieldOrNull(json, 'totalItems'),
    pageSize: json.intOrNull('pageSize') ?? 20,
  );

  final FieldRule? totalItems;
  final int pageSize;

  Map<String, Object?> toJson() => <String, Object?>{
    if (totalItems != null) 'totalItems': totalItems!.toJson(),
    'pageSize': pageSize,
  };
}

/// `toc.fanOutFrom` 条目到「分组 id / 标题」的映射。
class TocGroupRule {
  const TocGroupRule({required this.idField, required this.titleField});

  factory TocGroupRule.fromJson(Map<String, Object?> json) => TocGroupRule(
    idField: json.stringOrNull('id') ?? '',
    titleField: json.stringOrNull('title') ?? '',
  );

  final String idField;
  final String titleField;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': idField,
    'title': titleField,
  };
}

/// `content.resolve` 的二段请求。
class ResolveRule {
  const ResolveRule({
    required this.url,
    this.method = 'GET',
    this.body,
    this.fields = const <String, FieldRule>{},
  });

  factory ResolveRule.fromJson(Map<String, Object?> json) => ResolveRule(
    url: json.stringOrNull('url') ?? '',
    method: (json.stringOrNull('method') ?? 'GET').toUpperCase(),
    body: json.stringOrNull('body'),
    fields: _fieldsFromJson(json),
  );

  final String url;
  final String method;
  final String? body;
  final Map<String, FieldRule> fields;

  Map<String, Object?> toJson() => <String, Object?>{
    'url': url,
    'method': method,
    if (body != null) 'body': body,
    if (fields.isNotEmpty)
      'fields': <String, Object?>{
        for (final entry in fields.entries) entry.key: entry.value.toJson(),
      },
  };
}

/// 各能力共用的字段，避免四个子类重复解析。
class _CommonFields {
  const _CommonFields({
    required this.url,
    required this.method,
    required this.body,
    required this.headers,
    required this.list,
    required this.fields,
  });

  factory _CommonFields.fromJson(Map<String, Object?> json) => _CommonFields(
    url: json.stringOrNull('url') ?? '',
    method: (json.stringOrNull('method') ?? 'GET').toUpperCase(),
    body: json.stringOrNull('body'),
    headers: json.stringMapOrNull('headers') ?? const <String, String>{},
    list: _fieldOrNull(json, 'list'),
    fields: _fieldsFromJson(json),
  );

  final String url;
  final String method;
  final String? body;
  final Map<String, String> headers;
  final FieldRule? list;
  final Map<String, FieldRule> fields;
}

SearchMode _searchMode(Map<String, Object?> json) {
  final raw = json.stringOrNull('mode');
  if (raw == null) {
    return SearchMode.query;
  }
  final mode = SearchMode.tryParse(raw);
  if (mode == null) {
    throw RuleFormatException('search.mode 仅支持 query / index，实际为 $raw');
  }
  return mode;
}

FieldRule? _fieldOrNull(Map<String, Object?> json, String key) {
  final value = json.mapOrNull(key);
  return value == null ? null : FieldRule.fromJson(value);
}

Map<String, FieldRule> _fieldsFromJson(Map<String, Object?> json) {
  final fieldsJson = json.mapOrNull('fields') ?? const <String, Object?>{};
  return <String, FieldRule>{
    for (final entry in fieldsJson.entries)
      entry.key: FieldRule.fromJson(asJsonMap(entry.value, path: 'fields.${entry.key}')),
  };
}

T? _mapOrNull<T>(Map<String, Object?> json, String key, T Function(Map<String, Object?>) parse) {
  final value = json.mapOrNull(key);
  return value == null ? null : parse(value);
}
