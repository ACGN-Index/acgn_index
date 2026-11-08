import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/pipeline/detail_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pipeline_test_helpers.dart';

void main() {
  group('RuleDetailPipeline', () {
    test('解析 JSON 详情、绝对地址与分卷', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('''
{"data":{"title":"作品A","cover":"/cover.jpg","intro":"简介","author":"作者",
"tags":["tag1","tag2"],"episodeCount":12,
"volumes":[{"vid":"v1","title":"卷一"},{"vid":"v2","title":"卷二"}]}}
'''),
      ]);
      final pipeline = RuleDetailPipeline(httpClient: client);

      final detail = await pipeline.fetch(_pack(), id: '42');

      expect(client.requests.single.uri.toString(), 'https://api.test/work/42');
      expect(detail.title, '作品A');
      expect(detail.cover, 'https://api.test/cover.jpg');
      expect(detail.intro, '简介');
      expect(detail.author, '作者');
      expect(detail.episodeCount, 12);
      expect(detail.tags, <String>['tag1', 'tag2']);
      expect(detail.volumes, <Map<String, String>>[
        <String, String>{'id': 'v1', 'title': '卷一'},
        <String, String>{'id': 'v2', 'title': '卷二'},
      ]);
      expect(detail.url, 'https://api.test/work/42');
      expect(detail.headers['User-Agent'], isNotEmpty);
    });

    test('解析 HTML 详情字段', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply(
          '<h1>作品B</h1><div class="intro"><p>第一段</p><p>第二段</p></div>',
          headers: <String, String>{'content-type': 'text/html; charset=utf-8'},
        ),
      ]);
      final pipeline = RuleDetailPipeline(httpClient: client);

      final detail = await pipeline.fetch(_htmlPack(), id: '7');

      expect(detail.title, '作品B');
      expect(detail.intro, '<p>第一段</p><p>第二段</p>');
    });

    test('缺少 title 时抛规则异常', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('{"data":{"name":"没有标题"}}'),
      ]);
      final pipeline = RuleDetailPipeline(httpClient: client);

      await expectLater(pipeline.fetch(_pack(), id: '42'), throwsA(isA<RuleFormatException>()));
    });

    test('未声明 detail 能力时抛不支持异常', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleDetailPipeline(httpClient: client);

      await expectLater(
        pipeline.fetch(
          _pack(capabilities: const <RuleCapability, CapabilityRule>{}),
          id: '42',
        ),
        throwsA(isA<UnsupportedCapabilityException>()),
      );
    });
  });
}

RulePack _pack({Map<RuleCapability, CapabilityRule>? capabilities}) => testPack(
  capabilities:
      capabilities ??
      const <RuleCapability, CapabilityRule>{
        RuleCapability.detail: DetailCapabilityRule(
          url: '/work/{{id}}',
          fields: <String, FieldRule>{
            'title': FieldRule(jsonPath: r'$.data.title'),
            'cover': FieldRule(jsonPath: r'$.data.cover', absolute: true),
            'intro': FieldRule(jsonPath: r'$.data.intro'),
            'author': FieldRule(jsonPath: r'$.data.author'),
            'episodeCount': FieldRule(jsonPath: r'$.data.episodeCount'),
            'tags': FieldRule(jsonPath: r'$.data.tags[*]', multiple: true),
            'volumes': FieldRule(
              items: FieldRule(jsonPath: r'$.data.volumes[*]'),
              fields: <String, FieldRule>{
                'id': FieldRule(jsonPath: r'$.vid'),
                'title': FieldRule(jsonPath: r'$.title'),
              },
            ),
          },
        ),
      },
);

RulePack _htmlPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.detail: DetailCapabilityRule(
      url: '/work/{{id}}',
      fields: <String, FieldRule>{
        'title': FieldRule(selector: 'h1'),
        'intro': FieldRule(selector: '.intro', extractHtml: true),
      },
    ),
  },
);
