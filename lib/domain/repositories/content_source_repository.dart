import 'package:acgn_index/domain/entities/content_source.dart';

/// 详情页的跨源检索入口：在具备正文能力的规则中查找同一作品。
abstract interface class ContentSourceRepository {
  /// 检索所有候选来源，按来源返回各自的状态与命中作品。
  Future<ContentSourceResult> search(ContentSourceQuery query);

  /// 用指定检索词重新检索单个来源（对应 Kazumi 的「修改此来源的检索词」）。
  Future<ContentSourceGroup?> refreshProvider(
    ContentSourceQuery query, {
    required String ruleId,
    required String keyword,
  });
}
