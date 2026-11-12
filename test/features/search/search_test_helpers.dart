import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_page_cursor.dart';
import 'package:acgn_index/domain/entities/work_search.dart';
import 'package:acgn_index/domain/repositories/work_search_repository.dart';

class FakeWorkSearchRepository implements WorkSearchRepository {
  FakeWorkSearchRepository({
    this.page = WorkSearchPage.empty,
    this.more = WorkSearchPage.empty,
  });

  WorkSearchPage page;
  WorkSearchPage more;
  Object? searchError;
  Object? loadMoreError;
  int searchCount = 0;
  int loadMoreCount = 0;
  String? lastKeyword;
  List<RulePageCursor> lastCursors = const <RulePageCursor>[];

  @override
  Future<WorkSearchPage> search(String keyword) async {
    searchCount++;
    lastKeyword = keyword;
    final error = searchError;
    if (error != null) {
      throw error;
    }
    return page;
  }

  @override
  Future<WorkSearchPage> loadMore(String keyword, List<RulePageCursor> cursors) async {
    loadMoreCount++;
    lastKeyword = keyword;
    lastCursors = cursors;
    final error = loadMoreError;
    if (error != null) {
      throw error;
    }
    return more;
  }
}

WorkSearchGroup searchGroup({
  required String ruleId,
  required String ruleName,
  MediaType type = MediaType.comic,
  List<DiscoverItem> items = const <DiscoverItem>[],
  WorkSearchStatus status = WorkSearchStatus.ok,
}) => WorkSearchGroup(
  ruleId: ruleId,
  ruleName: ruleName,
  type: type,
  adult: false,
  items: items,
  status: status,
);
