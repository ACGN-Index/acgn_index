import 'package:acgn_index/domain/entities/comic_content.dart';
import 'package:acgn_index/domain/entities/novel_content.dart';
import 'package:acgn_index/domain/entities/video_content.dart';

/// 一次章节抓取后要打开的查看器。
sealed class ViewerLaunch {
  const ViewerLaunch();
}

final class ComicViewerLaunch extends ViewerLaunch {
  const ComicViewerLaunch(this.content);

  final ComicViewerContent content;
}

final class NovelViewerLaunch extends ViewerLaunch {
  const NovelViewerLaunch(this.content);

  final NovelViewerContent content;
}

final class VideoViewerLaunch extends ViewerLaunch {
  const VideoViewerLaunch(this.content);

  final VideoViewerContent content;
}

/// EPUB / TXT 等文件：当前不内置文件阅读器，交由页面提示或复制地址。
final class FileViewerLaunch extends ViewerLaunch {
  const FileViewerLaunch({
    required this.url,
    required this.format,
    this.headers = const <String, String>{},
  });

  final Uri url;
  final String format;
  final Map<String, String> headers;
}
