import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';

class FakeDiscoverFeedRepository implements DiscoverFeedRepository {
  FakeDiscoverFeedRepository([this.feed = DiscoverFeed.empty]);

  DiscoverFeed feed;

  /// 追加页返回的内容；默认空 chunk 表示已经到底。
  DiscoverFeedChunk chunk = DiscoverFeedChunk.empty;
  Object? loadError;
  Object? loadMoreError;
  int loadCount = 0;
  int loadMoreCount = 0;
  List<RulePageCursor> lastCursors = const <RulePageCursor>[];

  @override
  Future<DiscoverFeed> load() async {
    loadCount++;
    final error = loadError;
    if (error != null) {
      throw error;
    }
    return feed;
  }

  @override
  Future<DiscoverFeedChunk> loadMore(List<RulePageCursor> cursors) async {
    loadMoreCount++;
    lastCursors = cursors;
    final error = loadMoreError;
    if (error != null) {
      throw error;
    }
    return chunk;
  }
}

DiscoverItem discoverItem({
  required String id,
  required String title,
  MediaType type = MediaType.anime,
  RuleSourceOrigin origin = RuleSourceOrigin.builtin,
  bool adult = false,
  String? cover,
}) => DiscoverItem(
  ruleId: 'rule.$id',
  ruleName: 'Rule $id',
  type: type,
  origin: origin,
  adult: adult,
  id: id,
  title: title,
  cover: cover,
);

DiscoverFailure discoverFailure(String ruleId) => DiscoverFailure(ruleId: ruleId, ruleName: ruleId);

DiscoverFeed discoverFeed({
  List<DiscoverItem> items = const <DiscoverItem>[],
  List<DiscoverFailure> failures = const <DiscoverFailure>[],
  int? sourceCount,
  int? searchableSourceCount,
  List<RulePageCursor> cursors = const <RulePageCursor>[],
}) => DiscoverFeed(
  items: items,
  failures: failures,
  sourceCount: sourceCount ?? (items.isEmpty ? 0 : 1),
  searchableSourceCount: searchableSourceCount ?? (items.isEmpty ? 0 : 1),
  cursors: cursors,
);
