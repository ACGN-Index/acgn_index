import 'package:acgn_index/core/utils/title_match.dart';
import 'package:acgn_index/domain/entities/danmaku_library.dart';

/// 从章节标题里解析集数，用于在弹幕库里定位同一集。
///
/// 支持「第12集 / 第12话 / EP12 / S1E12 / 12」等常见写法；
/// 解析不到时返回 null，由调用方按顺序兜底。
int? parseEpisodeNumber(String title) {
  final text = _normalizeDigits(title).toLowerCase();
  if (text.isEmpty) {
    return null;
  }
  final patterns = <RegExp>[
    RegExp(r's\d+\s*e\s*(\d+)'),
    RegExp(r'第\s*(\d+(?:\.\d+)?)\s*[话話集回期]'),
    RegExp(r'(?:episode|ep|e)\s*\.?\s*(\d+)'),
    RegExp(r'^\s*(\d+)\s*$'),
  ];
  for (final pattern in patterns) {
    final value = pattern.firstMatch(text)?.group(1);
    final parsed = value == null ? null : num.tryParse(value);
    if (parsed != null) {
      return parsed.floor();
    }
  }
  return null;
}

/// 在搜索结果里挑最贴近作品标题的一部。
///
/// 完全匹配优先，其次是包含关系；同分时标题更短、剧集更多的优先。
/// 一个都匹配不上时返回 null，避免把弹幕挂到无关作品上。
DanmakuLibraryAnime? pickAnime(List<DanmakuLibraryAnime> animes, String workTitle) {
  DanmakuLibraryAnime? best;
  var bestRank = 0;
  var bestLength = 1 << 30;
  var bestEpisodes = -1;
  for (final anime in animes) {
    final rank = titleMatchRank(anime.title, workTitle);
    if (rank == 0) {
      continue;
    }
    final length = normalizeTitle(anime.title).length;
    final better =
        rank > bestRank ||
        (rank == bestRank && length < bestLength) ||
        (rank == bestRank && length == bestLength && anime.episodes.length > bestEpisodes);
    if (better) {
      best = anime;
      bestRank = rank;
      bestLength = length;
      bestEpisodes = anime.episodes.length;
    }
  }
  return best;
}

/// 按集数挑选剧集；集数未知时取第一条，按序号兜底时取第 number 条。
DanmakuLibraryEpisode? pickEpisode(List<DanmakuLibraryEpisode> episodes, {int? number}) {
  if (episodes.isEmpty) {
    return null;
  }
  if (number == null) {
    return episodes.first;
  }
  for (final episode in episodes) {
    if (parseEpisodeNumber(episode.title) == number) {
      return episode;
    }
  }
  if (number > 0 && number <= episodes.length) {
    return episodes[number - 1];
  }
  return episodes.first;
}

String _normalizeDigits(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final halfWidth = rune >= 0xFF10 && rune <= 0xFF19 ? rune - 0xFEE0 : rune;
    buffer.writeCharCode(halfWidth);
  }
  return buffer.toString();
}
