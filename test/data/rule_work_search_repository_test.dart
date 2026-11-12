import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/repositories/rule_work_search_repository.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/work_search.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/sources/sources_test_helpers.dart';

void main() {
  group('RuleWorkSearchRepository', () {
    test('空关键词不发起任何请求', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        builtinSource(
          id: 'builtin.comic',
          name: '漫画规则',
          type: MediaType.comic,
          enabled: true,
          priority: 0,
        ),
      ]);
      addTearDown(sources.close);
      final service = _FakeSearchService();

      final page = await RuleWorkSearchRepository(sources, service).search('   ');

      expect(page.groups, isEmpty);
      expect(page.cursors, isEmpty);
      expect(service.calls, isEmpty);
    });

    test('按 priority 分组，跳过停用规则并去掉组内重复条目', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        builtinSource(
          id: 'builtin.novel',
          name: '小说规则',
          type: MediaType.novel,
          enabled: true,
          priority: 2,
        ),
        builtinSource(
          id: 'builtin.comic',
          name: '漫画规则',
          type: MediaType.comic,
          enabled: true,
          priority: 0,
        ),
        importedSource(id: 'imported.off', name: '停用规则', enabled: false),
      ]);
      addTearDown(sources.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'builtin.novel#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'n1', title: '小说 1')],
          ),
          'builtin.comic#1': SearchPage(
            items: <SearchResult>[
              SearchResult(id: 'c1', title: '漫画 1'),
              SearchResult(id: 'c1', title: '漫画 1 重复'),
            ],
          ),
        },
      );

      final page = await RuleWorkSearchRepository(sources, service).search('关键词');

      expect(page.groups.map((group) => group.ruleId), <String>[
        'builtin.comic',
        'builtin.novel',
      ]);
      expect(page.groups.first.items.map((item) => item.id), <String>['c1']);
      expect(page.groups.first.status, WorkSearchStatus.ok);
      expect(page.groups.last.type, MediaType.novel);
      expect(service.calls.map((call) => call.keyword), <String>['关键词', '关键词']);
      expect(service.calls.map((call) => call.page), <int>[1, 1]);
      expect(page.hasMore, isFalse);
    });

    test('单条规则失败只影响自己的分组', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        builtinSource(
          id: 'builtin.comic',
          name: '漫画规则',
          type: MediaType.comic,
          enabled: true,
          priority: 0,
        ),
        builtinSource(
          id: 'builtin.anime',
          name: '动漫规则',
          type: MediaType.anime,
          enabled: true,
          priority: 1,
        ),
      ]);
      addTearDown(sources.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'builtin.comic#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c1', title: '漫画 1')],
          ),
        },
        pageFailures: const <String>{'builtin.anime#1'},
      );

      final page = await RuleWorkSearchRepository(sources, service).search('关键词');

      expect(page.groups.map((group) => group.status), <WorkSearchStatus>[
        WorkSearchStatus.ok,
        WorkSearchStatus.failed,
      ]);
      expect(page.groups.last.items, isEmpty);
    });

    test('hasMore 生成游标，loadMore 只请求对应页码', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        builtinSource(
          id: 'builtin.comic',
          name: '漫画规则',
          type: MediaType.comic,
          enabled: true,
          priority: 0,
        ),
      ]);
      addTearDown(sources.close);
      final service = _FakeSearchService(
        pages: const <String, SearchPage>{
          'builtin.comic#1': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c1', title: '漫画 1')],
            hasMore: true,
          ),
          'builtin.comic#2': SearchPage(
            items: <SearchResult>[SearchResult(id: 'c2', title: '漫画 2')],
          ),
        },
      );
      final repository = RuleWorkSearchRepository(sources, service);

      final first = await repository.search('关键词');
      expect(first.cursors, <RulePageCursor>[
        const RulePageCursor(ruleId: 'builtin.comic', page: 2),
      ]);
      expect(first.hasMore, isTrue);

      service.calls.clear();
      final more = await repository.loadMore('关键词', first.cursors);

      expect(service.calls, <({String ruleId, int page, String keyword})>[
        (ruleId: 'builtin.comic', page: 2, keyword: '关键词'),
      ]);
      expect(more.groups.single.ruleId, 'builtin.comic');
      expect(more.groups.single.items.map((item) => item.id), <String>['c2']);
      expect(more.cursors, isEmpty);
    });

    test('游标为空时不再发起请求', () async {
      final sources = FakeRuleSourceRepository(<RuleSource>[
        builtinSource(
          id: 'builtin.comic',
          name: '漫画规则',
          type: MediaType.comic,
          enabled: true,
          priority: 0,
        ),
      ]);
      addTearDown(sources.close);
      final service = _FakeSearchService();

      final page = await RuleWorkSearchRepository(
        sources,
        service,
      ).loadMore('关键词', const <RulePageCursor>[]);

      expect(page.groups, isEmpty);
      expect(service.calls, isEmpty);
    });
  });
}

class _FakeSearchService implements RuleSearchService {
  _FakeSearchService({
    this.pages = const <String, SearchPage>{},
    this.pageFailures = const <String>{},
  });

  /// `ruleId#page` → 该页结果；未声明的页码视为空页。
  final Map<String, SearchPage> pages;

  /// `ruleId#page` → 该页请求失败。
  final Set<String> pageFailures;

  final List<({String ruleId, int page, String keyword})> calls =
      <({String ruleId, int page, String keyword})>[];

  @override
  Future<SearchPage> search(RulePack pack, {String keyword = '', int page = 1}) async {
    calls.add((ruleId: pack.id, page: page, keyword: keyword));
    final key = '${pack.id}#$page';
    if (pageFailures.contains(key)) {
      throw const NetworkException('boom');
    }
    return pages[key] ?? const SearchPage(items: <SearchResult>[]);
  }
}
