import 'package:acgn_index/domain/entities/viewer_launch.dart';

/// 目录中的一个章节引用；查看器据此列出整部作品的章节。
class ViewerChapterRef {
  const ViewerChapterRef({
    required this.key,
    required this.title,
    this.groupTitle,
    this.order,
  });

  final String key;
  final String title;

  /// 分组标题，例如分卷名；为空表示未分组。
  final String? groupTitle;

  final int? order;

  bool get hasGroup => (groupTitle ?? '').isNotEmpty;
}

/// 查看器的章节入口：既提供整部作品的目录，也负责按需抓取单章内容。
///
/// 内容仍在规则流水线里实时抓取，查看器只持有引用，不缓存正文。
abstract interface class ViewerChapterSource {
  List<ViewerChapterRef> get chapters;

  Future<ViewerLaunch> load(ViewerChapterRef chapter);
}
