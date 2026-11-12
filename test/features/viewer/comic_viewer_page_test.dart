import 'package:acgn_index/app/window/window_title.dart';
import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/comic_viewer_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget page) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  );
}

/// 返回按写入顺序记录的窗口标题。
Future<List<String>> _pump(WidgetTester tester, {ComicViewerContent? content}) async {
  final titles = <String>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        windowTitleControllerProvider.overrideWithValue(
          WindowTitleController(apply: (title) async => titles.add(title)),
        ),
      ],
      child: _wrap(ComicViewerPage(content: content)),
    ),
  );
  return titles;
}

void main() {
  testWidgets('缺少内容参数时展示提示', (tester) async {
    await _pump(tester);
    await tester.pump();

    expect(find.text('缺少内容参数，请从详情页重新进入。'), findsOneWidget);
  });

  testWidgets('章节没有图片时展示空提示并保留章节信息', (tester) async {
    const content = ComicViewerContent(
      title: '测试漫画',
      chapters: <ComicChapter>[
        ComicChapter(id: 'c1', title: '第 1 话', pages: <ViewerMedia>[]),
      ],
    );

    final titles = await _pump(tester, content: content);
    await tester.pump();

    expect(find.text('测试漫画'), findsOneWidget);
    expect(find.text('第 1 话'), findsOneWidget);
    expect(find.text('本章暂无图片'), findsOneWidget);
    expect(titles.last, '测试漫画 - 第 1 话');
  });

  testWidgets('切换章节后窗口标题跟随当前章节', (tester) async {
    const content = ComicViewerContent(
      title: '测试漫画',
      chapters: <ComicChapter>[
        ComicChapter(id: 'c1', title: '第 1 话', pages: <ViewerMedia>[]),
        ComicChapter(id: 'c2', title: '第 2 话', pages: <ViewerMedia>[]),
      ],
    );

    final titles = await _pump(tester, content: content);
    await tester.pump();

    expect(titles.last, '测试漫画 - 第 1 话');

    await tester.tap(find.text('下一章'));
    await tester.pumpAndSettle();

    expect(titles.last, '测试漫画 - 第 2 话');
  });
}
