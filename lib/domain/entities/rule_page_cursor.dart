/// 分页游标：某条规则下一次要请求的页码。
///
/// 发现聚合与跨规则搜索都是「每条规则各自翻页」，因此游标按规则保存，
/// 请求时只针对仍有下一页的规则继续拉取。
class RulePageCursor {
  const RulePageCursor({required this.ruleId, required this.page});

  final String ruleId;

  /// 下一次请求的页码；已经请求过的页码不再重复请求。
  final int page;

  @override
  bool operator ==(Object other) =>
      other is RulePageCursor && other.ruleId == ruleId && other.page == page;

  @override
  int get hashCode => Object.hash(ruleId, page);

  @override
  String toString() => 'RulePageCursor($ruleId, page: $page)';
}
