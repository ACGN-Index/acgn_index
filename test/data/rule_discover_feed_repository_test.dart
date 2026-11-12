import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/repositories/rule_discover_feed_repository.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/sources/sources_test_helpers.dart';

void main() {
  group('RuleDiscoverFeedRepository', () {
    test('只聚合启用且有 search 能力的规则，并按 priority 拼接', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(
          id: 'rule.comic',
          type: MediaType.comic,
        ),
        _source(
          id: 'rule.anime',
          type: MediaType.anime,
          priority: 1,
        ),
        _source(
          id: 'rule.novel',
          type: MediaType.novel,
          priority: 2,
          adult: true,
        ),
        _source(
          id: 'rule.disabled',
          type: MediaType.comic,
          priority: 3,
          enabled: false,
        ),
        _source(
          id: 'rule.noSearch',
          type: MediaType.comic,
          priority: 4,
          hasSearch: false,
        ),
      ]);
      addTearDown(repository.close);

      final feed = await RuleDiscoverFeedRepository(
        repository,
        _FakeSearchService(
          items: <String, List<SearchResult>>{
            'rule.comic': const <SearchResult>[
              SearchResult(
                id: 'c1',
                title: '漫画 1',
                cover: 'https://img/c1.jpg',
                extra: <String, Object?>{'volumes': <Object?>[]},
              ),
              SearchResult(id: 'c1', title: '漫画 1 重复'),
              SearchResult(id: 'c2', title: '漫画 2'),
            ],
            'rule.novel': const <SearchResult>[
              SearchResult(id: 'n1', title: '小说 1'),
            ],
          },
          failures: const <String>{'rule.anime'},
        ),
      ).load();

      expect(feed.sourceCount, 4);
      expect(feed.searchableSourceCount, 3);
      expect(feed.failures.map((failure) => failure.ruleId), <String>['rule.anime']);
      expect(feed.items.map((item) => item.id), <String>['c1', 'c2', 'n1']);
      expect(feed.items.first.coverHeaders['Referer'], 'https://example.invalid');
      expect(feed.items.first.coverHeaders['X-Test'], '1');
      expect(feed.items.first.extra['volumes'], isNotNull);
      expect(feed.items.last.adult, isTrue);
      expect(feed.items.last.type, MediaType.novel);
    });

    test('封面请求头合并本地登录凭据', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'rule.comic', type: MediaType.comic),
      ]);
      addTearDown(sources.close);
      final authRepository = FakeRuleAuthRepository(<String, RuleAuth>{
        'rule.comic': RuleAuth(
          ruleId: 'rule.comic',
          cookies: const <String, String>{'sid': 'abc'},
          headers: const <String, String>{'Authorization': 'Bearer token'},
          updatedAt: DateTime(2026),
        ),
      });
      addTearDown(authRepository.close);

      final feed = await RuleDiscoverFeedRepository(
        sources,
        _FakeSearchService(
          items: <String, List<SearchResult>>{
            'rule.comic': const <SearchResult>[
              SearchResult(
                id: 'c1',
                title: '漫画 1',
                cover: 'https://img/c1.jpg',
              ),
            ],
          },
        ),
        authRepository,
      ).load();

      expect(feed.items.single.coverHeaders['Cookie'], 'sid=abc');
      expect(feed.items.single.coverHeaders['Authorization'], 'Bearer token');
    });

    test('没有启用规则时返回空聚合结果', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(
          id: 'rule.disabled',
          type: MediaType.comic,
          enabled: false,
        ),
      ]);
      addTearDown(repository.close);

      final feed = await RuleDiscoverFeedRepository(
        repository,
        _FakeSearchService(),
      ).load();

      expect(feed.sourceCount, 0);
      expect(feed.searchableSourceCount, 0);
      expect(feed.items, isEmpty);
      expect(feed.failures, isEmpty);
      expect(feed.hasMore, isFalse);
    });

    test('声明 hasMore 的规则生成下一页游标，追加页只请求对应页码', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'rule.comic', type: MediaType.comic),
        _source(id: 'rule.novel', type: MediaType.novel, priority: 1),
      ]);
      addTearDown(repository.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'rule.comic#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c1', title: '漫画 1')],
            hasMore: true,
          ),
          'rule.novel#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'n1', title: '小说 1')],
          ),
          'rule.comic#2': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c2', title: '漫画 2')],
          ),
        },
      );
      final discover = RuleDiscoverFeedRepository(repository, service);

      final feed = await discover.load();
      expect(feed.items.map((item) => item.id), <String>['c1', 'n1']);
      expect(feed.cursors, <RulePageCursor>[
        const RulePageCursor(ruleId: 'rule.comic', page: 2),
      ]);
      expect(feed.hasMore, isTrue);

      service.calls.clear();
      final chunk = await discover.loadMore(feed.cursors);

      expect(service.calls, <({String ruleId, int page})>[
        (ruleId: 'rule.comic', page: 2),
      ]);
      expect(chunk.items.map((item) => item.id), <String>['c2']);
      expect(chunk.cursors, isEmpty);
      expect(chunk.failures, isEmpty);
    });

    test('空页即使声明 hasMore 也视为到底', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'rule.comic', type: MediaType.comic),
      ]);
      addTearDown(repository.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'rule.comic#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c1', title: '漫画 1')],
            hasMore: true,
          ),
          'rule.comic#2': SearchPage(
            items: <SearchResult>[],
            hasMore: true,
          ),
        },
      );
      final discover = RuleDiscoverFeedRepository(repository, service);

      final feed = await discover.load();
      final chunk = await discover.loadMore(feed.cursors);

      expect(chunk.items, isEmpty);
      expect(chunk.cursors, isEmpty);
    });

    test('追加页失败会记录失败并停止该规则翻页', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'rule.comic', type: MediaType.comic),
      ]);
      addTearDown(repository.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'rule.comic#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c1', title: '漫画 1')],
            hasMore: true,
          ),
        },
        pageFailures: const <String>{'rule.comic#2'},
      );
      final discover = RuleDiscoverFeedRepository(repository, service);

      final feed = await discover.load();
      final chunk = await discover.loadMore(feed.cursors);

      expect(chunk.items, isEmpty);
      expect(chunk.cursors, isEmpty);
      expect(chunk.failures.single.ruleId, 'rule.comic');
    });

    test('游标为空时不再发起请求', () async {
      final repository = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'rule.comic', type: MediaType.comic),
      ]);
      addTearDown(repository.close);
      final service = _FakeSearchService();
      final discover = RuleDiscoverFeedRepository(repository, service);

      final chunk = await discover.loadMore(const <RulePageCursor>[]);

      expect(chunk.items, isEmpty);
      expect(service.calls, isEmpty);
    });
  });
}

