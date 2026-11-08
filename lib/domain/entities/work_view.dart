import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';

/// 详情页所需的一次加载结果：规则源 + 详情 + 目录。
class WorkView {
  const WorkView({
    required this.item,
    required this.source,
    required this.detail,
    required this.toc,
  });

  final DiscoverItem item;
  final RuleSource source;
  final WorkDetail detail;
  final TocResult toc;

  String get title => detail.title.isNotEmpty ? detail.title : item.title;

  MediaType get type => source.type;

  bool get canOpenChapter => source.pack.supports(RuleCapability.content);
}
