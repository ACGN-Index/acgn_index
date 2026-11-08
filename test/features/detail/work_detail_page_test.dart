import 'package:acgn_index/app/router/app_destinations.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
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
}

Future<void> _pump(
  WidgetTester tester,
  _FakeWorkRepository repository, {
  DiscoverItem? item = _defaultItem,
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
      overrides: [workRepositoryProvider.overrideWithValue(repository)],
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

WorkView _work({
  Set<RuleCapability> capabilities = const <RuleCapability>{
    RuleCapability.detail,
    RuleCapability.toc,
    RuleCapability.content,
  },
}) => WorkView(
  item: _defaultItem,
  source: _source(capabilities),
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

RuleSource _source(Set<RuleCapability> capabilities) => RuleSource(
  pack: RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: const RuleMeta(
      id: 'rule.test',
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
  _FakeWorkRepository(this.work, {this.launch});

  final WorkView work;
  final ViewerLaunch? launch;
  var loadChapterCount = 0;

  @override
  Future<WorkView> loadWork(DiscoverItem item) async => work;

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
