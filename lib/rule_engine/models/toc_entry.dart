/// 目录中的一个条目：剧集、分卷章节或单章文件。
class TocEntry {
  const TocEntry({
    this.id,
    required this.title,
    this.url,
    this.order,
    this.group,
    this.groupTitle,
    this.duration,
    this.airdate,
    this.extra = const <String, Object?>{},
  });

  /// 章节 id；只有 `url` 的规则可能为 null。
  final String? id;

  final String title;

  /// 章节页绝对地址；规则未声明时为 null。
  final String? url;

  final int? order;

  /// 分组 id，例如分卷 id。
  final String? group;

  /// 分组展示名，例如分卷标题。
  final String? groupTitle;

  final String? duration;
  final String? airdate;

  /// 规则声明的其它字段（如 EPUB 的 `file`、`size`），保留原始求值结果。
  final Map<String, Object?> extra;

  String get key => id ?? url ?? title;

  bool get hasGroup => (groupTitle ?? group)?.isNotEmpty ?? false;
}

/// 一次 `toc` 请求或扇出后的完整目录。
class TocResult {
  const TocResult({this.entries = const <TocEntry>[]});

  static const TocResult empty = TocResult();

  final List<TocEntry> entries;

  bool get isEmpty => entries.isEmpty;

  /// 按分组首次出现顺序切分；未分组条目归入标题为空的组。
  List<TocGroup> get groups {
    final result = <TocGroup>[];
    final indexes = <String, int>{};
    for (final entry in entries) {
      final title = entry.groupTitle ?? entry.group ?? '';
      final index = indexes[title];
      if (index == null) {
        indexes[title] = result.length;
        result.add(TocGroup(title: title, entries: <TocEntry>[entry]));
      } else {
        result[index].entries.add(entry);
      }
    }
    return result;
  }
}

/// 目录分组；[title] 为空表示未分组。
class TocGroup {
  TocGroup({required this.title, required this.entries});

  final String title;
  final List<TocEntry> entries;
}
