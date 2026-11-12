import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/repositories/rule_cover_headers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';

/// 聚合所有启用规则的 `search` 结果；单条规则失败不影响其它规则。
class RuleDiscoverFeedRepository implements DiscoverFeedRepository {
  RuleDiscoverFeedRepository(
    this._sourceRepository,
    this._pipeline, [
    this._auth,
  ]);

  final RuleSourceRepository _sourceRepository;
  final RuleSearchService _pipeline;
  final RuleAuthRepository? _auth;

  @override
  Future<DiscoverFeed> load() async {
    final sources = await _sourceRepository.getAll();
    final enabled = sources.where((source) => source.enabled).toList(growable: false)
      ..sort(_compareSources);
    final searchable = enabled
        .where((source) => source.pack.supports(RuleCapability.search))
        .toList(growable: false);

    final results = await Future.wait(searchable.map(_loadSource));
    final items = <DiscoverItem>[];
    final failures = <DiscoverFailure>[];
    for (final result in results) {
      if (result.error != null) {
        failures.add(
          DiscoverFailure(ruleId: result.source.id, ruleName: result.source.name),
        );
        continue;
      }
      final auth = await _auth?.find(result.source.id);
      final headers = ruleCoverHeaders(result.source, auth);
      final seen = <String>{};
      for (final work in result.items) {
        if (!seen.add(work.id)) {
          continue;
        }
        items.add(_toItem(result.source, work, headers));
      }
    }
    return DiscoverFeed(
      items: List<DiscoverItem>.unmodifiable(items),
      failures: List<DiscoverFailure>.unmodifiable(failures),
      sourceCount: enabled.length,
      searchableSourceCount: searchable.length,
    );
  }

  Future<_SourceResult> _loadSource(RuleSource source) async {
    try {
      final page = await _pipeline.search(source.pack);
      return _SourceResult(source: source, items: page.items);
    } on Object catch (error, stackTrace) {
      AppLogger.of('discover').warning(
        '规则 ${source.id} 加载失败',
        error,
        stackTrace,
      );
      return _SourceResult(
        source: source,
        items: const <SearchResult>[],
        error: error,
      );
    }
  }

  int _compareSources(RuleSource a, RuleSource b) {
    final priority = a.priority.compareTo(b.priority);
    return priority != 0 ? priority : a.name.compareTo(b.name);
  }

  DiscoverItem _toItem(
    RuleSource source,
    SearchResult work,
    Map<String, String> headers,
  ) => DiscoverItem(
    ruleId: source.id,
    ruleName: source.name,
    type: source.type,
    origin: source.origin,
    adult: source.pack.meta.adult,
    id: work.id,
    title: work.title,
    cover: work.cover,
    coverHeaders: headers,
    author: work.author,
    subtitle: work.subtitle,
    url: work.url == null ? null : Uri.tryParse(work.url!),
    extra: work.extra,
  );
}

class _SourceResult {
  const _SourceResult({required this.source, required this.items, this.error});

  final RuleSource source;
  final List<SearchResult> items;
  final Object? error;
}
