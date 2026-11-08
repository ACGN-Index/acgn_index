import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';

/// 详情页的数据入口：组装详情/目录，并按需抓取单章内容。
abstract interface class WorkRepository {
  Future<WorkView> loadWork(DiscoverItem item);

  Future<ViewerLaunch> loadChapter(WorkView work, TocEntry chapter);
}
