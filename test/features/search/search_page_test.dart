import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/work_search.dart';
import 'package:acgn_index/features/discover/discover_work_card.dart';
import 'package:acgn_index/features/search/search_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../discover/discover_test_helpers.dart';
import 'search_test_helpers.dart';

void main() {
  Future<FakeWorkSearchRepository> pumpPage(
    WidgetTester tester, {
    WorkSearchPage page = WorkSearchPage.empty,
    WorkSearchPage more = WorkSearchPage.empty,
  }) async {
    final repository = FakeWorkSearchRepository(page: page, more: more);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workSearchRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SearchPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> search(WidgetTester tester, String keyword) async {
    await tester.enterText(find.byType(TextField), keyword);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  testWidgets('初始状态提示输入关键词', (tester) async {
    await pumpPage(tester);

    expect(find.text('跨规则搜索作品'), findsOneWidget);
    expect(find.byType(DiscoverWorkCard), findsNothing);
  });

  testWidgets('输入关键词后按规则分组展示作品', (tester) async {
    final repository = await pumpPage(
      tester,
      page: WorkSearchPage(
        groups: <WorkSearchGroup>[
          searchGroup(
            ruleId: 'rule.comic',
            ruleName: '漫画规则',
            items: <DiscoverItem>[discoverItem(id: 'c1', title: '漫画 1')],
          ),
          searchGroup(
            ruleId: 'rule.novel',
            ruleName: '小说规则',
            type: MediaType.novel,
            items: <DiscoverItem>[
              discoverItem(id: 'n1', title: '小说 1', type: MediaType.novel),
            ],
          ),
        ],
      ),
    );

    await search(tester, '作品');

    expect(repository.lastKeyword, '作品');
    expect(find.text('漫画规则'), findsOneWidget);
    expect(find.text('小说规则'), findsOneWidget);
    expect(find.text('1 个结果'), findsNWidgets(2));
    expect(find.text('漫画 1'), findsOneWidget);
    expect(find.text('小说 1'), findsOneWidget);
  });

  testWidgets('没有可搜索的规则时引导到规则页', (tester) async {
    await pumpPage(tester);

    await search(tester, '作品');

    expect(find.text('没有可搜索的规则'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '前往规则'), findsOneWidget);
  });

  testWidgets('搜索失败时展示错误与重试', (tester) async {
    final repository = await pumpPage(tester);
    repository.searchError = StateError('boom');

    await search(tester, '作品');

    expect(find.text('搜索失败'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '重试'), findsOneWidget);

    repository.searchError = null;
    repository.page = WorkSearchPage(
      groups: <WorkSearchGroup>[
        searchGroup(
          ruleId: 'rule.comic',
          ruleName: '漫画规则',
          items: <DiscoverItem>[discoverItem(id: 'c1', title: '漫画 1')],
        ),
      ],
    );
    await tester.tap(find.widgetWithText(FilledButton, '重试'));
    await tester.pumpAndSettle();

    expect(repository.searchCount, 2);
    expect(find.text('漫画 1'), findsOneWidget);
  });

  testWidgets('没有命中时展示空结果并可以重试', (tester) async {
    await pumpPage(
      tester,
      page: WorkSearchPage(
        groups: <WorkSearchGroup>[
          searchGroup(ruleId: 'rule.comic', ruleName: '漫画规则', status: WorkSearchStatus.noResult),
        ],
      ),
    );

    await search(tester, '作品');

    expect(find.text('没有找到作品'), findsOneWidget);
  });

  testWidgets('内容不足一屏时自动加载下一页并追加到分组', (tester) async {
    final repository = await pumpPage(
      tester,
      page: WorkSearchPage(
        groups: <WorkSearchGroup>[
          searchGroup(
            ruleId: 'rule.comic',
            ruleName: '漫画规则',
            items: <DiscoverItem>[discoverItem(id: 'c1', title: '漫画 1')],
          ),
        ],
        cursors: const <RulePageCursor>[
          RulePageCursor(ruleId: 'rule.comic', page: 2),
        ],
      ),
      more: WorkSearchPage(
        groups: <WorkSearchGroup>[
          searchGroup(
            ruleId: 'rule.comic',
            ruleName: '漫画规则',
            items: <DiscoverItem>[discoverItem(id: 'c2', title: '漫画 2')],
          ),
        ],
      ),
    );

    await search(tester, '作品');

    expect(repository.loadMoreCount, 1);
    expect(repository.lastCursors, <RulePageCursor>[
      const RulePageCursor(ruleId: 'rule.comic', page: 2),
    ]);
    expect(find.text('漫画 1'), findsOneWidget);
    expect(find.text('漫画 2'), findsOneWidget);
    expect(find.text('没有更多内容了'), findsOneWidget);
  });

  testWidgets('清空关键词回到初始提示', (tester) async {
    await pumpPage(
      tester,
      page: WorkSearchPage(
        groups: <WorkSearchGroup>[
          searchGroup(
            ruleId: 'rule.comic',
            ruleName: '漫画规则',
            items: <DiscoverItem>[discoverItem(id: 'c1', title: '漫画 1')],
          ),
        ],
      ),
    );

    await search(tester, '作品');
    expect(find.text('漫画 1'), findsOneWidget);

    await tester.tap(find.byTooltip('清空'));
    await tester.pumpAndSettle();

    expect(find.text('跨规则搜索作品'), findsOneWidget);
  });
}
