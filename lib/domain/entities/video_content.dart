import 'package:acgn_index/domain/entities/danmaku_comment.dart';
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
    this.initialEpisodeIndex = 0,
  });

  final String title;
  final String? subtitle;
  final List<VideoEpisode> episodes;
  final int initialEpisodeIndex;

  int get safeInitialEpisodeIndex {
    if (episodes.isEmpty || initialEpisodeIndex < 0) {
      return 0;
    }
    return initialEpisodeIndex >= episodes.length ? episodes.length - 1 : initialEpisodeIndex;
  }
}
