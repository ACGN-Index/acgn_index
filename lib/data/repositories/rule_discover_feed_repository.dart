import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/repositories/rule_cover_headers.dart';
import 'package:acgn_index/data/repositories/rule_discover_item.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
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

    final result = await _loadTargets(<_Target>[
      for (final source in searchable) _Target(source: source, page: 1),
    ]);
    return DiscoverFeed(
      items: result.items,
      failures: result.failures,
      sourceCount: enabled.length,
      searchableSourceCount: searchable.length,
      cursors: result.cursors,
    );
  }

  @override
  Future<DiscoverFeedChunk> loadMore(List<RulePageCursor> cursors) async {
    if (cursors.isEmpty) {
      return DiscoverFeedChunk.empty;
    }
    final sources = await _sourceRepository.getAll();
    final byId = <String, RuleSource>{for (final source in sources) source.id: source};
    final targets = <_Target>[];
    for (final cursor in cursors) {
      final source = byId[cursor.ruleId];
      // 翻页期间规则可能被停用或删除，跳过即可（不再产生游标）。
      if (source == null || !source.enabled || !source.pack.supports(RuleCapability.search)) {
        continue;
      }
      targets.add(_Target(source: source, page: cursor.page));
    }
    final result = await _loadTargets(targets);
    return DiscoverFeedChunk(
      items: result.items,
      failures: result.failures,
      cursors: result.cursors,
    );
  }

  Future<_PageResult> _loadTargets(List<_Target> targets) async {
    if (targets.isEmpty) {
      return _PageResult.empty;
    }
    final results = await Future.wait(targets.map(_loadTarget));
    final items = <DiscoverItem>[];
    final failures = <DiscoverFailure>[];
    final cursors = <RulePageCursor>[];
    for (final result in results) {
      final source = result.source;
      if (result.error != null) {
        // 失败不产生游标：坏规则不参与后续翻页，避免每次触底都重复请求。
        failures.add(
          DiscoverFailure(ruleId: source.id, ruleName: source.name),
        );
        continue;
      }
      if (result.items.isNotEmpty) {
        final auth = await _auth?.find(source.id);
        final headers = ruleCoverHeaders(source, auth);
        final seen = <String>{};
        for (final work in result.items) {
          if (!seen.add(work.id)) {
            continue;
          }
          items.add(discoverItemFrom(source, work, headers));
        }
      }
      // 空页即使声明了 hasMore 也视为到底，避免站点返回空列表时无限触底重试。
      if (result.hasMore && result.items.isNotEmpty) {
        cursors.add(RulePageCursor(ruleId: source.id, page: result.page + 1));
      }
    }
    return _PageResult(
      items: List<DiscoverItem>.unmodifiable(items),
      failures: List<DiscoverFailure>.unmodifiable(failures),
      cursors: List<RulePageCursor>.unmodifiable(cursors),
    );
  }

  Future<_SourceResult> _loadTarget(_Target target) async {
    try {
      final page = await _pipeline.search(target.source.pack, page: target.page);
      return _SourceResult(
        source: target.source,
        page: target.page,
        items: page.items,
        hasMore: page.hasMore,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.of('discover').warning(
        '规则 ${target.source.id} 第 ${target.page} 页加载失败',
        error,
        stackTrace,
      );
      return _SourceResult(
        source: target.source,
        page: target.page,
        items: const <SearchResult>[],
        error: error,
      );
    }
  }

  int _compareSources(RuleSource a, RuleSource b) {
    final priority = a.priority.compareTo(b.priority);
    return priority != 0 ? priority : a.name.compareTo(b.name);
  }
}

class _Target {
  const _Target({required this.source, required this.page});

  final RuleSource source;
  final int page;
}

class _SourceResult {
  const _SourceResult({
    required this.source,
    required this.page,
    required this.items,
    this.hasMore = false,
    this.error,
  });

  final RuleSource source;
  final int page;
  final List<SearchResult> items;
  final bool hasMore;
  final Object? error;
}

class _PageResult {
  const _PageResult({
    required this.items,
    required this.failures,
    required this.cursors,
  });

  static const _PageResult empty = _PageResult(
    items: <DiscoverItem>[],
    failures: <DiscoverFailure>[],
    cursors: <RulePageCursor>[],
  );

  final List<DiscoverItem> items;
  final List<DiscoverFailure> failures;
  final List<RulePageCursor> cursors;
}