RuleSource _source({
  required String id,
  required MediaType type,
  bool enabled = true,
  int priority = 0,
  bool hasSearch = true,
  bool adult = false,
}) => RuleSource(
  pack: RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: RuleMeta(
      id: id,
      name: id,
      type: type,
      baseUrl: 'https://example.invalid',
      version: '1.0.0',
      author: 'tester',
      lang: 'zh',
      adult: adult,
    ),
    request: const RequestRule(
      headers: <String, String>{'Referer': 'https://example.invalid'},
    ),
    capabilities: hasSearch
        ? const <RuleCapability, CapabilityRule>{
            RuleCapability.search: SearchCapabilityRule(
              url: '/search',
              headers: <String, String>{'X-Test': '1'},
            ),
          }
        : const <RuleCapability, CapabilityRule>{},
  ),
  enabled: enabled,
  installedAt: DateTime(2026),
  origin: RuleSourceOrigin.builtin,
  readOnly: true,
  priority: priority,
);

class _FakeSearchService implements RuleSearchService {
  _FakeSearchService({
    this.items = const <String, List<SearchResult>>{},
    this.failures = const <String>{},
    this.pages = const <String, SearchPage>{},
    this.pageFailures = const <String>{},
  });

  /// `ruleId` → 第一页结果。
  final Map<String, List<SearchResult>> items;

  /// 整条规则都失败。
  final Set<String> failures;

  /// `ruleId#page` → 该页结果；未声明的页码视为空页。
  final Map<String, SearchPage> pages;

  /// `ruleId#page` → 该页请求失败。
  final Set<String> pageFailures;

  final List<({String ruleId, int page})> calls = <({String ruleId, int page})>[];

  @override
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1}) async {
    calls.add((ruleId: pack.id, page: page));
    final key = '${pack.id}#$page';
    if (failures.contains(pack.id) || pageFailures.contains(key)) {
      throw const NetworkException('boom');
    }
    if (pages[key] case final SearchPage result) {
      return result;
    }
    return page > 1
        ? const SearchPage(items: <SearchResult>[])
        : SearchPage(items: items[pack.id] ?? const <SearchResult>[]);
  }
}
