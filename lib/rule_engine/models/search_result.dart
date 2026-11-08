/// `search` 能力产出的单个作品。
class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    this.cover,
    this.author,
    this.subtitle,
    this.url,
    this.extra = const <String, Object?>{},
  });

  final String id;
  final String title;

  /// 封面绝对地址；规则未声明时为 null。
  final String? cover;

  final String? author;
  final String? subtitle;

  /// 作品详情页绝对地址；规则未声明时为 null。
  final String? url;

  /// 规则声明的其它字段，保留原始求值结果。
  final Map<String, Object?> extra;
}

/// 一页搜索结果。
class SearchPage {
  const SearchPage({
    required this.items,
    this.totalItems,
    this.hasMore = false,
  });

  final List<SearchResult> items;

  /// 规则声明了总条数时可用。
  final int? totalItems;

  /// 是否还有下一页；未知时为 `items.length == pageSize` 的推断值。
  final bool hasMore;
}
