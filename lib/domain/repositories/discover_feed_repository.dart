import 'package:acgn_index/domain/entities/discover_feed.dart';

/// 发现页数据入口：聚合所有启用规则的搜索结果。
abstract interface class DiscoverFeedRepository {
  Future<DiscoverFeed> load();
}
