import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_fetch.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_request_builder.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_values.dart';

/// 目录服务抽象，便于详情页测试替换。
abstract interface class RuleTocService {
  Future<TocResult> fetch(
    RulePack pack, {
    required String id,
    String? url,
    WorkDetail? detail,
    SearchResult? searchResult,
  });
}

/// 执行规则包的 `toc` 能力，支持平铺目录与 `fanOutFrom` 逐组扇出。
class RuleTocPipeline implements RuleTocService {
  const RuleTocPipeline({
    required this.httpClient,
    this.evaluator = const FieldEvaluator(),
    this.requestBuilder = const RuleRequestBuilder(),
  });

  final RuleHttpClient httpClient;
  final FieldEvaluator evaluator;
  final RuleRequestBuilder requestBuilder;

  @override
  Future<TocResult> fetch(
    RulePack pack, {
    required String id,
    String? url,
    WorkDetail? detail,
    SearchResult? searchResult,
  }) async {
    final capability = pack.capabilities[RuleCapability.toc];
    if (capability is! TocCapabilityRule) {
      throw const UnsupportedCapabilityException('规则未声明 toc 能力');
    }
    final workUrl = url ?? detail?.url;
    final variables = <String, Object?>{
      'baseUrl': pack.meta.baseUrl,
      'id': id,
      'url': workUrl ?? '',
    };
    final fanOutFrom = capability.fanOutFrom;
    if (fanOutFrom == null) {
      return _fetchFlat(pack, capability, variables);
    }
    final items = _fanOutItems(fanOutFrom, detail, searchResult);
    if (items.isEmpty) {
      return TocResult.empty;
    }
    return _fetchFanOut(pack, capability, variables, items);
  }

  Future<TocResult> _fetchFlat(
    RulePack pack,
    TocCapabilityRule capability,
    Map<String, Object?> variables,
  ) async {
    final list = capability.list;
    if (list == null) {
      throw const RuleFormatException('toc 缺少 list 选择器');
    }
    final request = requestBuilder.build(
      pack: pack,
      url: capability.url,
      method: capability.method,
      body: capability.body,
      headers: capability.headers,
      variables: variables,
    );
    final document = await fetchRuleDocument(httpClient, request);
    final context = RuleEvalContext(
      pack: pack,
      pageUri: document.uri,
      json: document.json,
      htmlDocument: document.htmlDocument,
      xmlNode: document.xmlDocument,
      variables: variables,
    );
    final entries = _mapEntries(
      capability.fields,
      evaluator.resolveItems(list, context),
      context,
      document.uri,
      null,
      null,
    );
    return TocResult(entries: List<TocEntry>.unmodifiable(entries));
  }

  Future<TocResult> _fetchFanOut(
    RulePack pack,
    TocCapabilityRule capability,
    Map<String, Object?> variables,
    List<Object?> items,
  ) async {
    final result = <TocEntry>[];
    final groupRule = capability.group;
    final hasRequest = capability.url.trim().isNotEmpty && capability.list != null;
    for (final item in items) {
      final groupItem = _groupItem(item);
      final groupId = groupRule == null ? null : scalarValue(groupItem[groupRule.idField]);
      final groupTitle = groupRule == null ? null : scalarValue(groupItem[groupRule.titleField]);
      final groupVariables = <String, Object?>{
        ...variables,
        for (final entry in groupItem.entries) 'group.${entry.key}': entry.value,
        'group.id': ?groupId,
        'group.title': ?groupTitle,
      };
      if (hasRequest) {
        final request = requestBuilder.build(
          pack: pack,
          url: capability.url,
          method: capability.method,
          body: capability.body,
          headers: capability.headers,
          variables: groupVariables,
        );
        final document = await fetchRuleDocument(httpClient, request);
        final context = RuleEvalContext(
          pack: pack,
          pageUri: document.uri,
          json: document.json,
          htmlDocument: document.htmlDocument,
          xmlNode: document.xmlDocument,
          variables: groupVariables,
        );
        result.addAll(
          _mapEntries(
            capability.fields,
            evaluator.resolveItems(capability.list!, context),
            context,
            document.uri,
            groupId,
            groupTitle,
          ),
        );
        continue;
      }
      final pageUri = Uri.parse(pack.meta.baseUrl);
      final baseContext = RuleEvalContext(
        pack: pack,
        pageUri: pageUri,
        variables: groupVariables,
      );
      final values = _evaluateFields(capability.fields, baseContext.withEntry(item));
      final entry = _toEntry(values, pageUri, groupId, groupTitle);
      if (entry != null) {
        result.add(entry);
      }
    }
    return TocResult(entries: List<TocEntry>.unmodifiable(result));
  }

  List<TocEntry> _mapEntries(
    Map<String, FieldRule> fields,
    List<Object?> entries,
    RuleEvalContext pageContext,
    Uri pageUri,
    String? groupId,
    String? groupTitle,
  ) {
    final result = <TocEntry>[];
    for (final entry in entries) {
      final values = _evaluateFields(fields, pageContext.withEntry(entry));
      final tocEntry = _toEntry(values, pageUri, groupId, groupTitle);
      if (tocEntry != null) {
        result.add(tocEntry);
      }
    }
    return result;
  }

  Map<String, Object?> _evaluateFields(
    Map<String, FieldRule> fields,
    RuleEvalContext context,
  ) {
    final values = <String, Object?>{};
    for (final entry in fields.entries) {
      values[entry.key] = evaluator.evaluate(entry.value, context);
    }
    return values;
  }

  TocEntry? _toEntry(
    Map<String, Object?> values,
    Uri pageUri,
    String? groupId,
    String? groupTitle,
  ) {
    final title = scalarValue(values['title']);
    final id = scalarValue(values['id']);
    final url = absoluteUrl(pageUri, scalarValue(values['url']));
    if (title == null || (id == null && url == null)) {
      return null;
    }
    return TocEntry(
      id: id,
      title: title,
      url: url,
      order: intValue(values['order']),
      group: scalarValue(values['group']) ?? groupId,
      groupTitle: scalarValue(values['groupTitle']) ?? groupTitle,
      duration: scalarValue(values['duration']),
      airdate: scalarValue(values['airdate']),
      extra: Map<String, Object?>.unmodifiable(values),
    );
  }

  List<Object?> _fanOutItems(
    String source,
    WorkDetail? detail,
    SearchResult? searchResult,
  ) {
    final separator = source.indexOf('.');
    if (separator <= 0 || separator == source.length - 1) {
      throw RuleFormatException('fanOutFrom 必须是 <能力>.<字段>，实际为 $source');
    }
    final capability = source.substring(0, separator);
    final field = source.substring(separator + 1);
    final Object? raw = switch (capability) {
      'detail' => detail?.fields[field],
      'search' => searchResult?.extra[field],
      _ => throw RuleFormatException('fanOutFrom 仅支持 detail / search，实际为 $capability'),
    };
    if (raw == null) {
      throw RuleFormatException('fanOutFrom 缺少数据：$source');
    }
    if (raw is List<Object?>) {
      return raw;
    }
    if (raw is Map<Object?, Object?>) {
      return <Object?>[raw];
    }
    throw RuleFormatException('fanOutFrom 目标必须是对象数组：$source');
  }

  Map<String, Object?> _groupItem(Object? item) {
    if (item is Map<String, Object?>) {
      return item;
    }
    if (item is Map<Object?, Object?>) {
      return <String, Object?>{
        for (final entry in item.entries) entry.key.toString(): entry.value,
      };
    }
    throw const RuleFormatException('fanOutFrom 条目必须是对象');
  }
}
