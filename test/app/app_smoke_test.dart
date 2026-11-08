import 'package:acgn_index/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('启动后进入发现页', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AcgnIndexApp()));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('搜索、榜单与分类将在规则引擎接入后开放。'), findsOneWidget);
  });

  testWidgets('可以切换到收藏页并展示空状态', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AcgnIndexApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('收藏'));
    await tester.pumpAndSettle();

    expect(find.text('收藏还是空的'), findsOneWidget);
  });

  testWidgets('可以切换到我的页并展示许可证信息', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AcgnIndexApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的'));
    await tester.pumpAndSettle();

    expect(find.text('GPL-3.0'), findsOneWidget);
  });
}
