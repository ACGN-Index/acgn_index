import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_document.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_request_builder.dart';

/// 搜索服务抽象，便于发现页聚合逻辑单测时替换。
abstract interface class RuleSearchService {
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1});
}

/// 执行规则包的 `search` 能力。
///
/// `query` 模式每次请求站点搜索接口；`localIndex` 模式拉取索引后本地过滤，
/// 并按 `index.ttlSeconds` 做内存缓存。
class RuleSearchPipeline implements RuleSearchService {
  RuleSearchPipeline({
    required this.httpClient,
    this.evaluator = const FieldEvaluator(),
    this.requestBuilder = const RuleRequestBuilder(),
  });

  final RuleHttpClient httpClient;
  final FieldEvaluator evaluator;
  final RuleRequestBuilder requestBuilder;
  final Map<String, _IndexCacheEntry> _indexCache = <String, _IndexCacheEntry>{};

  @override
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1}) async {
    final capability = pack.capabilities[RuleCapability.search];
    if (capability is! SearchCapabilityRule) {
      throw const UnsupportedCapabilityException('规则未声明 search 能力');
    }
    final pageNumber = page < 1 ? 1 : page;
    return switch (capability.mode) {
      SearchMode.query => _searchRemote(pack, capability, keyword: keyword, page: pageNumber),
      SearchMode.localIndex => _searchIndex(pack, capability, keyword: keyword, page: pageNumber),
    };
  }

  Future<SearchPage> _searchRemote(
    RulePack pack,
    SearchCapabilityRule capability, {
    required String keyword,
    required int page,
  }) async {
    final pageSize = capability.pageSize > 0 ? capability.pageSize : 20;
    final variables = _searchVariables(pack, keyword, page, pageSize);
    final document = await _fetch(
      requestBuilder.build(
        pack: pack,
        url: capability.url,
        method: capability.method,
        body: capability.body,
        headers: capability.headers,
        variables: variables,
      ),
    );
    final context = _documentContext(pack, document, variables);
    final entries = _entries(capability.list, context);
    final items = _mapEntries(capability.fields, entries, context, document.uri);
    final totalRule = capability.pagination?.totalItems;
    final totalItems = totalRule == null ? null : _asInt(evaluator.evaluate(totalRule, context));
    final paginationPageSize = capability.pagination?.pageSize ?? pageSize;
    final hasMore = totalItems != null
        ? page * paginationPageSize < totalItems
        : items.length >= pageSize;
    return SearchPage(items: items, totalItems: totalItems, hasMore: hasMore);
  }

  Future<SearchPage> _searchIndex(
    RulePack pack,
    SearchCapabilityRule capability, {
    required String keyword,
    required int page,
  }) async {
    final index = capability.index;
    if (index == null) {
      throw const RuleFormatException('search.mode=index 缺少 index 配置');
    }
    final pageSize = capability.pageSize > 0 ? capability.pageSize : 20;
    final variables = _searchVariables(pack, keyword, page, pageSize);
    final now = DateTime.now();
    var cached = _indexCache[pack.id];
    if (cached == null || !cached.expiresAt.isAfter(now)) {
      final document = await _fetch(
        requestBuilder.build(
          pack: pack,
          url: index.url,
          method: index.method,
          body: index.body,
          headers: capability.headers,
          variables: variables,
        ),
      );
      final context = _documentContext(pack, document, variables);
      final list = index.list;
      final entries = list == null
          ? const <Object?>[]
          : List<Object?>.unmodifiable(evaluator.resolveItems(list, context));
      final ttl = index.ttlSeconds > 0 ? index.ttlSeconds : 3600;
      cached = _IndexCacheEntry(
        document: document,
        entries: entries,
        expiresAt: now.add(Duration(seconds: ttl)),
      );
      _indexCache[pack.id] = cached;
    }
    final context = _documentContext(pack, cached.document, variables);
    var entries = cached.entries;
    final filter = capability.filter;
    if (keyword.trim().isNotEmpty && filter != null) {
      final normalizedKeyword = _normalizeKeyword(keyword);
      final filterContext = context.withVariables(<String, Object?>{
        'keyword': keyword,
        'keywordNormalized': normalizedKeyword,
        'ctx.keyword': keyword,
        'ctx.keywordNormalized': normalizedKeyword,
      });
      entries = entries
          .where((entry) => _isTruthy(evaluator.evaluate(filter, filterContext.withEntry(entry))))
          .toList(growable: false);
    }
    final total = entries.length;
    final start = (page - 1) * pageSize;
    final end = start + pageSize;
    final pageEntries = start >= total
        ? const <Object?>[]
        : entries.sublist(start, end > total ? total : end);
    final items = _mapEntries(capability.fields, pageEntries, context, context.pageUri);
    return SearchPage(items: items, totalItems: total, hasMore: end < total);
  }

  Future<RuleDocument> _fetch(RuleHttpRequest request) async {
    final response = await httpClient.send(request);
    if (!response.isSuccess) {
      throw NetworkException('请求失败：HTTP ${response.statusCode}');
    }
    return RuleDocument.parse(
      response.body,
      uri: response.uri,
      headers: response.headers,
    );
  }

  RuleEvalContext _documentContext(
    RulePack pack,
    RuleDocument document,
    Map<String, Object?> variables,
  ) => RuleEvalContext(
    pack: pack,
    pageUri: document.uri,
    json: document.json,
    htmlDocument: document.htmlDocument,
    xmlNode: document.xmlDocument,
    variables: variables,
  );

  List<Object?> _entries(FieldRule? list, RuleEvalContext context) {
    if (list == null) {
      throw const RuleFormatException('search 缺少 list 选择器');
    }
    return evaluator.resolveItems(list, context);
  }

  List<SearchResult> _mapEntries(
    Map<String, FieldRule> fields,
    List<Object?> entries,
    RuleEvalContext pageContext,
    Uri pageUri,
  ) {
    final results = <SearchResult>[];
    for (final entry in entries) {
      final entryContext = pageContext.withEntry(entry);
      final values = <String, Object?>{};
      for (final field in fields.entries) {
        values[field.key] = evaluator.evaluate(field.value, entryContext);
      }
      final id = _scalar(values['id']);
      final title = _scalar(values['title']);
      if (id == null || title == null) {
        continue;
      }
      results.add(
        SearchResult(
          id: id,
          title: title,
          cover: _scalar(values['cover']),
          author: _scalar(values['author']),
          subtitle: _scalar(values['subtitle']),
          url: _absoluteUrl(pageUri, _scalar(values['url'])),
          extra: values,
        ),
      );
    }
    return results;
  }

  String? _scalar(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is List<Object?>) {
      for (final item in value) {
        final text = item?.toString().trim() ?? '';
        if (text.isNotEmpty) {
          return text;
        }
      }
      return null;
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  String? _absoluteUrl(Uri pageUri, String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.hasScheme) {
      return value;
    }
    return pageUri.resolve(value).toString();
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim());
    }
    if (value is List<Object?> && value.isNotEmpty) {
      return _asInt(value.first);
    }
    return null;
  }

  bool _isTruthy(Object? value) {
    if (value == null) {
      return false;
    }
    if (value is bool) {
      return value;
    }
    if (value is num) {
      return value != 0;
    }
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      return normalized.isNotEmpty && normalized != 'false' && normalized != '0';
    }
    if (value is List<Object?>) {
      return value.isNotEmpty;
    }
    return true;
  }

  Map<String, Object?> _searchVariables(
    RulePack pack,
    String keyword,
    int page,
    int pageSize,
  ) {
    final normalizedKeyword = _normalizeKeyword(keyword);
    return <String, Object?>{
      'baseUrl': pack.meta.baseUrl,
      'key': Uri.encodeQueryComponent(keyword),
      'keywordNormalized': normalizedKeyword,
      'ctx.keyword': keyword,
      'ctx.keywordNormalized': normalizedKeyword,
      'page': page,
      'pageSize': pageSize,
      'offset': (page - 1) * pageSize,
    };
  }
}

final RegExp _keywordPunctuation = RegExp(
  r'[\s\-_.,，。！？!?、/\\:：;；\x27\x22()（）\[\]【】<>《》]',
);

String _normalizeKeyword(String keyword) =>
    keyword.toLowerCase().replaceAll(_keywordPunctuation, '');

class _IndexCacheEntry {
  const _IndexCacheEntry({
    required this.document,
    required this.entries,
    required this.expiresAt,
  });

  final RuleDocument document;
  final List<Object?> entries;
  final DateTime expiresAt;
}
