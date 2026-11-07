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
  });

  final String title;
  final List<ComicChapter> chapters;
  final int initialChapterIndex;

  int get safeInitialChapterIndex {
    if (chapters.isEmpty || initialChapterIndex < 0) {
      return 0;
    }
    return initialChapterIndex >= chapters.length ? chapters.length - 1 : initialChapterIndex;
  }
}
