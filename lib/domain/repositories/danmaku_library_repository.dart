import 'package:acgn_index/domain/entities/danmaku_comment.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';

/// 外部弹幕库（弹弹play 兼容 API）的读取入口。
abstract interface class DanmakuLibraryRepository {
  /// 按作品标题搜索弹幕库条目。
  Future<List<DanmakuLibraryAnime>> searchEpisodes({
    required String keyword,
    required DanmakuLibraryConfig config,
  });

  /// 拉取某一集的弹幕。
  Future<List<DanmakuComment>> fetchComments({
    required int episodeId,
    required DanmakuLibraryConfig config,
  });
}
