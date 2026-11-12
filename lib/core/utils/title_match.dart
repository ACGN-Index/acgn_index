/// 跨规则标题匹配用的规范化：只抹平稳定的书写差异，不改动展示文案。
///
/// 处理全角转半角、大小写、空白与常见标点/括号，使
/// 「【简中】葬送的芙莉莲 第一季」与「葬送的芙莉莲」可以相互匹配。
String normalizeTitle(String value) {
  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final code = rune == 0x3000 ? 0x20 : rune;
    final halfWidth = code >= 0xFF01 && code <= 0xFF5E ? code - 0xFEE0 : code;
    final char = String.fromCharCode(halfWidth);
    if (char.trim().isEmpty || _ignoredPunctuation.contains(char)) {
      continue;
    }
    buffer.write(char.toLowerCase());
  }
  return buffer.toString();
}

/// 标题相关度：2 = 完全一致，1 = 互相包含，0 = 不相关。
int titleMatchRank(String candidate, String query) {
  final normalizedQuery = normalizeTitle(query);
  final normalizedCandidate = normalizeTitle(candidate);
  if (normalizedQuery.isEmpty || normalizedCandidate.isEmpty) {
    return 0;
  }
  if (normalizedCandidate == normalizedQuery) {
    return 2;
  }
  if (normalizedCandidate.contains(normalizedQuery)) {
    return 1;
  }
  if (normalizedCandidate.length >= 2 && normalizedQuery.contains(normalizedCandidate)) {
    return 1;
  }
  return 0;
}

const Set<String> _ignoredPunctuation = <String>{
  '<',
  '>',
  '《',
  '》',
  '【',
  '】',
  '[',
  ']',
  '「',
  '」',
  '『',
  '』',
  '(',
  ')',
  '（',
  '）',
  '{',
  '}',
  ',',
  '，',
  '.',
  '。',
  '、',
  ':',
  '：',
  ';',
  '；',
  '!',
  '！',
  '?',
  '？',
  '-',
  '—',
  '_',
  '~',
  '～',
  '·',
  '•',
  '/',
  r'\',
  '|',
  '"',
  "'",
  '“',
  '”',
  '‘',
  '’',
  '+',
  '＋',
  '&',
  '＆',
};
