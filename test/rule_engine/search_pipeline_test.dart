import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';
import 'package:acgn_index/rule_engine/sandbox/js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleSearchPipeline', () {
    test('query 模式渲染请求并映射 JSON 结果', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply('''
{"total":2,"data":[
  {"id":1,"name_cn":"A","images":{"common":"/a.jpg"}},
  {"id":2,"name":"B","images":{"common":"https://img.test/b.jpg"}}
]}
'''),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      final page = await pipeline.search(
        _pack(
          search: _querySearch,
          requestHeaders: const <String, String>{'Accept': 'application/json'},
        ),
      );

      final request = client.requests.single;
      expect(request.uri.toString(), 'https://api.test/search?q=&page=1');
      expect(request.method, 'POST');
      expect(request.body, '{"keyword":""}');
      expect(request.headers['Accept'], 'application/json');
      expect(request.headers['User-Agent'], isNotEmpty);
      expect(page.items.map((item) => item.title), <String>['A', 'B']);
      expect(page.items.first.cover, 'https://api.test/a.jpg');
      expect(page.items.last.cover, 'https://img.test/b.jpg');
      expect(page.totalItems, 2);
      expect(page.hasMore, isFalse);
    });

    test('query 模式解析 HTML 列表', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply(
          '''
<div class="item">
  <a href="/work/1"><span class="title">作品A</span><img src="/a.jpg"></a>
</div>
<div class="item">
  <a href="/work/2"><span class="title">作品B</span><img src="/b.jpg"></a>
</div>
''',
          headers: <String, String>{'content-type': 'text/html; charset=utf-8'},
        ),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      final page = await pipeline.search(_pack(search: _htmlSearch));

      expect(page.items.map((item) => item.id), <String>['1', '2']);
      expect(page.items.map((item) => item.title), <String>['作品A', '作品B']);
      expect(page.items.first.cover, 'https://api.test/a.jpg');
    });

    test('query 模式解析 XML 列表', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply(
          '<rss><item><id>1</id><title>作品A</title></item>'
          '<item><id>2</id><title>作品B</title></item></rss>',
          headers: <String, String>{'content-type': 'application/xml'},
        ),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      final page = await pipeline.search(_pack(search: _xmlSearch));

      expect(page.items.map((item) => item.id), <String>['1', '2']);
      expect(page.items.map((item) => item.title), <String>['作品A', '作品B']);
    });

    test('index 模式空关键词跳过过滤并分页缓存', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply('''
{"data":[
  {"id":"1","title":"A"},
  {"id":"2","title":"B"},
  {"id":"3","title":"C"}
]}
'''),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);
      final pack = _pack(search: _indexSearch);

      final first = await pipeline.search(pack);
      expect(first.items.map((item) => item.id), <String>['1', '2']);
      expect(first.totalItems, 3);
      expect(first.hasMore, isTrue);

      final second = await pipeline.search(pack, page: 2);
      expect(second.items.map((item) => item.id), <String>['3']);
      expect(second.hasMore, isFalse);
      expect(client.requests, hasLength(1));
    });

    test('index 模式用 js filter 过滤条目', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply('{"data":[{"id":"1","title":"A"},{"id":"2","title":"B"}]}'),
      ]);
      final runtime = _FakeJsRuntime((script, bindings) {
        final value = bindings['value']! as Map<String, Object?>;
        final ctx = bindings['ctx']! as Map<String, Object?>;
        return value['title'] == ctx['keyword'];
      });
      final pipeline = RuleSearchPipeline(
        httpClient: client,
        evaluator: FieldEvaluator(jsRuntime: runtime),
      );

      final page = await pipeline.search(_pack(search: _jsFilterSearch), keyword: 'A');

      expect(page.items.map((item) => item.id), <String>['1']);
      expect(runtime.scripts, hasLength(2));
      expect(runtime.scripts, everyElement('value.title === ctx.keyword'));
    });

    test('目标主机不在白名单时拒绝请求', () async {
      final client = _FakeHttpClient(<_Reply>[]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      await expectLater(
        pipeline.search(_pack(search: _evilSearch)),
        throwsA(isA<NetworkException>()),
      );
      expect(client.requests, isEmpty);
    });

    test('allowedHosts 中的主机可以访问', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply('{"data":[]}'),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      await pipeline.search(
        _pack(
          search: _cdnSearch,
          allowedHosts: const <String>['cdn.test'],
        ),
      );

      expect(client.requests.single.uri.host, 'cdn.test');
    });

    test('非 2xx 响应抛出网络异常', () async {
      final client = _FakeHttpClient(<_Reply>[
        const _Reply(
          'server error',
          statusCode: 500,
          headers: <String, String>{'content-type': 'text/plain'},
        ),
      ]);
      final pipeline = RuleSearchPipeline(httpClient: client);

      await expectLater(
        pipeline.search(_pack(search: _querySearch)),
        throwsA(isA<NetworkException>()),
      );
    });
  });
}

