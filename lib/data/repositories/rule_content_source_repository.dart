import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/title_match.dart';
import 'package:acgn_index/data/repositories/rule_cover_headers.dart';
import 'package:acgn_index/data/repositories/rule_discover_item.dart';
import 'package:acgn_index/domain/entities/content_source.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/content_source_repository.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';

/// 在启用且具备 `content` 能力的同类规则中检索同一作品。
///
/// 结果按来源分组，单个来源失败或没有命中只影响自己的分组；主关键词全部
/// 落空时再按别名重试（最多 [maxAliasKeywords] 个），每个来源最多保留
/// [maxItemsPerProvider] 条结果。
class RuleContentSourceRepository implements ContentSourceRepository {
  RuleContentSourceRepository(this._sources, this._pipeline, [this._auth]);

  static const int maxItemsPerProvider = 3;
  static const int maxAliasKeywords = 2;

  final RuleSourceRepository _sources;
  final RuleSearchService _pipeline;
  final RuleAuthRepository? _auth;

  @override
  Future<ContentSourceResult> search(ContentSourceQuery query) async {
    final providers = await _providers(query);
    if (providers.isEmpty) {
      return ContentSourceResult.empty;
    }
    final groups = <String, ContentSourceGroup>{};
    for (final keyword in _keywords(query)) {
      final targets = providers
          .where((source) {
            final existing = groups[source.id];
            return existing == null || existing.status == ContentSourceStatus.noResult;
          })
          .toList(growable: false);
      if (targets.isEmpty) {
        break;
      }
      final loaded = await Future.wait(targets.map((source) => _loadProvider(source, keyword)));
      for (final group in loaded) {
        groups[group.ruleId] = group;
      }
      if (groups.values.any((group) => group.hasResults)) {
        break;
      }
    }
    return ContentSourceResult(
      groups: List<ContentSourceGroup>.unmodifiable(<ContentSourceGroup>[
        for (final source in providers)
          groups[source.id] ??
              ContentSourceGroup(ruleId: source.id, ruleName: source.name, keyword: query.title),
      ]),
    );
  }

  @override
  Future<ContentSourceGroup?> refreshProvider(
    ContentSourceQuery query, {
    required String ruleId,
    required String keyword,
  }) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final providers = await _providers(query);
    final source = providers.where((candidate) => candidate.id == ruleId).firstOrNull;
    if (source == null) {
      return null;
    }
    return _loadProvider(source, trimmed);
  }

  Future<List<RuleSource>> _providers(ContentSourceQuery query) async {
    final sources = await _sources.getAll();
    return sources.where((source) => _isProvider(source, query)).toList(growable: false)
      ..sort(_compareSources);
  }

  Future<ContentSourceGroup> _loadProvider(RuleSource source, String keyword) async {
    try {
      final page = await _pipeline.search(source.pack, keyword: keyword);
      final items = await _toItems(source, _select(page.items, keyword));
      return ContentSourceGroup(
        ruleId: source.id,
        ruleName: source.name,
        keyword: keyword,
        items: items,
        status: items.isEmpty ? ContentSourceStatus.noResult : ContentSourceStatus.ok,
      );
    } on Object catch (error, stackTrace) {
      AppLogger.of('detail').warning(
        '内容来源检索失败：${source.id}/$keyword',
        error,
        stackTrace,
      );
      return ContentSourceGroup(
        ruleId: source.id,
        ruleName: source.name,
        keyword: keyword,
        status: ContentSourceStatus.failed,
      );
    }
  }

  Future<List<DiscoverItem>> _toItems(RuleSource source, List<SearchResult> results) async {
    if (results.isEmpty) {
      return const <DiscoverItem>[];
    }
    final RuleAuth? auth = await _auth?.find(source.id);
    final headers = ruleCoverHeaders(source, auth);
    return <DiscoverItem>[
      for (final work in results) discoverItemFrom(source, work, headers),
    ];
  }

  /// 标题相关的条目优先；该来源完全无关时回退到原顺序的前几条。
  List<SearchResult> _select(List<SearchResult> items, String keyword) {
    final seen = <String>{};
    final ranked = <({SearchResult item, int rank, int index})>[];
    for (final item in items) {
      if (item.id.isEmpty || !seen.add(item.id)) {
        continue;
      }
      ranked.add((item: item, rank: titleMatchRank(item.title, keyword), index: ranked.length));
    }
    final related = ranked.where((entry) => entry.rank > 0).toList();
    if (related.isEmpty) {
      return ranked.take(maxItemsPerProvider).map((entry) => entry.item).toList(growable: false);
    }
    related.sort((a, b) {
      final byRank = b.rank.compareTo(a.rank);
      return byRank != 0 ? byRank : a.index.compareTo(b.index);
    });
    return related.take(maxItemsPerProvider).map((entry) => entry.item).toList(growable: false);
  }

  List<String> _keywords(ContentSourceQuery query) {
    final keywords = <String>[];
    final seen = <String>{};
    void add(String value) {
      final text = value.trim();
      final normalized = normalizeTitle(text);
      if (normalized.isEmpty || !seen.add(normalized)) {
        return;
      }
      keywords.add(text);
    }

    add(query.title);
    for (final alias in query.aliases.take(maxAliasKeywords)) {
      add(alias);
    }
    return keywords;
  }

  bool _isProvider(RuleSource source, ContentSourceQuery query) =>
      source.enabled &&
      source.type == query.type &&
      source.id != query.excludeRuleId &&
      source.pack.supports(RuleCapability.search) &&
      source.pack.supports(RuleCapability.content);

  int _compareSources(RuleSource a, RuleSource b) {
    final priority = a.priority.compareTo(b.priority);
    return priority != 0 ? priority : a.name.compareTo(b.name);
  }
}
