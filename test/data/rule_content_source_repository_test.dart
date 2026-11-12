import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/repositories/rule_content_source_repository.dart';
import 'package:acgn_index/domain/entities/content_source.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/sources/sources_test_helpers.dart';

void main() {
  group('RuleContentSourceRepository', () {
    test('只检索启用、同类型的资源提供者，按 priority 分组返回', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'current', hasContent: false),
        _source(id: 'provider.late', priority: 5),
        _source(id: 'provider.early', priority: 1),
        _source(id: 'provider.disabled', enabled: false),
        _source(id: 'provider.comic', type: MediaType.comic),
        _source(id: 'provider.noContent', hasContent: false),
        _source(id: 'provider.noSearch', hasSearch: false),
      ]);
      addTearDown(sources.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '作品A': <String, List<SearchResult>>{
          'provider.late': const <SearchResult>[SearchResult(id: 'l1', title: '作品A')],
          'provider.early': const <SearchResult>[SearchResult(id: 'e1', title: '作品A')],
        },
      });

      final result = await RuleContentSourceRepository(sources, search).search(
        const ContentSourceQuery(
          type: MediaType.anime,
          title: '作品A',
          excludeRuleId: 'current',
        ),
      );

      expect(search.calls.map((call) => call.ruleId), <String>[
        'provider.early',
        'provider.late',
      ]);
      expect(result.groups.map((group) => group.ruleId), <String>[
        'provider.early',
        'provider.late',
      ]);
      expect(result.groups.every((group) => group.status == ContentSourceStatus.ok), isTrue);
      expect(result.resultCount, 2);
      expect(result.groups.first.keyword, '作品A');
      expect(result.groups.first.items.single.extra, isEmpty);
    });

    test('每个来源优先保留标题相关的结果并限制条数', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'related'),
        _source(id: 'unrelated'),
      ]);
      addTearDown(sources.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '葬送的芙莉莲': <String, List<SearchResult>>{
          'related': const <SearchResult>[
            SearchResult(id: 'r1', title: '进击的巨人'),
            SearchResult(id: 'r2', title: '葬送的芙莉莲 第一季'),
            SearchResult(id: 'r3', title: '葬送的芙莉莲'),
            SearchResult(id: 'r4', title: '芙莉莲外传'),
          ],
          'unrelated': const <SearchResult>[
            SearchResult(id: 'u1', title: '甲'),
            SearchResult(id: 'u2', title: '乙'),
            SearchResult(id: 'u3', title: '丙'),
            SearchResult(id: 'u4', title: '丁'),
          ],
        },
      });

      final result = await RuleContentSourceRepository(sources, search).search(
        const ContentSourceQuery(type: MediaType.anime, title: '葬送的芙莉莲'),
      );

      final related = result.groups.firstWhere((group) => group.ruleId == 'related');
      final unrelated = result.groups.firstWhere((group) => group.ruleId == 'unrelated');
      expect(related.items.map((item) => item.id), <String>['r3', 'r2']);
      expect(unrelated.items.map((item) => item.id), <String>['u1', 'u2', 'u3']);
    });

    test('没有命中或检索失败的来源只影响自己的分组', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'provider.broken'),
        _source(id: 'provider.empty'),
        _source(id: 'provider.ok'),
      ]);
      addTearDown(sources.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '作品A': <String, List<SearchResult>>{
          'provider.ok': const <SearchResult>[SearchResult(id: 'ok1', title: '作品A')],
        },
      });
      search.failingRuleIds.add('provider.broken');

      final result = await RuleContentSourceRepository(sources, search).search(
        const ContentSourceQuery(type: MediaType.anime, title: '作品A'),
      );

      expect(result.providerCount, 3);
      expect(
        result.groups.map((group) => group.status),
        <ContentSourceStatus>[
          ContentSourceStatus.failed,
          ContentSourceStatus.noResult,
          ContentSourceStatus.ok,
        ],
      );
      expect(result.failureCount, 1);
      expect(result.resultCount, 1);
    });

    test('首轮没有结果时按别名再检索，最多尝试两个别名', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[_source(id: 'provider')]);
      addTearDown(sources.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '别名A': <String, List<SearchResult>>{
          'provider': const <SearchResult>[SearchResult(id: 'a1', title: '别名A')],
        },
      });

      final result = await RuleContentSourceRepository(sources, search).search(
        const ContentSourceQuery(
          type: MediaType.anime,
          title: '作品A',
          aliases: <String>['别名B', '别名A', '别名C'],
        ),
      );

      expect(search.calls.map((call) => call.keyword), <String>['作品A', '别名B', '别名A']);
      expect(result.groups.single.items.single.id, 'a1');
      expect(result.groups.single.keyword, '别名A');
    });

    test('封面请求头合并规则头、搜索能力头与本地凭据', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[_source(id: 'provider')]);
      addTearDown(sources.close);
      final auth = FakeRuleAuthRepository(<String, RuleAuth>{
        'provider': RuleAuth(
          ruleId: 'provider',
          cookies: const <String, String>{'sid': 'abc'},
          headers: const <String, String>{'Authorization': '******'},
          updatedAt: DateTime(2026),
        ),
      });
      addTearDown(auth.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '作品A': <String, List<SearchResult>>{
          'provider': const <SearchResult>[SearchResult(id: 'p1', title: '作品A')],
        },
      });

      final result = await RuleContentSourceRepository(sources, search, auth).search(
        const ContentSourceQuery(type: MediaType.anime, title: '作品A'),
      );

      final headers = result.groups.single.items.single.coverHeaders;
      expect(headers['Referer'], 'https://example.invalid');
      expect(headers['X-Test'], '1');
      expect(headers['Cookie'], 'sid=abc');
      expect(headers['Authorization'], '******');
    });

    test('没有候选来源时不发起请求', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'current', hasContent: false),
        _source(id: 'provider.disabled', enabled: false),
      ]);
      addTearDown(sources.close);
      final search = _FakeSearchService();

      final result = await RuleContentSourceRepository(sources, search).search(
        const ContentSourceQuery(
          type: MediaType.anime,
          title: '作品A',
          excludeRuleId: 'current',
        ),
      );

      expect(search.calls, isEmpty);
      expect(result.providerCount, 0);
      expect(result.isEmpty, isTrue);
    });

    test('用指定检索词重新检索单个来源', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        _source(id: 'provider.a'),
        _source(id: 'provider.b'),
      ]);
      addTearDown(sources.close);
      final search = _FakeSearchService(<String, Map<String, List<SearchResult>>>{
        '自定义词': <String, List<SearchResult>>{
          'provider.b': const <SearchResult>[SearchResult(id: 'b1', title: '自定义词')],
        },
      });
      final repository = RuleContentSourceRepository(sources, search);
      const query = ContentSourceQuery(type: MediaType.anime, title: '作品A');

      final group = await repository.refreshProvider(
        query,
        ruleId: 'provider.b',
        keyword: ' 自定义词 ',
      );

      expect(search.calls.single.ruleId, 'provider.b');
      expect(search.calls.single.keyword, '自定义词');
      expect(group?.ruleId, 'provider.b');
      expect(group?.keyword, '自定义词');
      expect(group?.items.single.id, 'b1');
      expect(group?.status, ContentSourceStatus.ok);

      expect(
        await repository.refreshProvider(query, ruleId: 'missing', keyword: '作品A'),
        isNull,
      );
      expect(
        await repository.refreshProvider(query, ruleId: 'provider.a', keyword: '   '),
        isNull,
      );
    });
  });
}

