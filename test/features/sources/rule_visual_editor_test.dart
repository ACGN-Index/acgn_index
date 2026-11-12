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

  Future<void> pumpEditor(WidgetTester tester, {RuleSource? source}) async {
    await tester.pumpWidget(
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
    await tester.pumpAndSettle();
  }

  Future<void> openSection(WidgetTester tester, String label) async {
    await tester.tap(find.widgetWithText(ChoiceChip, label));
    await tester.pumpAndSettle();
  }

  Future<String> readJsonText(WidgetTester tester) async {
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    return tester.widget<TextField>(find.byType(TextField)).controller!.text;
  }

  testWidgets('可视化编辑会同步到 JSON', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(find.byKey(const ValueKey<String>('visual.meta.name')), '改过的名字');
    await tester.pumpAndSettle();

    final text = await readJsonText(tester);
    expect(text, contains('"name": "改过的名字"'));
  });

  testWidgets('可以在可视化模式启用和关闭能力', (tester) async {
    await pumpEditor(tester);
    await openSection(tester, '搜索');

    final toggle = find.byKey(const ValueKey<String>('visual.search.enabled'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    var text = await readJsonText(tester);
    expect(text, isNot(contains('"search":')));

    await tester.tap(find.text('可视化'));
    await tester.pumpAndSettle();
    await openSection(tester, '搜索');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    text = await readJsonText(tester);
    expect(text, contains('"search":'));
    expect(text, contains('"selector": ""'));
  });

  testWidgets('字段规则可以用表单编辑', (tester) async {
    await pumpEditor(tester);
    await openSection(tester, '搜索');

    final row = find.byKey(const ValueKey<String>('search.title'));
    await tester.ensureVisible(row);
    await tester.tap(find.descendant(of: row, matching: find.byIcon(Icons.edit_outlined)));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('fieldRule.value')),
      '.book-title',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    final text = await readJsonText(tester);
    expect(text, contains('".book-title"'));
  });

  testWidgets('各分区与可选配置都能渲染', (tester) async {
    Future<void> enableCapability(String key) async {
      final toggle = find.byKey(ValueKey<String>('visual.$key.enabled'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
    }

    await pumpEditor(tester);

    await openSection(tester, '请求设置');

    await openSection(tester, '搜索');
    final indexChip = find.widgetWithText(ChoiceChip, '本地索引');
    await tester.ensureVisible(indexChip);
    await tester.tap(indexChip);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('远程分页'));
    await tester.tap(find.text('远程分页'));
    await tester.pumpAndSettle();

    await openSection(tester, '详情');
    await enableCapability('detail');

    await openSection(tester, '目录');
    await enableCapability('toc');
    final group = find.text('分组映射');
    await tester.ensureVisible(group);
    await tester.tap(group);
    await tester.pumpAndSettle();

    await openSection(tester, '正文');
    await enableCapability('content');
    final resolve = find.text('二段请求');
    await tester.ensureVisible(resolve);
    await tester.tap(resolve);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('只读规则的可视化视图仍可滚动', (tester) async {
    final builtin = builtinSource(
      id: 'builtin.demo',
      name: 'Demo',
      type: MediaType.comic,
      enabled: true,
      priority: 0,
    );
    await repository.save(builtin);
    await pumpEditor(tester, source: builtin);

    final scrollable = find
        .descendant(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);

    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
  });

  testWidgets('JSON 语法错误时停留在 JSON 模式', (tester) async {
    await pumpEditor(tester);

    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '{');
    await tester.pumpAndSettle();

    await tester.tap(find.text('可视化'));
    await tester.pumpAndSettle();

    expect(find.textContaining('JSON 语法错误'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('添加字段后直接进入字段编辑', (tester) async {
    await pumpEditor(tester);
    await openSection(tester, '搜索');

    final addButton = find.text('添加字段');
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'author',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '添加'));
    await tester.pumpAndSettle();

    expect(find.text('编辑字段「author」'), findsOneWidget);
    await tester.tap(find.text('完成'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('search.author')), findsOneWidget);

    final text = await readJsonText(tester);
    expect(text, contains('"author":'));
  });

  testWidgets('可以启用并配置登录', (tester) async {
    await pumpEditor(tester);
    await openSection(tester, '登录');

    final toggle = find.byKey(const ValueKey<String>('visual.login.enabled'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();

    var text = await readJsonText(tester);
    expect(text, contains('"login":'));
    expect(text, contains('"mode": "webview"'));

    await tester.tap(find.text('可视化'));
    await tester.pumpAndSettle();
    await openSection(tester, '登录');
    await tester.tap(find.text('手动请求头'));
    await tester.pumpAndSettle();

    text = await readJsonText(tester);
    expect(text, contains('"mode": "headers"'));
  });
}
