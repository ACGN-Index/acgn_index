import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';

/// 跨源检索请求：在同类资源提供者中查找同一作品。
class ContentSourceQuery {
  const ContentSourceQuery({
    required this.type,
    required this.title,
    this.aliases = const <String>[],
    this.excludeRuleId,
  });

  final MediaType type;

  /// 首选关键词，通常是详情页标题。
  final String title;

  /// 首选关键词没有命中时依次尝试的别名。
  final List<String> aliases;

  /// 当前详情页所属规则；该规则不参与检索。
  final String? excludeRuleId;
}

/// 单个来源的检索状态。
enum ContentSourceStatus {
  /// 检索到至少一条结果。
  ok,

  /// 请求成功但没有匹配结果。
  noResult,

  /// 请求失败（网络、规则或站点异常）。
  failed,
}

/// 一个资源提供者的检索结果，对应 Kazumi 的「来源」分组。
class ContentSourceGroup {
  const ContentSourceGroup({
    required this.ruleId,
    required this.ruleName,
    required this.keyword,
    this.items = const <DiscoverItem>[],
    this.status = ContentSourceStatus.noResult,
  });

  final String ruleId;
  final String ruleName;

  /// 产出这批结果的检索词；用户改过检索词时与详情页标题不同。
  final String keyword;

  final List<DiscoverItem> items;
  final ContentSourceStatus status;

  bool get hasResults => items.isNotEmpty;
}

/// 一次跨源检索的结果：按来源分组的检索状态与命中作品。
class ContentSourceResult {
  const ContentSourceResult({required this.groups});

  static const ContentSourceResult empty = ContentSourceResult(
    groups: <ContentSourceGroup>[],
  );

  final List<ContentSourceGroup> groups;

  int get providerCount => groups.length;

  int get resultCount => groups.fold<int>(0, (sum, group) => sum + group.items.length);

  int get failureCount =>
      groups.where((group) => group.status == ContentSourceStatus.failed).length;

  bool get isEmpty => resultCount == 0;

  /// 用单个来源的最新结果替换同 id 分组，其余保持顺序不变。
  ContentSourceResult replaceGroup(ContentSourceGroup group) => ContentSourceResult(
    groups: <ContentSourceGroup>[
      for (final candidate in groups)
        if (candidate.ruleId == group.ruleId) group else candidate,
    ],
  );
}
