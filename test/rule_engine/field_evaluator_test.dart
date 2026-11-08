import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/sandbox/js_runtime.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart';
import 'package:xml/xml.dart';

void main() {
  const evaluator = FieldEvaluator();

  RulePack pack() => const RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: RuleMeta(
      id: 'test.pack',
      name: 'Test',
      type: MediaType.comic,
      baseUrl: 'https://example.com/base/',
      version: '1.0.0',
      author: 'tester',
      lang: 'zh',
    ),
  );

  RuleEvalContext pageContext({
    Object? json,
    String? html,
    XmlDocument? xmlDocument,
    String pageUri = 'https://example.com/base/list',
    Map<String, Object?> variables = const <String, Object?>{},
  }) => RuleEvalContext(
    pack: pack(),
    pageUri: Uri.parse(pageUri),
    json: json,
    htmlDocument: html == null ? null : parse(html),
    xmlNode: xmlDocument,
    variables: variables,
  );

  group('JSON 字段', () {
    test('jsonPath 读取、fallback 与 absolute', () {
      final json = jsonDecode('''
{"data":[{"id":7,"name_cn":null,"name":"作品A","images":{"common":"/cover/a.jpg"}}]}
''');
      final page = pageContext(json: json);
      final entries = evaluator.resolveItems(
        const FieldRule(jsonPath: r'$.data[*]'),
        page,
      );
      expect(entries, hasLength(1));
      final entry = page.withEntry(entries.single);

      expect(evaluator.evaluate(const FieldRule(jsonPath: r'$.id'), entry), '7');
      expect(
        evaluator.evaluate(
          const FieldRule(
            jsonPath: r'$.name_cn',
            fallback: FieldRule(jsonPath: r'$.name'),
          ),
          entry,
        ),
        '作品A',
      );
      expect(
        evaluator.evaluate(
          const FieldRule(jsonPath: r'$.images.common', absolute: true),
          entry,
        ),
        'https://example.com/cover/a.jpg',
      );
    });

    test('multiple 返回全部匹配', () {
      final json = jsonDecode('{"tags":[{"name":"a"},{"name":"b"}]}');
      final context = pageContext(json: json).withEntry(json);

      expect(
        evaluator.evaluate(
          const FieldRule(jsonPath: r'$.tags[*].name', multiple: true),
          context,
        ),
        <String>['a', 'b'],
      );
    });

    test('对象数组逐项提取字段', () {
      final json = jsonDecode('''
{"volumes":[{"vid":"v1","title":"卷一"},{"vid":"v2","title":"卷二"}]}
''');
      final context = pageContext(json: json).withEntry(json);

      final result = evaluator.evaluate(
        const FieldRule(
          items: FieldRule(jsonPath: r'$.volumes[*]'),
          fields: <String, FieldRule>{
            'id': FieldRule(jsonPath: r'$.vid'),
            'title': FieldRule(jsonPath: r'$.title'),
          },
        ),
        context,
      );

      expect(result, <Map<String, String>>[
        <String, String>{'id': 'v1', 'title': '卷一'},
        <String, String>{'id': 'v2', 'title': '卷二'},
      ]);
    });
  });

  group('HTML 字段', () {
    test('selector、attr、regex、absolute 与 multiple', () {
      final page = pageContext(
        html: '''
<div class="item">
  <a class="link" href="/work/42">作品B</a>
  <img src="/img/b.jpg">
  <span class="tag">x</span>
  <span class="tag">y</span>
</div>
''',
      );
      final entries = evaluator.resolveItems(const FieldRule(selector: '.item'), page);
      expect(entries, hasLength(1));
      final entry = page.withEntry(entries.single);

      expect(
        evaluator.evaluate(
          const FieldRule(
            selector: 'a',
            attribute: 'href',
            regex: r'/(\d+)$',
          ),
          entry,
        ),
        '42',
      );
      expect(
        evaluator.evaluate(
          const FieldRule(selector: 'img', attribute: 'src', absolute: true),
          entry,
        ),
        'https://example.com/img/b.jpg',
      );
      expect(
        evaluator.evaluate(
          const FieldRule(selector: '.tag', multiple: true),
          entry,
        ),
        <String>['x', 'y'],
      );
    });

    test('htmlToText 保留段落换行', () {
      final page = pageContext(
        html: '<div class="intro"><p>第一段</p><p>第二段</p></div>',
      );
      final entries = evaluator.resolveItems(const FieldRule(selector: '.intro'), page);
      final entry = page.withEntry(entries.single);

      expect(
        evaluator.evaluate(
          const FieldRule(selector: 'p', multiple: true, htmlToText: true),
          entry,
        ),
        <String>['第一段', '第二段'],
      );
    });
  });

  group('XML 字段', () {
    test('xpath 取条目与属性', () {
      final document = XmlDocument.parse(
        '<root><item id="1"><title>作品C</title></item></root>',
      );
      final page = pageContext(
        xmlDocument: document,
        pageUri: 'https://example.com/list',
      );
      final entries = evaluator.resolveItems(const FieldRule(xpath: '//item'), page);
      expect(entries, hasLength(1));
      final entry = page.withEntry(entries.single);

      expect(evaluator.evaluate(const FieldRule(xpath: 'title'), entry), '作品C');
      expect(evaluator.evaluate(const FieldRule(xpath: '@id'), entry), '1');
    });
  });

  group('通用后处理', () {
    test('const 支持模板变量', () {
      final page = pageContext(
        variables: const <String, Object?>{'id': '42'},
      );

      expect(
        evaluator.evaluate(
          const FieldRule(constant: '{{baseUrl}}work/{{id}}'),
          page,
        ),
        'https://example.com/base/work/42',
      );
    });

    test('default 在前一步为空时生效', () {
      final page = pageContext(json: const <String, Object?>{});
      expect(
        evaluator.evaluate(
          const FieldRule(jsonPath: r'$.missing', defaultValue: 'unknown'),
          page,
        ),
        'unknown',
      );
    });

    test('未配置 JS 运行时遇到 js 规则时报错', () {
      final page = pageContext(json: const <String, Object?>{});
      expect(
        () => evaluator.evaluate(const FieldRule(script: 'value'), page),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });

  group('JS 字段', () {
    test('纯 js 来源读取 value 与 ctx', () {
      final runtime = _FakeJsRuntime((script, bindings) {
        final value = bindings['value']! as Map<String, Object?>;
        final ctx = bindings['ctx']! as Map<String, Object?>;
        return value['title'] == ctx['keyword'];
      });
      final evaluator = FieldEvaluator(jsRuntime: runtime);
      final context = pageContext(
        json: const <String, Object?>{'title': '作品A'},
        variables: const <String, Object?>{'keyword': '作品A'},
      ).withEntry(const <String, Object?>{'title': '作品A'});

      final result = evaluator.evaluate(
        const FieldRule(script: 'value.title === ctx.keyword'),
        context,
      );

      expect(result, 'true');
      expect(runtime.scripts.single, 'value.title === ctx.keyword');
    });

    test('主来源结果可以交给 js 后处理', () {
      final runtime = _FakeJsRuntime(
        (script, bindings) => bindings['value'].toString().toUpperCase(),
      );
      final evaluator = FieldEvaluator(jsRuntime: runtime);
      final context = pageContext();

      final result = evaluator.evaluate(
        const FieldRule(constant: 'abc', script: 'value => value.toUpperCase()'),
        context,
      );

      expect(result, 'ABC');
    });

    test('js 返回数组时 multiple 逐项产出', () {
      final runtime = _FakeJsRuntime(
        (script, bindings) => <Object?>['a', 'b'],
      );
      final evaluator = FieldEvaluator(jsRuntime: runtime);
      final context = pageContext();

      final result = evaluator.evaluate(
        const FieldRule(script: '["a", "b"]', multiple: true, suffix: '!'),
        context,
      );

      expect(result, <String>['a!', 'b!']);
    });

    test('js 结果先走模板再拼接前后缀', () {
      final runtime = _FakeJsRuntime((script, bindings) => '42');
      final evaluator = FieldEvaluator(jsRuntime: runtime);
      final context = pageContext(variables: const <String, Object?>{'id': '42'});

      final result = evaluator.evaluate(
        const FieldRule(
          script: 'Math.random()',
          template: '{{ctx.baseUrl}}{{value}}?id={{id}}',
          suffix: '!',
        ),
        context,
      );

      expect(result, 'https://example.com/base/42?id=42!');
    });
  });
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
