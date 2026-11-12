import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';

/// 发现页聚合出的单个作品。
class DiscoverItem {
  const DiscoverItem({
    required this.ruleId,
    required this.ruleName,
    required this.type,
    required this.origin,
    required this.adult,
    required this.id,
    required this.title,
    this.cover,
    this.coverHeaders = const <String, String>{},
    this.author,
    this.subtitle,
    this.url,
    this.extra = const <String, Object?>{},
  });

  final String ruleId;
  final String ruleName;
  final MediaType type;
  final RuleSourceOrigin origin;

  /// 规则 `meta.adult`，发现页据此显示徽标。
  final bool adult;

  /// 作品在该规则内的 id。
  final String id;

  final String title;
  final String? cover;

  /// 加载封面时需要携带的规则请求头。
  final Map<String, String> coverHeaders;

  final String? author;
  final String? subtitle;
  final Uri? url;

  /// 搜索规则声明的其它字段，例如 `toc.fanOutFrom: search.volumes` 需要的分卷。
  final Map<String, Object?> extra;

  String get key => '$ruleId:$id';

  bool get isBuiltin => origin == RuleSourceOrigin.builtin;
}

/// 单条规则加载失败的信息；UI 只展示数量。
class DiscoverFailure {
  const DiscoverFailure({required this.ruleId, required this.ruleName});

  final String ruleId;
  final String ruleName;
}

/// 发现页一次聚合的结果。
class DiscoverFeed {
  const DiscoverFeed({
    required this.items,
    required this.failures,
    required this.sourceCount,
    required this.searchableSourceCount,
    this.cursors = const <RulePageCursor>[],
  });

  static const DiscoverFeed empty = DiscoverFeed(
    items: <DiscoverItem>[],
    failures: <DiscoverFailure>[],
    sourceCount: 0,
    searchableSourceCount: 0,
  );

  final List<DiscoverItem> items;
  final List<DiscoverFailure> failures;

  /// 已启用的规则源数量。
  final int sourceCount;

  /// 其中有 `search` 能力的规则源数量。
  final int searchableSourceCount;

  /// 仍有下一页的规则及其下一页页码；为空表示已经到底。
  final List<RulePageCursor> cursors;

  bool get hasFailures => failures.isNotEmpty;

  bool get hasMore => cursors.isNotEmpty;
}

/// 分页追加的一批结果：新增条目、新增失败与下一轮游标。
///
/// 与 [DiscoverFeed] 分开是因为追加页只包含「这一页新增的内容」，
/// 规则源数量等信息不会重复计算。
class DiscoverFeedChunk {
  const DiscoverFeedChunk({
    required this.items,
    required this.failures,
    required this.cursors,
  });

  static const DiscoverFeedChunk empty = DiscoverFeedChunk(
    items: <DiscoverItem>[],
    failures: <DiscoverFailure>[],
    cursors: <RulePageCursor>[],
  );

  final List<DiscoverItem> items;
  final List<DiscoverFailure> failures;

  /// 下一轮仍有下一页的规则游标。
  final List<RulePageCursor> cursors;
}
