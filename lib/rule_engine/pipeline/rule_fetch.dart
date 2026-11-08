import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_document.dart';

/// 发送请求并按响应内容解析成 JSON / HTML / XML 文档。
Future<RuleDocument> fetchRuleDocument(
  RuleHttpClient httpClient,
  RuleHttpRequest request,
) async {
  final response = await httpClient.send(request);
  if (!response.isSuccess) {
    throw NetworkException('请求失败：HTTP ${response.statusCode}');
  }
  return RuleDocument.parse(
    response.body,
    uri: response.uri,
    headers: response.headers,
  );
}
