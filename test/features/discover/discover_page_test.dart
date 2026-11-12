import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/features/discover/discover_page.dart';
import 'package:acgn_index/features/discover/discover_work_card.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../sources/sources_test_helpers.dart';
import 'discover_test_helpers.dart';

void main() {
  SliverGridDelegateWithFixedCrossAxisCount gridDelegateOf(WidgetTester tester) =>
      tester.widget<SliverGrid>(find.byType(SliverGrid)).gridDelegate
          as SliverGridDelegateWithFixedCrossAxisCount;

  Future<FakeDiscoverFeedRepository> pumpPage(
    WidgetTester tester,
    DiscoverFeed feed, {
    DiscoverFeedChunk chunk = DiscoverFeedChunk.empty,
  }) async {
    final feedRepository = FakeDiscoverFeedRepository(feed)..chunk = chunk;
    final sourceRepository = FakeRuleSourceRepository(<RuleSource>[]);
    addTearDown(sourceRepository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverFeedRepositoryProvider.overrideWithValue(feedRepository),
          ruleSourceRepositoryProvider.overrideWithValue(sourceRepository),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: DiscoverPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return feedRepository;
  }

  testWidgets('作品卡片点击触发回调', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              height: 300,
              child: DiscoverWorkCard(
                item: discoverItem(id: 'a', title: '作品 A'),
                onTap: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('作品 A'));

    expect(taps, 1);
  });

  testWidgets('窄屏作品网格至少三列', (tester) async {
    tester.view.physicalSize = const Size(380, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          discoverItem(id: 'a', title: '作品 A'),
          discoverItem(id: 'b', title: '作品 B'),
          discoverItem(id: 'c', title: '作品 C'),
          discoverItem(id: 'd', title: '作品 D'),
        ],
      ),
    );

    expect(gridDelegateOf(tester).crossAxisCount, 3);
    expect(find.byType(DiscoverWorkCard), findsNWidgets(4));
  });

  testWidgets('宽屏作品网格随宽度增加列数', (tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          discoverItem(id: 'a', title: '作品 A'),
          discoverItem(id: 'b', title: '作品 B'),
        ],
      ),
    );

    expect(gridDelegateOf(tester).crossAxisCount, greaterThan(3));
  });

  testWidgets('展示作品卡片、类型徽标与成人徽标', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          discoverItem(id: 'a', title: '作品 A'),
          discoverItem(
            id: 'b',
            title: '作品 B',
            type: MediaType.novel,
            adult: true,
          ),
        ],
      ),
    );

    expect(find.byType(DiscoverWorkCard), findsNWidgets(2));
    expect(find.text('作品 A'), findsOneWidget);
    expect(find.text('作品 B'), findsOneWidget);
    expect(find.text('动漫'), findsOneWidget);
    expect(find.text('小说'), findsOneWidget);
    expect(find.text('成人'), findsOneWidget);
  });

  testWidgets('左上角筛选面板按类型与来源过滤', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          discoverItem(id: 'a', title: '作品 A'),
          discoverItem(
            id: 'b',
            title: '作品 B',
            type: MediaType.comic,
            origin: RuleSourceOrigin.imported,
          ),
        ],
      ),
    );

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();
    expect(find.text('筛选'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, '漫画'));
    await tester.tap(find.widgetWithText(ChoiceChip, '已导入'));
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();

    expect(find.text('作品 A'), findsNothing);
    expect(find.text('作品 B'), findsOneWidget);
  });

  testWidgets('筛选无结果时可以重置筛选', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[discoverItem(id: 'a', title: '作品 A')],
      ),
    );

    await tester.tap(find.text('发现'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '漫画'));
    await tester.tap(find.widgetWithText(FilledButton, '应用'));
    await tester.pumpAndSettle();

    expect(find.text('当前筛选下没有内容'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, '重置筛选'));
    await tester.pumpAndSettle();

    expect(find.text('作品 A'), findsOneWidget);
  });

  testWidgets('无启用规则时展示空状态与规则入口', (tester) async {
    await pumpPage(tester, DiscoverFeed.empty);

    expect(find.text('还没有启用的规则源'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, '前往规则'), findsOneWidget);
  });

  testWidgets('没有可搜索规则时展示对应空状态', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(sourceCount: 1, searchableSourceCount: 0),
    );

    expect(find.text('没有可发现的内容'), findsOneWidget);
  });

  testWidgets('全部规则失败时展示错误状态', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        failures: <DiscoverFailure>[discoverFailure('rule.a')],
        sourceCount: 1,
        searchableSourceCount: 1,
      ),
    );

    expect(find.text('内容加载失败'), findsOneWidget);
    expect(find.text('1 个规则加载失败'), findsOneWidget);
  });

  testWidgets('部分规则失败时保留作品并展示提示', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[discoverItem(id: 'a', title: '作品 A')],
        failures: <DiscoverFailure>[discoverFailure('rule.b')],
        sourceCount: 2,
        searchableSourceCount: 2,
      ),
    );

    expect(find.text('作品 A'), findsOneWidget);
    expect(find.text('1 个规则加载失败'), findsOneWidget);
  });

  testWidgets('右上角是搜索入口，不再有刷新按钮', (tester) async {
    await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[discoverItem(id: 'a', title: '作品 A')],
      ),
    );

    expect(find.byIcon(Icons.search), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsNothing);
  });

  testWidgets('下拉刷新重新加载第一页', (tester) async {
    final repository = await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          for (var index = 0; index < 30; index++)
            discoverItem(id: 'work.$index', title: '作品 $index'),
        ],
      ),
    );
    expect(repository.loadCount, 1);

    await tester.fling(find.byType(CustomScrollView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(repository.loadCount, 2);
  });

  testWidgets('内容不足一屏时自动加载下一页', (tester) async {
    final repository = await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          for (var index = 0; index < 4; index++)
            discoverItem(id: 'work.$index', title: '作品 $index'),
        ],
        cursors: const <RulePageCursor>[
          RulePageCursor(ruleId: 'rule.work.0', page: 2),
        ],
      ),
      chunk: DiscoverFeedChunk(
        items: <DiscoverItem>[discoverItem(id: 'more', title: '更多作品')],
        failures: const <DiscoverFailure>[],
        cursors: const <RulePageCursor>[],
      ),
    );

    expect(repository.loadMoreCount, 1);
    expect(find.text('更多作品'), findsOneWidget);
    expect(find.text('没有更多内容了'), findsOneWidget);
  });

  testWidgets('滚动到底部加载下一页', (tester) async {
    final repository = await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          for (var index = 0; index < 30; index++)
            discoverItem(id: 'work.$index', title: '作品 $index'),
        ],
        cursors: const <RulePageCursor>[
          RulePageCursor(ruleId: 'rule.work.0', page: 2),
        ],
      ),
    );
    expect(repository.loadMoreCount, 0);
    expect(find.text('没有更多内容了'), findsNothing);

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(repository.loadMoreCount, 1);
    expect(repository.lastCursors, <RulePageCursor>[
      const RulePageCursor(ruleId: 'rule.work.0', page: 2),
    ]);
    await tester.scrollUntilVisible(
      find.text('没有更多内容了'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('没有更多内容了'), findsOneWidget);
  });

  testWidgets('加载更多失败后可以手动重试', (tester) async {
    final repository = await pumpPage(
      tester,
      discoverFeed(
        items: <DiscoverItem>[
          for (var index = 0; index < 30; index++)
            discoverItem(id: 'work.$index', title: '作品 $index'),
        ],
        cursors: const <RulePageCursor>[
          RulePageCursor(ruleId: 'rule.work.0', page: 2),
        ],
      ),
    );
    repository.loadMoreError = StateError('boom');

    await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
    await tester.pumpAndSettle();

    expect(repository.loadMoreCount, 1);
    await tester.scrollUntilVisible(
      find.widgetWithText(TextButton, '重试'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('加载更多失败'), findsOneWidget);

    repository.loadMoreError = null;
    await tester.ensureVisible(find.widgetWithText(TextButton, '重试'));
    await tester.tap(find.widgetWithText(TextButton, '重试'));
    await tester.pumpAndSettle();

    expect(repository.loadMoreCount, 2);
    expect(find.text('没有更多内容了'), findsOneWidget);
  });
}
