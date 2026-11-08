import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';

class FakeReply {
  const FakeReply(
    this.body, {
    this.statusCode = 200,
    this.headers = const <String, String>{'content-type': 'application/json'},
  });

  final String body;
  final int statusCode;
  final Map<String, String> headers;
}

class FakeHttpClient implements RuleHttpClient {
  FakeHttpClient(this.replies);

  final List<FakeReply> replies;
  final List<RuleHttpRequest> requests = <RuleHttpRequest>[];
  var _index = 0;

  @override
  Future<RuleHttpResponse> send(RuleHttpRequest request) async {
    requests.add(request);
    final reply = replies[_index++];
    return RuleHttpResponse(
      statusCode: reply.statusCode,
      body: reply.body,
      uri: request.uri,
      headers: reply.headers,
    );
  }
}

RulePack testPack({
  required Map<RuleCapability, CapabilityRule> capabilities,
  String baseUrl = 'https://api.test',
  List<String> allowedHosts = const <String>[],
  Map<String, String> requestHeaders = const <String, String>{},
}) => RulePack(
  schemaVersion: kSupportedSchemaVersion,
  meta: RuleMeta(
    id: 'test.pack',
    name: 'Test',
    type: MediaType.comic,
    baseUrl: baseUrl,
    version: '1.0.0',
    author: 'tester',
    lang: 'zh',
    allowedHosts: allowedHosts,
  ),
  request: RequestRule(headers: requestHeaders),
  capabilities: capabilities,
);
