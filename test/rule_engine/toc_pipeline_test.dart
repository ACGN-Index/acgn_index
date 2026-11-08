import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/models/capability_rule.dart';
import 'package:acgn_index/rule_engine/models/field_rule.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/models/search_result.dart';
import 'package:acgn_index/rule_engine/models/work_detail.dart';
import 'package:acgn_index/rule_engine/pipeline/toc_pipeline.dart';
import 'package:flutter_test/flutter_test.dart';

import 'pipeline_test_helpers.dart';

void main() {
  group('RuleTocPipeline', () {
    test('平铺目录解析 JSON、绝对地址与排序字段', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('''
{"data":[
  {"cid":"c1","title":"第一话","url":"/chapter/1","sort":1,"airdate":"2026-01-01","duration":"24:00"},
  {"cid":"c2","title":"第二话","url":"https://cdn.test/2","sort":2}
]}
'''),
      ]);
      final pipeline = RuleTocPipeline(httpClient: client);

      final toc = await pipeline.fetch(_flatPack(), id: '42');

      expect(client.requests.single.uri.toString(), 'https://api.test/toc/42');
      expect(toc.entries, hasLength(2));
      expect(toc.entries.first.id, 'c1');
      expect(toc.entries.first.title, '第一话');
      expect(toc.entries.first.url, 'https://api.test/chapter/1');
      expect(toc.entries.first.order, 1);
      expect(toc.entries.first.airdate, '2026-01-01');
      expect(toc.entries.first.duration, '24:00');
      expect(toc.entries.last.url, 'https://cdn.test/2');
    });

    test('按 detail.volumes 逐卷请求并写入分组', () async {
      final client = FakeHttpClient(<FakeReply>[
        const FakeReply('{"data":[{"cid":"c1","title":"卷一 第一章"}]}'),
        const FakeReply('{"data":[{"cid":"c2","title":"卷二 第一章"}]}'),
      ]);
      final pipeline = RuleTocPipeline(httpClient: client);
      const detail = WorkDetail(
        title: '作品',
        fields: <String, Object?>{
          'volumes': <Map<String, String>>[
            <String, String>{'id': 'v1', 'title': '卷一'},
            <String, String>{'id': 'v2', 'title': '卷二'},
          ],
        },
      );

      final toc = await pipeline.fetch(_fanOutPack(), id: '42', detail: detail);

      expect(
        client.requests.map((request) => request.uri.toString()),
        <String>['https://api.test/toc/42/v1', 'https://api.test/toc/42/v2'],
      );
      expect(toc.entries.map((entry) => entry.id), <String>['c1', 'c2']);
      expect(toc.entries.map((entry) => entry.group), <String>['v1', 'v2']);
      expect(toc.entries.map((entry) => entry.groupTitle), <String>['卷一', '卷二']);
      expect(toc.groups.map((group) => group.title), <String>['卷一', '卷二']);
    });

    test('按 search.volumes 扇出时每个条目本身是一章', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleTocPipeline(httpClient: client);
      const searchResult = SearchResult(
        id: 'book-1',
        title: '作品',
        extra: <String, Object?>{
          'volumes': <Map<String, String>>[
            <String, String>{'file': 'f1', 'title': '第一卷', 'size': '1024'},
            <String, String>{'file': 'f2', 'title': '第二卷', 'size': '2048'},
          ],
        },
      );

      final toc = await pipeline.fetch(
        _searchFanOutPack(),
        id: 'book-1',
        searchResult: searchResult,
      );

      expect(client.requests, isEmpty);
      expect(toc.entries, hasLength(2));
      expect(toc.entries.first.id, 'epub');
      expect(toc.entries.first.title, '第一卷');
      expect(toc.entries.first.extra['file'], 'f1');
      expect(toc.entries.first.extra['size'], '1024');
      expect(toc.entries.first.group, 'f1');
      expect(toc.entries.first.groupTitle, '第一卷');
      expect(toc.entries.last.title, '第二卷');
    });

    test('缺少 fanOutFrom 数据时抛规则异常', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleTocPipeline(httpClient: client);

      await expectLater(
        pipeline.fetch(_fanOutPack(), id: '42'),
        throwsA(isA<RuleFormatException>()),
      );
    });

    test('平铺目录缺少 list 时抛规则异常', () async {
      final client = FakeHttpClient(<FakeReply>[]);
      final pipeline = RuleTocPipeline(httpClient: client);

      await expectLater(
        pipeline.fetch(_packWithoutList(), id: '42'),
        throwsA(isA<RuleFormatException>()),
      );
    });
  });
}

RulePack _flatPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.toc: TocCapabilityRule(
      url: '/toc/{{id}}',
      list: FieldRule(jsonPath: r'$.data[*]'),
      fields: <String, FieldRule>{
        'id': FieldRule(jsonPath: r'$.cid'),
        'title': FieldRule(jsonPath: r'$.title'),
        'url': FieldRule(jsonPath: r'$.url', absolute: true),
        'order': FieldRule(jsonPath: r'$.sort'),
        'airdate': FieldRule(jsonPath: r'$.airdate'),
        'duration': FieldRule(jsonPath: r'$.duration'),
      },
    ),
  },
);

RulePack _fanOutPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.toc: TocCapabilityRule(
      url: '/toc/{{id}}/{{group.id}}',
      fanOutFrom: 'detail.volumes',
      group: TocGroupRule(idField: 'id', titleField: 'title'),
      list: FieldRule(jsonPath: r'$.data[*]'),
      fields: <String, FieldRule>{
        'id': FieldRule(jsonPath: r'$.cid'),
        'title': FieldRule(jsonPath: r'$.title'),
      },
    ),
  },
);

RulePack _searchFanOutPack() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.toc: TocCapabilityRule(
      url: '',
      fanOutFrom: 'search.volumes',
      group: TocGroupRule(idField: 'file', titleField: 'title'),
      fields: <String, FieldRule>{
        'id': FieldRule(constant: 'epub'),
        'title': FieldRule(constant: '{{group.title}}'),
        'file': FieldRule(constant: '{{group.id}}'),
        'size': FieldRule(constant: '{{group.size}}'),
      },
    ),
  },
);

RulePack _packWithoutList() => testPack(
  capabilities: const <RuleCapability, CapabilityRule>{
    RuleCapability.toc: TocCapabilityRule(url: '/toc/{{id}}'),
  },
);
