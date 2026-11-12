import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/repositories/rule_cover_headers.dart';
import 'package:acgn_index/data/repositories/rule_discover_item.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/work_search.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/domain/repositories/work_search_repository.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';

/// 用关键词并发检索所有启用且具备 `search` 能力的规则，结果按规则分组。
///
/// 与发现页聚合共用同一套游标语义：每条规则各自翻页，单条规则失败只影响
/// 自己的分组；空页视为到底，避免用户无限触底重试。
class RuleWorkSearchRepository implements WorkSearchRepository {
  RuleWorkSearchRepository(this._sources, this._pipeline, [this._auth]);

  final RuleSourceRepository _sources;
  final RuleSearchService _pipeline;
  final RuleAuthRepository? _auth;

  @override
  Future<WorkSearchPage> search(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return WorkSearchPage.empty;
    }
    final searchable = await _searchableSources();
    return _load(trimmed, <_Target>[
      for (final source in searchable) _Target(source: source, page: 1),
    ]);
  }

  @override
  Future<WorkSearchPage> loadMore(String keyword, List<RulePageCursor> cursors) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty || cursors.isEmpty) {
      return WorkSearchPage.empty;
    }
    final byId = <String, RuleSource>{
      for (final source in await _searchableSources()) source.id: source,
    };
    return _load(trimmed, <_Target>[
      for (final cursor in cursors)
        if (byId[cursor.ruleId] case final RuleSource source)
          _Target(source: source, page: cursor.page),
    ]);
  }

  Future<List<RuleSource>> _searchableSources() async {
    final sources = await _sources.getAll();
    return sources
        .where((source) => source.enabled && source.pack.supports(RuleCapability.search))
        .toList(growable: false)
      ..sort(_compareSources);
  }

  Future<WorkSearchPage> _load(String keyword, List<_Target> targets) async {
    if (targets.isEmpty) {
      return WorkSearchPage.empty;
    }
    final results = await Future.wait(targets.map((target) => _loadTarget(target, keyword)));
    final groups = <WorkSearchGroup>[];
    final cursors = <RulePageCursor>[];
    for (final result in results) {
      groups.add(result.group);
      if (result.hasMore && result.group.items.isNotEmpty) {
        cursors.add(RulePageCursor(ruleId: result.source.id, page: result.page + 1));
      }
    }
    return WorkSearchPage(
      groups: List<WorkSearchGroup>.unmodifiable(groups),
      cursors: List<RulePageCursor>.unmodifiable(cursors),
    );
  }

  Future<_SourceResult> _loadTarget(_Target target, String keyword) async {
    final source = target.source;
    try {
      final page = await _pipeline.search(source.pack, keyword: keyword, page: target.page);
      final items = <DiscoverItem>[];
      if (page.items.isNotEmpty) {
        final auth = await _auth?.find(source.id);
        final headers = ruleCoverHeaders(source, auth);
        final seen = <String>{};
        for (final work in page.items) {
          if (!seen.add(work.id)) {
            continue;
          }
          items.add(discoverItemFrom(source, work, headers));
        }
      }
      return _SourceResult(
        source: source,
        page: target.page,
        hasMore: page.hasMore,
        group: WorkSearchGroup(
          ruleId: source.id,
          ruleName: source.name,
          type: source.type,
          adult: source.pack.meta.adult,
          items: List<DiscoverItem>.unmodifiable(items),
          status: items.isEmpty ? WorkSearchStatus.noResult : WorkSearchStatus.ok,
        ),
      );
    } on Object catch (error, stackTrace) {
      AppLogger.of('search').warning(
        '规则 ${source.id} 搜索失败：$keyword',
        error,
        stackTrace,
      );
      return _SourceResult(
        source: source,
        page: target.page,
        group: WorkSearchGroup(
          ruleId: source.id,
          ruleName: source.name,
          type: source.type,
          adult: source.pack.meta.adult,
          status: WorkSearchStatus.failed,
        ),
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
    required this.group,
    this.hasMore = false,
  });

  final RuleSource source;
  final int page;
  final WorkSearchGroup group;
  final bool hasMore;
}
