import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/data/repositories/work_viewer_mapper.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/viewer_launch.dart';
import 'package:acgn_index/domain/entities/work_view.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/domain/repositories/work_repository.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/models/toc_entry.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:acgn_index/rule_engine/pipeline/content_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/detail_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/toc_pipeline.dart';

/// 编排规则引擎的三条流水线，供详情页使用。
class RuleWorkRepository implements WorkRepository {
  RuleWorkRepository(
    this._sources,
    this._detail,
    this._toc,
    this._content,
  );

  final RuleSourceRepository _sources;
  final RuleDetailService _detail;
  final RuleTocService _toc;
  final RuleContentService _content;

  @override
  Future<WorkView> loadWork(DiscoverItem item) async {
    final sources = await _sources.getAll();
    final source = sources.where((candidate) => candidate.id == item.ruleId).firstOrNull;
    if (source == null) {
      throw StorageException('规则不存在：${item.ruleId}');
    }
    final pack = source.pack;
    final workUrl = item.url?.toString();
    final searchResult = SearchResult(
      id: item.id,
      title: item.title,
      cover: item.cover,
      author: item.author,
      subtitle: item.subtitle,
      url: workUrl,
      extra: item.extra,
    );

    final detail = pack.supports(RuleCapability.detail)
        ? await _detail.fetch(pack, id: item.id, url: workUrl)
        : WorkDetail(
            title: item.title,
            url: workUrl,
            headers: item.coverHeaders,
            fields: <String, Object?>{
              if (item.cover != null) 'cover': item.cover,
              if (item.author != null) 'author': item.author,
              if (item.subtitle != null) 'subtitle': item.subtitle,
            },
          );

    final toc = pack.supports(RuleCapability.toc)
        ? await _toc.fetch(
            pack,
            id: item.id,
            url: detail.url ?? workUrl,
            detail: detail,
            searchResult: searchResult,
          )
        : TocResult.empty;

    return WorkView(item: item, source: source, detail: detail, toc: toc);
  }

  @override
  Future<ViewerLaunch> loadChapter(WorkView work, TocEntry chapter) async {
    final pack = work.source.pack;
    if (!pack.supports(RuleCapability.content)) {
      throw const UnsupportedCapabilityException('该规则仅提供资料，没有正文');
    }
    final content = await _content.fetch(
      pack,
      id: work.item.id,
      chapter: chapter,
      url: work.detail.url ?? work.item.url?.toString(),
    );
    return mapRuleContent(content, workTitle: work.title, chapter: chapter);
  }
}
