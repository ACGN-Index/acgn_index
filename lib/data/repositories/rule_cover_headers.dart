import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/data/repositories/rule_auth_headers.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';

/// 封面等远程素材需要的请求头：规则包级 → 搜索能力级 → 本地登录凭据。
Map<String, String> ruleCoverHeaders(RuleSource source, RuleAuth? auth) {
  final headers = <String, String>{'User-Agent': AppConstants.defaultUserAgent};
  void merge(Map<String, String> sourceHeaders) {
    for (final entry in sourceHeaders.entries) {
      final key = entry.key.toLowerCase();
      if (key == 'accept' || key == 'content-type') {
        continue;
      }
      final existing = headers.keys.where((header) => header.toLowerCase() == key).firstOrNull;
      headers[existing ?? entry.key] = entry.value;
    }
  }

  merge(source.pack.request.headers);
  final search = source.pack.capabilities[RuleCapability.search];
  if (search != null) {
    merge(search.headers);
  }
  return mergeAuthHeaders(headers, auth?.toRequestHeaders() ?? const <String, String>{});
}
