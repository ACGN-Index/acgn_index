import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/work_search.dart';

/// 跨规则搜索数据入口：用关键词并发检索所有启用的、具备 `search` 能力的规则。
abstract interface class WorkSearchRepository {
  /// 搜索关键词的第一页结果，按规则分组。
  ///
  /// 关键词去掉首尾空白后为空时返回 [WorkSearchPage.empty]，不发起请求。
  Future<WorkSearchPage> search(String keyword);

  /// 为仍有下一页的规则加载下一页，返回这一页各组的新增内容与下一轮游标。
  Future<WorkSearchPage> loadMore(
    String keyword,
    List<RulePageCursor> cursors,
  );
}
