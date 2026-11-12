import 'package:acgn_index/app/app.dart';
import 'package:acgn_index/data/providers.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/discover/discover_test_helpers.dart';
import '../features/search/search_test_helpers.dart';
import '../features/sources/sources_test_helpers.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    final sourceRepository = FakeRuleSourceRepository(<RuleSource>[]);
    addTearDown(sourceRepository.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          discoverFeedRepositoryProvider.overrideWithValue(
            FakeDiscoverFeedRepository(),
          ),
          ruleSourceRepositoryProvider.overrideWithValue(sourceRepository),
          workSearchRepositoryProvider.overrideWithValue(
            FakeWorkSearchRepository(),
          ),
        ],
        child: const AcgnIndexApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('启动后进入发现页', (tester) async {
    await pumpApp(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('还没有启用的规则源'), findsOneWidget);
  });

  testWidgets('可以切换到收藏页并展示空状态', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('收藏还是空的'), findsOneWidget);
  });

  testWidgets('可以切换到我的页并展示许可证信息', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('GPL-3.0'), findsOneWidget);
  });

  testWidgets('发现页搜索入口打开跨规则搜索页', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();

    expect(find.text('跨规则搜索作品'), findsOneWidget);
  });
}
