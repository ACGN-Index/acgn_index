/// 一个小说章节：标题 + 已切成段落的正文。
class NovelChapter {
  const NovelChapter({required this.id, required this.title, required this.paragraphs});

  final String id;
  final String title;
  final List<String> paragraphs;
}

/// 小说查看器的入参。
class NovelViewerContent {
  const NovelViewerContent({
    required this.title,
    required this.chapters,
    this.initialChapterIndex = 0,
  });

  final String title;
  final List<NovelChapter> chapters;
  final int initialChapterIndex;

  int get safeInitialChapterIndex {
    if (chapters.isEmpty || initialChapterIndex < 0) {
      return 0;
    }
    return initialChapterIndex >= chapters.length ? chapters.length - 1 : initialChapterIndex;
  }
}
