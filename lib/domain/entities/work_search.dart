import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';

/// 单条规则的跨规则搜索状态。
enum WorkSearchStatus {
  /// 检索到至少一条结果。
  ok,

  /// 请求成功但没有结果。
  noResult,

  /// 请求失败（网络、规则或站点异常）。
  failed,
}

/// 跨规则搜索中一条规则的结果分组。
class WorkSearchGroup {
  const WorkSearchGroup({
    required this.ruleId,
    required this.ruleName,
    required this.type,
    required this.adult,
    this.items = const <DiscoverItem>[],
    this.status = WorkSearchStatus.noResult,
  });

  final String ruleId;
  final String ruleName;
  final MediaType type;

  /// 规则 `meta.adult`，搜索页据此显示成人徽标。
  final bool adult;

  final List<DiscoverItem> items;
  final WorkSearchStatus status;

  bool get hasResults => items.isNotEmpty;

  /// 追加同一规则的下一页结果；追加到内容后状态即为 [WorkSearchStatus.ok]。
  WorkSearchGroup appendItems(List<DiscoverItem> more) => WorkSearchGroup(
    ruleId: ruleId,
    ruleName: ruleName,
    type: type,
    adult: adult,
    items: <DiscoverItem>[...items, ...more],
    status: items.isEmpty && more.isEmpty ? status : WorkSearchStatus.ok,
  );
}

/// 跨规则搜索的一页结果：按规则分组，并带上各规则的下一页游标。
class WorkSearchPage {
  const WorkSearchPage({
    required this.groups,
    this.cursors = const <RulePageCursor>[],
  });

  static const WorkSearchPage empty = WorkSearchPage(groups: <WorkSearchGroup>[]);

  final List<WorkSearchGroup> groups;

  /// 仍有下一页的规则游标；为空表示已经到底。
  final List<RulePageCursor> cursors;

  bool get hasMore => cursors.isNotEmpty;

  int get resultCount => groups.fold<int>(0, (sum, group) => sum + group.items.length);
}
