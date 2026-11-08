import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/features/sources/sources_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sources_test_helpers.dart';

void main() {
  late FakeRuleSourceRepository repository;

  setUp(() {
    repository = FakeRuleSourceRepository(<RuleSource>[
      builtinSource(
        id: 'builtin.bangumi.anime',
        name: 'Bangumi 番组计划（资料）',
        type: MediaType.anime,
        enabled: true,
        priority: 0,
      ),
      builtinSource(
        id: 'builtin.bangumi.comic',
        name: 'Bangumi 番组计划（漫画资料）',
        type: MediaType.comic,
        enabled: true,
        priority: 1,
      ),
      builtinSource(
        id: 'builtin.lnovel.novel',
        name: 'LNovel（日轻中文文本）',
        type: MediaType.novel,
        enabled: false,
        priority: 2,
      ),
    ]);
  });

  tearDown(() => repository.close());

  Future<void> pumpPage(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [ruleSourceRepositoryProvider.overrideWithValue(repository)],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourcesPage(),
      ),
    ),
  );

  testWidgets('规则页展示内置规则集并可切换启用状态', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.text('内置规则集'), findsOneWidget);
    expect(find.textContaining('Bangumi 番组计划（资料）'), findsOneWidget);
    expect(find.textContaining('LNovel'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(3));

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    final sources = await repository.getAll();
    expect(sources.where((source) => source.enabled), hasLength(1));
  });

  testWidgets('右下角提供添加规则入口', (tester) async {
    await pumpPage(tester);
    await tester.pumpAndSettle();

    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });
}