RulePack _pack({
  required SearchCapabilityRule search,
  List<String> allowedHosts = const <String>[],
  Map<String, String> requestHeaders = const <String, String>{},
}) => RulePack(
  schemaVersion: kSupportedSchemaVersion,
  meta: RuleMeta(
    id: 'test.pack',
    name: 'Test',
    type: MediaType.anime,
    baseUrl: 'https://api.test',
    version: '1.0.0',
    author: 'tester',
    lang: 'zh',
    allowedHosts: allowedHosts,
  ),
  request: RequestRule(headers: requestHeaders),
  capabilities: <RuleCapability, CapabilityRule>{
    RuleCapability.search: search,
  },
);

const SearchCapabilityRule _querySearch = SearchCapabilityRule(
  url: '/search?q={{key}}&page={{page}}',
  method: 'POST',
  body: '{"keyword":"{{key}}"}',
  list: FieldRule(jsonPath: r'$.data[*]'),
  fields: <String, FieldRule>{
    'id': FieldRule(jsonPath: r'$.id'),
    'title': FieldRule(
      jsonPath: r'$.name_cn',
      fallback: FieldRule(jsonPath: r'$.name'),
    ),
    'cover': FieldRule(jsonPath: r'$.images.common', absolute: true),
  },
  pagination: SearchPagination(
    totalItems: FieldRule(jsonPath: r'$.total'),
  ),
);

const SearchCapabilityRule _htmlSearch = SearchCapabilityRule(
  url: '/list',
  list: FieldRule(selector: '.item'),
  fields: <String, FieldRule>{
    'id': FieldRule(selector: 'a', attribute: 'href', regex: r'/(\d+)$'),
    'title': FieldRule(selector: '.title'),
    'cover': FieldRule(selector: 'img', attribute: 'src', absolute: true),
  },
);

const SearchCapabilityRule _xmlSearch = SearchCapabilityRule(
  url: '/rss',
  list: FieldRule(xpath: '//item'),
  fields: <String, FieldRule>{
    'id': FieldRule(xpath: 'id'),
    'title': FieldRule(xpath: 'title'),
  },
);

const SearchCapabilityRule _indexSearch = SearchCapabilityRule(
  url: '',
  mode: SearchMode.localIndex,
  pageSize: 2,
  index: SearchIndexRule(
    url: '/index',
    list: FieldRule(jsonPath: r'$.data[*]'),
  ),
  fields: <String, FieldRule>{
    'id': FieldRule(jsonPath: r'$.id'),
    'title': FieldRule(jsonPath: r'$.title'),
  },
);

const SearchCapabilityRule _jsFilterSearch = SearchCapabilityRule(
  url: '',
  mode: SearchMode.localIndex,
  pageSize: 2,
  index: SearchIndexRule(
    url: '/index',
    list: FieldRule(jsonPath: r'$.data[*]'),
  ),
  filter: FieldRule(script: 'value.title === ctx.keyword'),
  fields: <String, FieldRule>{
    'id': FieldRule(jsonPath: r'$.id'),
    'title': FieldRule(jsonPath: r'$.title'),
  },
);

const SearchCapabilityRule _evilSearch = SearchCapabilityRule(
  url: 'https://evil.test/search',
  list: FieldRule(jsonPath: r'$.data[*]'),
  fields: <String, FieldRule>{
    'id': FieldRule(jsonPath: r'$.id'),
    'title': FieldRule(jsonPath: r'$.title'),
  },
);

const SearchCapabilityRule _cdnSearch = SearchCapabilityRule(
  url: 'https://cdn.test/search',
  list: FieldRule(jsonPath: r'$.data[*]'),
  fields: <String, FieldRule>{
    'id': FieldRule(jsonPath: r'$.id'),
    'title': FieldRule(jsonPath: r'$.title'),
  },
);

class _Reply {
  const _Reply(
    this.body, {
    this.statusCode = 200,
    this.headers = const <String, String>{'content-type': 'application/json'},
  });

  final String body;
  final int statusCode;
  final Map<String, String> headers;
}

class _FakeJsRuntime implements JsRuntime {
  _FakeJsRuntime(this.handler);

  final Object? Function(String script, Map<String, Object?> bindings) handler;
  final List<String> scripts = <String>[];

  @override
  Object? evaluate(
    String script, {
    Map<String, Object?> bindings = const <String, Object?>{},
  }) {
    scripts.add(script);
    return handler(script, bindings);
  }

  @override
  Future<void> dispose() async {}
}

class _FakeHttpClient implements RuleHttpClient {
  _FakeHttpClient(this.replies);

  final List<_Reply> replies;
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
