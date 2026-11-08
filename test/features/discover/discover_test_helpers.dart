import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/discover_feed.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';

class FakeDiscoverFeedRepository implements DiscoverFeedRepository {
  FakeDiscoverFeedRepository([this.feed = DiscoverFeed.empty]);

  DiscoverFeed feed;
  int loadCount = 0;

  @override
  Future<DiscoverFeed> load() async {
    loadCount++;
    return feed;
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
}) => DiscoverFeed(
  items: items,
  failures: failures,
  sourceCount: sourceCount ?? (items.isEmpty ? 0 : 1),
  searchableSourceCount: searchableSourceCount ?? (items.isEmpty ? 0 : 1),
);
