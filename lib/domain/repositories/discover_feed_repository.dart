import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';

/// 发现页数据入口：聚合所有启用规则的搜索结果。
abstract interface class DiscoverFeedRepository {
  /// 加载第一页聚合结果。
  Future<DiscoverFeed> load();

  /// 按游标继续加载仍有下一页的规则，返回这一页新增的内容。
  ///
  /// 只请求 [cursors] 中列出的规则与页码；游标为空时返回
  /// [DiscoverFeedChunk.empty]，调用方据此判断已经到底。
  Future<DiscoverFeedChunk> loadMore(List<RulePageCursor> cursors);
}
