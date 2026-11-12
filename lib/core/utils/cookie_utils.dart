/// 解析 `name=value; name2=value2` 形式的 Cookie 头。
Map<String, String> parseCookieHeader(String source) {
  final result = <String, String>{};
  for (final part in source.split(';')) {
    final trimmed = part.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final index = trimmed.indexOf('=');
    if (index <= 0) {
      continue;
    }
    final name = trimmed.substring(0, index).trim();
    if (name.isEmpty) {
      continue;
    }
    result[name] = trimmed.substring(index + 1).trim();
  }
  return result;
}

/// 把 Cookie 键值对格式化为请求头值。
String formatCookieHeader(Map<String, String> cookies) => cookies.entries
    .where((entry) => entry.key.trim().isNotEmpty)
    .map((entry) => '${entry.key.trim()}=${entry.value}')
    .join('; ');
