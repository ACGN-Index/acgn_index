import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/viewer_chapter_source.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';

/// 一集视频：播放源 + 该集的弹幕。
class VideoEpisode {
  const VideoEpisode({
    required this.title,
    required this.media,
    this.danmaku = const <DanmakuComment>[],
  });

  final String title;
  final ViewerMedia media;
  final List<DanmakuComment> danmaku;
}

/// 视频查看器的入参。
class VideoViewerContent {
  const VideoViewerContent({
    required this.title,
    required this.episodes,
    this.subtitle,
    this.chapterTitle,
    this.initialEpisodeIndex = 0,
    this.chapterSource,
    this.initialChapterKey,
  });

  final String title;
  final String? subtitle;

  /// 当前章节（集）的标题；弹幕库按它匹配集数。
  final String? chapterTitle;

  final List<VideoEpisode> episodes;
  final int initialEpisodeIndex;

  /// 整部作品的目录；为空时只能在当前章节的线路间切换。
  final ViewerChapterSource? chapterSource;

  final String? initialChapterKey;

  int get safeInitialEpisodeIndex {
    if (episodes.isEmpty || initialEpisodeIndex < 0) {
      return 0;
    }
    return initialEpisodeIndex >= episodes.length ? episodes.length - 1 : initialEpisodeIndex;
  }
}
