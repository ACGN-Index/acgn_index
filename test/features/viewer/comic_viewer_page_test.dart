import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/features/viewer/comic_viewer_page.dart';
import 'package:acgn_index/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget page) {
  return MaterialApp(
    locale: const Locale('zh'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: page,
  );
}

void main() {
  testWidgets('缺少内容参数时展示提示', (tester) async {
    await tester.pumpWidget(_wrap(const ComicViewerPage()));
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

    await tester.pumpWidget(_wrap(const ComicViewerPage(content: content)));
    await tester.pump();

    expect(find.text('测试漫画'), findsOneWidget);
    expect(find.text('第 1 话'), findsOneWidget);
    expect(find.text('本章暂无图片'), findsOneWidget);
  });
}
