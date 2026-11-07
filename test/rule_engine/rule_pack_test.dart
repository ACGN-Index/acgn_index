import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_pack_helpers.dart';

void main() {
  group('RulePack', () {
    test('解析示例规则包并还原元信息', () {
      final pack = RulePack.fromJson(loadDemoPack());

      expect(pack.schemaVersion, kSupportedSchemaVersion);
      expect(pack.meta.id, 'demo.mock');
      expect(pack.meta.baseUrl, 'https://example.invalid');
      expect(pack.meta.types, <MediaType>{MediaType.comic, MediaType.novel});
      expect(pack.request.timeoutMs, 15000);
      expect(pack.request.headers['User-Agent'], 'ACGNIndex/0.1');
      expect(pack.capabilities.keys, containsAll(RuleCapability.values));
    });

    test('序列化后的 JSON 能再次解析且关键字段不变', () {
      final original = RulePack.fromJson(loadDemoPack());
      final reparsed = RulePack.parse(jsonEncode(original.toJson()));

      expect(reparsed.meta.id, original.meta.id);
      expect(reparsed.meta.types, original.meta.types);
      expect(reparsed.capabilities.length, original.capabilities.length);

      final originalSearch = original.capabilities[RuleCapability.search]!;
      final reparsedSearch = reparsed.capabilities[RuleCapability.search]!;
      expect(reparsedSearch.url, originalSearch.url);
      expect(reparsedSearch.list?.selector, '.result .item');
      expect(reparsedSearch.fields['id']?.regex, r'/(\d+)$');
      expect(reparsedSearch.fields['cover']?.absolute, isTrue);
    });

    test('缺少 schemaVersion 时抛出 RuleFormatException', () {
      final json = cloneDemoPack()..remove('schemaVersion');

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('字段规则声明多种取值来源时抛出 RuleFormatException', () {
      final json = cloneDemoPack();
      final search = json['capabilities'] as Map<String, Object?>;
      final searchRule = search['search'] as Map<String, Object?>;
      final fields = searchRule['fields'] as Map<String, Object?>;
      fields['title'] = <String, Object?>{'selector': '.title', 'js': 'value'};

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('未知内容类型时抛出 RuleFormatException', () {
      final json = cloneDemoPack();
      final meta = json['meta'] as Map<String, Object?>;
      meta['types'] = <String>['game'];

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('非法 JSON 文本抛出 RuleFormatException', () {
      expect(() => RulePack.parse('{"schemaVersion":'), throwsA(isA<RuleFormatException>()));
    });
  });
}
