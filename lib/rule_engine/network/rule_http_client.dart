/// 规则引擎发出的 HTTP 请求。
///
/// 该层只描述请求本身，不绑定具体 HTTP 客户端，便于单测替换。
class RuleHttpRequest {
  const RuleHttpRequest({
    required this.uri,
    this.method = 'GET',
    this.headers = const <String, String>{},
    this.body,
    this.timeout = const Duration(seconds: 15),
    this.retry = 0,
    this.encoding = 'utf-8',
    this.ruleId,
  });

  final Uri uri;
  final String method;
  final Map<String, String> headers;
  final String? body;
  final Duration timeout;

  /// 网络错误后的重试次数，0–2。
  final int retry;

  final String encoding;

  /// 发起请求的规则 id，用于注入该规则保存的本地登录凭据。
  final String? ruleId;

  RuleHttpRequest copyWith({Map<String, String>? headers}) => RuleHttpRequest(
    uri: uri,
    method: method,
    headers: headers ?? this.headers,
    body: body,
    timeout: timeout,
    retry: retry,
    encoding: encoding,
    ruleId: ruleId,
  );
}

/// 规则引擎收到的 HTTP 响应。
class RuleHttpResponse {
  const RuleHttpResponse({
    required this.statusCode,
    required this.body,
    required this.uri,
    this.headers = const <String, String>{},
  });

  final int statusCode;
  final String body;

  /// 跟随重定向后的最终地址，相对链接据此解析。
  final Uri uri;

  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

/// HTTP 客户端抽象；实现方负责超时、重试、编码与状态码处理。
abstract interface class RuleHttpClient {
  Future<RuleHttpResponse> send(RuleHttpRequest request);
}

/// 需要释放底层资源的客户端实现。
abstract interface class ClosableRuleHttpClient implements RuleHttpClient {
  Future<void> close();
}
