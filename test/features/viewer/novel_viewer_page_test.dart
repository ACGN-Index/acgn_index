import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/features/viewer/novel_viewer_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget page) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  );
}

const NovelViewerContent _content = NovelViewerContent(
  title: '测试小说',
  chapters: <NovelChapter>[
    NovelChapter(id: 'c1', title: '第一章', paragraphs: <String>['第一段。', '第二段。']),
    NovelChapter(id: 'c2', title: '第二章', paragraphs: <String>['第二章正文。']),
  ],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('缺少内容参数时展示提示', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: _wrap(const NovelViewerPage())),
    );
    await tester.pump();

    expect(find.text('缺少内容参数，请从详情页重新进入。'), findsOneWidget);
  });

  testWidgets('展示章节正文并可以切换章节', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: _wrap(const NovelViewerPage(content: _content))),
    );
    await tester.pumpAndSettle();

    expect(find.text('第一章'), findsWidgets);
    expect(find.text('第一段。'), findsOneWidget);

    await tester.tap(find.text('下一章'));
    await tester.pumpAndSettle();

    expect(find.text('第二章正文。'), findsOneWidget);
  });
}
