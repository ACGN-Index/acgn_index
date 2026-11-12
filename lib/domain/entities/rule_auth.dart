/// 某个规则保存在本地的登录凭据。
///
/// 凭据只用于发起该规则的请求，不写入规则包、不参与导出，日志输出前必须脱敏。
class RuleAuth {
  const RuleAuth({
    required this.ruleId,
    this.cookies = const <String, String>{},
    this.headers = const <String, String>{},
    required this.updatedAt,
  });

  final String ruleId;
  final Map<String, String> cookies;
  final Map<String, String> headers;
  final DateTime updatedAt;

  bool get isEmpty => cookies.isEmpty && headers.isEmpty;

  /// 生成附加到规则请求的请求头。
  ///
  /// - [headers] 中的 `{{cookie.name}}` 会替换为本地 Cookie 值；
  /// - 值为空的请求头会被忽略；
  /// - [cookies] 会合并进 `Cookie` 头，并保留已有 Cookie 头中的其它项。
  Map<String, String> toRequestHeaders() {
    final result = <String, String>{};
    final cookiePattern = RegExp(r'\{\{\s*cookie\.([A-Za-z0-9_.\-]+)\s*\}\}');
    for (final entry in headers.entries) {
      final key = entry.key.trim();
      if (key.isEmpty) {
        continue;
      }
      final value = entry.value.replaceAllMapped(
        cookiePattern,
        (match) => cookies[match.group(1) ?? ''] ?? '',
      );
      if (value.isEmpty) {
        continue;
      }
      result[key] = value;
    }
    if (cookies.isNotEmpty) {
      final cookieKey = result.keys.where((key) => key.toLowerCase() == 'cookie').firstOrNull;
      result[cookieKey ?? 'Cookie'] = _mergeCookieHeader(
        cookieKey == null ? '' : result[cookieKey]!,
        cookies,
      );
    }
    return result;
  }
}

String _mergeCookieHeader(String existing, Map<String, String> cookies) {
  final values = <String, String>{};
  for (final part in existing.split(';')) {
    final index = part.indexOf('=');
    if (index <= 0) {
      continue;
    }
    values[part.substring(0, index).trim()] = part.substring(index + 1).trim();
  }
  values.addAll(cookies);
  return values.entries.map((entry) => '${entry.key}=${entry.value}').join('; ');
}