RuleSource _source({
  required String id,
  MediaType type = MediaType.anime,
  bool enabled = true,
  int priority = 0,
  bool hasSearch = true,
  bool hasContent = true,
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
    ),
    request: const RequestRule(
      headers: <String, String>{'Referer': 'https://example.invalid'},
    ),
    capabilities: <RuleCapability, CapabilityRule>{
      if (hasSearch)
        RuleCapability.search: const SearchCapabilityRule(
          url: '/search',
          headers: <String, String>{'X-Test': '1'},
        ),
      if (hasContent)
        RuleCapability.content: const ContentCapabilityRule(
          url: '/content/{{chapter.id}}',
          mode: ContentMode.images,
        ),
    },
  ),
  enabled: enabled,
  installedAt: DateTime(2026),
  priority: priority,
);

class _FakeSearchService implements RuleSearchService {
  _FakeSearchService([this.results = const <String, Map<String, List<SearchResult>>>{}]);

  /// 关键词 → 规则 id → 搜索结果。
  final Map<String, Map<String, List<SearchResult>>> results;
  final List<({String ruleId, String keyword})> calls = <({String ruleId, String keyword})>[];
  final Set<String> failingRuleIds = <String>{};

  @override
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1}) async {
    calls.add((ruleId: pack.id, keyword: keyword));
    if (failingRuleIds.contains(pack.id)) {
      throw const NetworkException('boom');
    }
    return SearchPage(items: results[keyword]?[pack.id] ?? const <SearchResult>[]);
  }
}
