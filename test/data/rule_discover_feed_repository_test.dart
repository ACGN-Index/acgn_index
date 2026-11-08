import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/repositories/rule_discover_feed_repository.dart';
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
  });

  final Map<String, List<SearchResult>> items;
  final Set<String> failures;

  @override
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1}) async {
    if (failures.contains(pack.id)) {
      throw const NetworkException('boom');
    }
    return SearchPage(items: items[pack.id] ?? const <SearchResult>[]);
  }
}
