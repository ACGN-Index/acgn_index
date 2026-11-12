import 'package:acgn_index/core/utils/cookie_utils.dart';

/// 把登录凭据生成的请求头合并到已有请求头，同名键（忽略大小写）以认证头为准。
///
/// `Cookie` 头会按名称合并，保留规则包声明的 Cookie，同时让本地登录 Cookie 覆盖同名项。
Map<String, String> mergeAuthHeaders(
  Map<String, String> base,
  Map<String, String> authHeaders,
) {
  final result = <String, String>{...base};
  for (final entry in authHeaders.entries) {
    final existing = result.keys
        .where((key) => key.toLowerCase() == entry.key.toLowerCase())
        .firstOrNull;
    if (entry.key.toLowerCase() == 'cookie' && existing != null) {
      result[existing] = formatCookieHeader(<String, String>{
        ...parseCookieHeader(result[existing]!),
        ...parseCookieHeader(entry.value),
      });
      continue;
    }
    result[existing ?? entry.key] = entry.value;
  }
  return result;
}
