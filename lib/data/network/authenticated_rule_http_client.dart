import 'package:acgn_index/core/utils/cookie_utils.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';

/// 为规则请求注入本地保存的登录凭据。
///
/// 凭据由 [RuleAuthRepository] 按 `request.ruleId` 读取；本地认证头优先于
/// 规则包中声明的同名请求头。
class AuthenticatedRuleHttpClient implements RuleHttpClient, ClosableRuleHttpClient {
  AuthenticatedRuleHttpClient(this._inner, this._authRepository);

  final RuleHttpClient _inner;
  final RuleAuthRepository _authRepository;

  @override
  Future<RuleHttpResponse> send(RuleHttpRequest request) async {
    final ruleId = request.ruleId;
    if (ruleId == null) {
      return _inner.send(request);
    }
    final auth = await _authRepository.find(ruleId);
    if (auth == null || auth.isEmpty) {
      return _inner.send(request);
    }
    final headers = _mergeHeaders(request.headers, auth.toRequestHeaders());
    return _inner.send(request.copyWith(headers: headers));
  }

  @override
  Future<void> close() async {
    final inner = _inner;
    if (inner is ClosableRuleHttpClient) {
      await inner.close();
    }
  }
}

Map<String, String> _mergeHeaders(
  Map<String, String> base,
  Map<String, String> extra,
) {
  final result = <String, String>{...base};
  for (final entry in extra.entries) {
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
