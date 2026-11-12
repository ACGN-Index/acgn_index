import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/template_renderer.dart';

/// 把规则声明渲染成可发送的 HTTP 请求，并执行 host 白名单检查。
class RuleRequestBuilder {
  const RuleRequestBuilder();

  RuleHttpRequest build({
    required RulePack pack,
    required String url,
    required String method,
    String? body,
    Map<String, String> headers = const <String, String>{},
    required Map<String, Object?> variables,
  }) {
    final renderedUrl = renderTemplate(url, variables);
    final uri = _resolveUri(pack, renderedUrl);
    if (!isHostAllowed(pack, uri.host)) {
      throw NetworkException('规则未允许访问主机：${uri.host}');
    }
    final mergedHeaders = <String, String>{'User-Agent': AppConstants.defaultUserAgent};
    _mergeHeaders(mergedHeaders, pack.request.headers);
    _mergeHeaders(mergedHeaders, headers);
    return RuleHttpRequest(
      uri: uri,
      method: method.toUpperCase(),
      headers: mergedHeaders,
      body: body == null ? null : renderTemplate(body, variables),
      timeout: pack.request.timeout,
      retry: pack.request.retry,
      encoding: pack.request.encoding,
      ruleId: pack.id,
    );
  }

  Uri _resolveUri(RulePack pack, String url) {
    final parsed = Uri.tryParse(url);
    if (parsed == null) {
      throw RuleFormatException('请求地址不是合法 URL：$url');
    }
    final base = Uri.tryParse(pack.meta.baseUrl);
    if (base == null) {
      throw RuleFormatException('规则 baseUrl 不是合法 URL：${pack.meta.baseUrl}');
    }
    final resolved = parsed.hasScheme ? parsed : base.resolveUri(parsed);
    if (!resolved.isScheme('http') && !resolved.isScheme('https')) {
      throw RuleFormatException('请求地址必须是 http(s)：$url');
    }
    return resolved;
  }

  void _mergeHeaders(Map<String, String> target, Map<String, String> source) {
    for (final entry in source.entries) {
      final existing = target.keys
          .where((key) => key.toLowerCase() == entry.key.toLowerCase())
          .firstOrNull;
      target[existing ?? entry.key] = entry.value;
    }
  }
}

/// 目标主机必须是 `baseUrl` 主机及其子域，或 `allowedHosts` 中声明的主机。
bool isHostAllowed(RulePack pack, String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty) {
    return false;
  }
  final baseHost = Uri.tryParse(pack.meta.baseUrl)?.host.toLowerCase() ?? '';
  if (baseHost.isNotEmpty && _matchesHost(normalized, baseHost)) {
    return true;
  }
  for (final allowed in pack.meta.allowedHosts) {
    final parsed = Uri.tryParse(allowed);
    final candidate = parsed != null && parsed.host.isNotEmpty
        ? parsed.host.toLowerCase()
        : allowed.toLowerCase();
    if (candidate.isNotEmpty && _matchesHost(normalized, candidate)) {
      return true;
    }
  }
  return false;
}

bool _matchesHost(String host, String allowed) => host == allowed || host.endsWith('.$allowed');
