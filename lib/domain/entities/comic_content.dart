import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';

/// 一个漫画章节：标题 + 按阅读顺序排列的图片。
class ComicChapter {
  const ComicChapter({required this.id, required this.title, required this.pages});

  final String id;
  final String title;
  final List<ViewerMedia> pages;
}

/// 漫画查看器的入参。
class ComicViewerContent {
  const ComicViewerContent({
    required this.title,
    required this.chapters,
    this.initialChapterIndex = 0,
    this.chapterSource,
    this.initialChapterKey,
  });

  final String title;
  final List<ComicChapter> chapters;
  final int initialChapterIndex;

  /// 整部作品的目录；为空时只能翻阅已加载的章节。
  final ViewerChapterSource? chapterSource;

  final String? initialChapterKey;

  int get safeInitialChapterIndex {
    if (chapters.isEmpty || initialChapterIndex < 0) {
      return 0;
    }
    return initialChapterIndex >= chapters.length ? chapters.length - 1 : initialChapterIndex;
  }
}
