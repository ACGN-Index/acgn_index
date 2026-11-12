import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/content_source.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/domain/repositories/content_source_repository.dart';
import 'package:acgn_index/domain/repositories/work_repository.dart';
import 'package:acgn_index/features/detail/work_detail_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('展示详情、标签、分组目录', (tester) async {
    final repository = _FakeWorkRepository(_work());
    await _pump(tester, repository);

    expect(find.text('作品A'), findsWidgets);
    expect(find.textContaining('作者A'), findsOneWidget);
    expect(find.text('第一段\n第二段'), findsOneWidget);
    expect(find.text('tag1'), findsOneWidget);
    expect(find.text('第一卷'), findsOneWidget);
    expect(find.text('第一章'), findsOneWidget);
    expect(find.text('第二章'), findsOneWidget);
  });

  testWidgets('没有 content 能力时提示仅资料并禁用章节', (tester) async {
    final repository = _FakeWorkRepository(
      _work(capabilities: const <RuleCapability>{RuleCapability.detail, RuleCapability.toc}),
    );
    await _pump(tester, repository);

    expect(find.text('该源仅提供资料，没有正文。'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('第一章'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('第一章'));
    await tester.pumpAndSettle();
    expect(repository.loadChapterCount, 0);
  });

  testWidgets('点击章节加载内容并打开对应查看器', (tester) async {
    final repository = _FakeWorkRepository(
      _work(),
      launch: const NovelViewerLaunch(
        NovelViewerContent(
          title: '作品A',
          chapters: <NovelChapter>[
            NovelChapter(id: 'c1', title: '第一章', paragraphs: <String>['正文']),
          ],
        ),
      ),
    );
    await _pump(tester, repository);

    await tester.tap(find.text('第一章'));
    await tester.pumpAndSettle();

    expect(repository.loadChapterCount, 1);
    expect(find.text('novel-viewer'), findsOneWidget);
  });

  testWidgets('缺少作品参数时展示提示', (tester) async {
    await _pump(tester, _FakeWorkRepository(_work()), item: null);

    expect(find.text('缺少作品参数，请从发现页重新进入。'), findsOneWidget);
  });

  testWidgets('仅资料源默认展开内容来源，点击结果切换来源', (tester) async {
    final repository = _FakeWorkRepository(
      _work(capabilities: const <RuleCapability>{RuleCapability.detail, RuleCapability.toc}),
      works: <String, WorkView>{_providerItem.ruleId: _work(item: _providerItem)},
    );
    final contentSources = _FakeContentSourceRepository(result: _result());
    await _pump(tester, repository, contentSources: contentSources);

    expect(find.text('内容来源'), findsOneWidget);
    expect(find.text('1 个来源 · 1 个结果'), findsOneWidget);
    expect(find.text('资源站'), findsWidgets);
    expect(find.text('来源作品'), findsOneWidget);
    expect(find.text('该源仅提供资料，没有正文。'), findsOneWidget);

    await tester.tap(find.text('来源作品'));
    await tester.pumpAndSettle();

    expect(find.text('内容来源'), findsOneWidget);
    expect(find.text('该源仅提供资料，没有正文。'), findsNothing);

    await tester.tap(find.text('第一章'));
    await tester.pumpAndSettle();
    expect(repository.loadChapterCount, 1);
  });

  testWidgets('有正文能力的详情页显示折叠的内容来源，展开后可见结果', (tester) async {
    final repository = _FakeWorkRepository(
      _work(),
      works: <String, WorkView>{_providerItem.ruleId: _work(item: _providerItem)},
    );
    final contentSources = _FakeContentSourceRepository(result: _result());
    await _pump(tester, repository, contentSources: contentSources);

    expect(find.text('内容来源'), findsOneWidget);
    expect(find.text('1 个来源 · 1 个结果'), findsOneWidget);
    expect(find.text('来源作品'), findsNothing);

    await tester.tap(find.text('内容来源'));
    await tester.pumpAndSettle();

    expect(find.text('资源站'), findsWidgets);
    expect(find.text('来源作品'), findsOneWidget);
  });

  testWidgets('内容来源检索失败时可重试', (tester) async {
    final contentSources = _FakeContentSourceRepository(
      error: const NetworkException('boom'),
    );
    await _pump(
      tester,
      _FakeWorkRepository(
        _work(capabilities: const <RuleCapability>{RuleCapability.detail, RuleCapability.toc}),
      ),
      contentSources: contentSources,
    );

    expect(find.text('内容来源检索失败，请稍后重试。'), findsWidgets);
    await tester.tap(find.text('重试').first);
    await tester.pumpAndSettle();
    expect(contentSources.searchCount, 2);
  });

  testWidgets('可以修改单个来源的检索词并重新检索', (tester) async {
    final contentSources = _FakeContentSourceRepository(
      result: const ContentSourceResult(
        groups: <ContentSourceGroup>[
          ContentSourceGroup(
            ruleId: 'rule.provider',
            ruleName: '资源站',
            keyword: '作品A',
          ),
        ],
      ),
      refreshed: const ContentSourceGroup(
        ruleId: 'rule.provider',
        ruleName: '资源站',
        keyword: '关键词B',
        items: <DiscoverItem>[_providerItem],
        status: ContentSourceStatus.ok,
      ),
    );
    await _pump(
      tester,
      _FakeWorkRepository(
        _work(capabilities: const <RuleCapability>{RuleCapability.detail, RuleCapability.toc}),
      ),
      contentSources: contentSources,
    );

    expect(find.text('没有结果'), findsOneWidget);
    await tester.tap(find.text('修改检索词').first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '关键词B');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(contentSources.refreshCount, 1);
    expect(contentSources.lastKeyword, '关键词B');
    expect(find.text('检索词：关键词B'), findsOneWidget);
    expect(find.text('来源作品'), findsOneWidget);
  });
}

Future<void> _pump(
  WidgetTester tester,
  _FakeWorkRepository repository, {
  DiscoverItem? item = _defaultItem,
  ContentSourceRepository? contentSources,
}) async {
  final router = GoRouter(
    initialLocation: AppRoutes.workDetail,
    routes: <RouteBase>[
      GoRoute(
        path: AppRoutes.workDetail,
        builder: (context, state) => WorkDetailPage(item: item),
      ),
      GoRoute(
        path: AppRoutes.novelViewer,
        builder: (context, state) => const Text('novel-viewer'),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        workRepositoryProvider.overrideWithValue(repository),
        contentSourceRepositoryProvider.overrideWithValue(
          contentSources ?? _FakeContentSourceRepository(),
        ),
      ],
      child: MaterialApp.router(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const DiscoverItem _defaultItem = DiscoverItem(
  ruleId: 'rule.test',
  ruleName: 'Test',
  type: MediaType.comic,
  origin: RuleSourceOrigin.imported,
  adult: false,
  id: '42',
  title: '作品A',
  author: '作者A',
);

const DiscoverItem _providerItem = DiscoverItem(
  ruleId: 'rule.provider',
  ruleName: '资源站',
  type: MediaType.comic,
  origin: RuleSourceOrigin.imported,
  adult: false,
  id: 'p1',
  title: '来源作品',
);

ContentSourceResult _result() => const ContentSourceResult(
  groups: <ContentSourceGroup>[
    ContentSourceGroup(
      ruleId: 'rule.provider',
      ruleName: '资源站',
      keyword: '作品A',
      items: <DiscoverItem>[_providerItem],
      status: ContentSourceStatus.ok,
    ),
  ],
);

WorkView _work({
  DiscoverItem item = _defaultItem,
  Set<RuleCapability> capabilities = const <RuleCapability>{
    RuleCapability.detail,
    RuleCapability.toc,
    RuleCapability.content,
  },
}) => WorkView(
  item: item,
  source: _source(capabilities, id: item.ruleId),
  detail: const WorkDetail(
    title: '作品A',
    fields: <String, Object?>{
      'author': '作者A',
      'intro': '<p>第一段</p><p>第二段</p>',
      'tags': <String>['tag1'],
    },
  ),
  toc: const TocResult(
    entries: <TocEntry>[
      TocEntry(
        id: 'c2',
        title: '第二章',
        order: 2,
        group: 'v1',
        groupTitle: '第一卷',
      ),
      TocEntry(id: 'c1', title: '第一章', order: 1, group: 'v1', groupTitle: '第一卷'),
    ],
  ),
);

RuleSource _source(Set<RuleCapability> capabilities, {String id = 'rule.test'}) => RuleSource(
  pack: RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: RuleMeta(
      id: id,
      name: 'Test',
      type: MediaType.comic,
      baseUrl: 'https://example.invalid',
      version: '1.0.0',
      author: 'tester',
      lang: 'zh',
    ),
    capabilities: <RuleCapability, CapabilityRule>{
      RuleCapability.detail: const DetailCapabilityRule(url: '/work/{{id}}'),
      RuleCapability.toc: const TocCapabilityRule(url: '/toc/{{id}}'),
      if (capabilities.contains(RuleCapability.content))
        RuleCapability.content: const ContentCapabilityRule(
          mode: ContentMode.images,
          url: '/content/{{chapter.id}}',
        ),
    },
  ),
  enabled: true,
  installedAt: DateTime(2026),
);

class _FakeWorkRepository implements WorkRepository {
  _FakeWorkRepository(this.work, {this.launch, this.works = const <String, WorkView>{}});

  final WorkView work;
  final Map<String, WorkView> works;
  final ViewerLaunch? launch;
  var loadChapterCount = 0;

  @override
  Future<WorkView> loadWork(DiscoverItem item) async => works[item.ruleId] ?? work;

  @override
  Future<ViewerLaunch> loadChapter(WorkView work, TocEntry chapter) async {
    loadChapterCount++;
    return launch ??
        const NovelViewerLaunch(
          NovelViewerContent(
            title: '作品A',
            chapters: <NovelChapter>[
              NovelChapter(id: 'c1', title: '第一章', paragraphs: <String>['正文']),
            ],
          ),
        );
  }
}

class _FakeContentSourceRepository implements ContentSourceRepository {
  _FakeContentSourceRepository({
    this.result = ContentSourceResult.empty,
    this.error,
    this.refreshed,
  });

  final ContentSourceResult result;
  final Object? error;
  final ContentSourceGroup? refreshed;
  var searchCount = 0;
  var refreshCount = 0;
  String? lastKeyword;

  @override
  Future<ContentSourceResult> search(ContentSourceQuery query) async {
    searchCount++;
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    return result;
  }

  @override
  Future<ContentSourceGroup?> refreshProvider(
    ContentSourceQuery query, {
    required String ruleId,
    required String keyword,
  }) async {
    refreshCount++;
    lastKeyword = keyword;
    return refreshed;
  }
}
