import 'package:acgn_index/data/network/authenticated_rule_http_client.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final request = RuleHttpRequest(
    uri: Uri.parse('https://example.invalid/api'),
    ruleId: 'rule.test',
    headers: const <String, String>{'X-Base': '1', 'Cookie': 'existing=1'},
  );

  test('按 ruleId 注入 Cookie、认证头并展开 cookie 模板', () async {
    final inner = _RecordingClient();
    final client = AuthenticatedRuleHttpClient(
      inner,
      _FakeAuthRepository(
        RuleAuth(
          ruleId: 'rule.test',
          cookies: const <String, String>{'sid': 'abc', 'token': 't1'},
          headers: const <String, String>{
            'Authorization': 'Bearer {{cookie.token}}',
            'X-Empty': '',
            'X-Base': 'auth',
          },
          updatedAt: DateTime(2026),
        ),
      ),
    );

    await client.send(request);

    final headers = inner.last!.headers;
    expect(headers['Authorization'], 'Bearer t1');
    expect(headers['X-Base'], 'auth');
    expect(headers['X-Empty'], isNull);
    expect(headers['Cookie'], 'existing=1; sid=abc; token=t1');
    expect(inner.last!.ruleId, 'rule.test');
  });

  test('没有登录凭据时原样透传', () async {
    final inner = _RecordingClient();
    final client = AuthenticatedRuleHttpClient(inner, _FakeAuthRepository(null));

    await client.send(request);

    expect(inner.last!.headers, request.headers);
  });

  test('没有 ruleId 时原样透传', () async {
    final inner = _RecordingClient();
    final client = AuthenticatedRuleHttpClient(
      inner,
      _FakeAuthRepository(
        RuleAuth(
          ruleId: 'rule.test',
          cookies: const <String, String>{'sid': 'abc'},
          updatedAt: DateTime(2026),
        ),
      ),
    );

    await client.send(
      RuleHttpRequest(
        uri: Uri.parse('https://example.invalid/api'),
        headers: const <String, String>{'X-Base': '1'},
      ),
    );

    expect(inner.last!.headers, <String, String>{'X-Base': '1'});
  });
}

class _RecordingClient implements RuleHttpClient {
  RuleHttpRequest? last;

  @override
  Future<RuleHttpResponse> send(RuleHttpRequest request) async {
    last = request;
    return RuleHttpResponse(
      statusCode: 200,
      body: '',
      uri: request.uri,
    );
  }
}

class _FakeAuthRepository implements RuleAuthRepository {
  _FakeAuthRepository(this.auth);

  final RuleAuth? auth;

  @override
  Future<void> delete(String ruleId) async {}

  @override
  Future<RuleAuth?> find(String ruleId) async => auth;

  @override
  Future<void> save(RuleAuth auth) async {}

  @override
  Stream<Set<String>> watchLoggedInRuleIds() => const Stream<Set<String>>.empty();
}
