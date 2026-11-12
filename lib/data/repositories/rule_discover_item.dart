import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';

/// 把搜索结果映射为发现页作品条目；发现聚合、跨规则搜索与内容来源共用。
DiscoverItem discoverItemFrom(
  RuleSource source,
  SearchResult work,
  Map<String, String> coverHeaders,
) => DiscoverItem(
  ruleId: source.id,
  ruleName: source.name,
  type: source.type,
  origin: source.origin,
  adult: source.pack.meta.adult,
  id: work.id,
  title: work.title,
  cover: work.cover,
  coverHeaders: coverHeaders,
  author: work.author,
  subtitle: work.subtitle,
  url: work.url == null ? null : Uri.tryParse(work.url!),
  extra: work.extra,
);
