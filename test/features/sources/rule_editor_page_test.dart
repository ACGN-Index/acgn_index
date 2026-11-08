import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/features/sources/rule_editor_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'sources_test_helpers.dart';

void main() {
  late FakeRuleSourceRepository repository;

  setUp(() => repository = FakeRuleSourceRepository());

  tearDown(() => repository.close());

  Future<void> pumpEditor(WidgetTester tester, {RuleSource? source}) => tester.pumpWidget(
    ProviderScope(
      overrides: [ruleSourceRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: RuleEditorPage(source: source),
      ),
    ),
  );

  Future<void> switchToJson(WidgetTester tester) async {
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
  }

  Future<void> replaceContent(WidgetTester tester, String text) async {
    await switchToJson(tester);
    await tester.enterText(find.byType(TextField), text);
    await tester.pumpAndSettle();
  }

  testWidgets('新建规则默认填入可以通过校验的骨架', (tester) async {
    await pumpEditor(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('规则编辑器'), findsOneWidget);
    expect(find.text('可视化'), findsOneWidget);
    expect(find.text('基础信息'), findsWidgets);

    await tester.tap(find.byIcon(Icons.fact_check_outlined));
    await tester.pumpAndSettle();

    expect(find.text('校验通过，可以保存'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
  });

  testWidgets('校验失败时列出错误位置', (tester) async {
    await pumpEditor(tester);
    await tester.pumpAndSettle();

    await replaceContent(
      tester,
      '{"schemaVersion":1,"meta":{"id":"","name":"x","type":"comic",'
      '"baseUrl":"https://example.invalid","version":"1.0.0"},'
      '"capabilities":{"search":{"url":"/s?q={{key}}",'
      '"fields":{"title":{"selector":".t"}}}}}',
    );

    await tester.tap(find.byIcon(Icons.fact_check_outlined));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsWidgets);
    expect(find.textContaining('meta.id'), findsOneWidget);
  });

  testWidgets('保存后写入已导入规则', (tester) async {
    await pumpEditor(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final sources = await repository.getAll();
    expect(sources, hasLength(1));
    expect(sources.single.id, 'user.my.rule');
    expect(sources.single.origin, RuleSourceOrigin.imported);
    expect(sources.single.enabled, isTrue);
  });

  testWidgets('内置规则只读，可另存为副本', (tester) async {
    final builtin = builtinSource(
      id: 'builtin.demo',
      name: 'Demo',
      type: MediaType.comic,
      enabled: true,
      priority: 0,
    );
    await repository.save(builtin);

    await pumpEditor(tester, source: builtin);
    await tester.pumpAndSettle();

    expect(find.text('内置规则为只读，可另存为已导入规则后再修改。'), findsOneWidget);

    await switchToJson(tester);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);

    await tester.tap(find.text('另存为新规则'));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isFalse);
    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    final sources = await repository.getAll();
    expect(sources.map((source) => source.id), contains('builtin.demo.副本'));
  });
}
