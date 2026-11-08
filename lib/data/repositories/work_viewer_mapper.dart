import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/domain/entities/video_content.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/viewer_media.dart';
import 'package:acgn_index/rule_engine/models/rule_content.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';

/// 把引擎的正文结果映射为现有查看器入参。
///
/// 漫画 / 小说一次只携带当前章节；视频把每条线路映射为一集。
ViewerLaunch mapRuleContent(
  RuleContent content, {
  required String workTitle,
  required TocEntry chapter,
}) => switch (content) {
  final ImagesContent imagesContent => ComicViewerLaunch(
    ComicViewerContent(
      title: workTitle,
      chapters: <ComicChapter>[
        ComicChapter(
          id: chapter.key,
          title: chapter.title,
          pages: imagesContent.images
              .map((image) => ViewerMedia(uri: image.uri, headers: image.headers))
              .toList(growable: false),
        ),
      ],
    ),
  ),
  final TextContent textContent => NovelViewerLaunch(
    NovelViewerContent(
      title: workTitle,
      chapters: <NovelChapter>[
        NovelChapter(
          id: chapter.key,
          title: chapter.title,
          paragraphs: textContent.paragraphs,
        ),
      ],
    ),
  ),
  final VideoContent videoContent => VideoViewerLaunch(
    VideoViewerContent(
      title: workTitle,
      subtitle: chapter.groupTitle,
      episodes: <VideoEpisode>[
        for (var index = 0; index < videoContent.sources.length; index++)
          VideoEpisode(
            title: _episodeTitle(
              chapter.title,
              videoContent.sources[index],
              index,
              videoContent.sources.length,
            ),
            media: ViewerMedia(
              uri: videoContent.sources[index].uri,
              headers: videoContent.headers,
            ),
          ),
      ],
    ),
  ),
  final FileContent fileContent => FileViewerLaunch(
    url: fileContent.url,
    format: fileContent.format,
    headers: fileContent.headers,
  ),
};

String _episodeTitle(String chapterTitle, VideoSource source, int index, int count) {
  if (count <= 1) {
    return chapterTitle;
  }
  final label = source.quality ?? source.type ?? '线路 ${index + 1}';
  return '$chapterTitle · $label';
}
