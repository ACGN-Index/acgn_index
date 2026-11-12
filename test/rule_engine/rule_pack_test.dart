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
      expect(pack.meta.type, MediaType.comic);
      expect(pack.request.timeoutMs, 15000);
      expect(pack.request.retry, 0);
      expect(pack.request.headers['User-Agent'], 'ACGNIndex/0.2');
      expect(pack.login, isNotNull);
      expect(pack.login!.mode, RuleLoginMode.webview);
      expect(pack.login!.cookieNames, <String>['sessionid']);
      expect(pack.login!.headers['X-Login-Token'], '{{cookie.sessionid}}');
      expect(pack.capabilities.keys, containsAll(RuleCapability.values));
      expect(
        pack.capabilities[RuleCapability.content],
        isA<ContentCapabilityRule>(),
      );
    });

    test('解析新增的数组字段、兜底与模板', () {
      final pack = RulePack.fromJson(loadDemoPack());
      final detail = pack.capabilities[RuleCapability.detail]!;
      final volumes = detail.fields['volumes']!;
      expect(volumes.isObjectList, isTrue);
      expect(volumes.items?.selector, '.volumes li');
      expect(volumes.fields['title']?.selector, 'a');

      final content = pack.capabilities[RuleCapability.content] as ContentCapabilityRule;
      expect(content.mode, ContentMode.images);
      expect(content.fields['images']?.multiple, isTrue);
      expect(content.fields['referer']?.constant, '{{baseUrl}}');

      final search = pack.capabilities[RuleCapability.search] as SearchCapabilityRule;
      expect(search.mode, SearchMode.query);
      expect(search.pagination?.pageSize, 20);
    });

    test('序列化后的 JSON 能再次解析且关键字段不变', () {
      final original = RulePack.fromJson(loadDemoPack());
      final reparsed = RulePack.parse(jsonEncode(original.toJson()));

      expect(reparsed.meta.id, original.meta.id);
      expect(reparsed.meta.type, original.meta.type);
      expect(reparsed.capabilities.length, original.capabilities.length);
      expect(reparsed.login?.mode, original.login?.mode);
      expect(reparsed.login?.cookieNames, original.login?.cookieNames);

      final originalSearch = original.capabilities[RuleCapability.search]!;
      final reparsedSearch = reparsed.capabilities[RuleCapability.search]!;
      expect(reparsedSearch.url, originalSearch.url);
      expect(reparsedSearch.list?.selector, '.result .item');
      expect(reparsedSearch.fields['id']?.regex, r'/(\d+)$');
      expect(reparsedSearch.fields['cover']?.absolute, isTrue);
    });

    test('登录地址支持 baseUrl 模板与相对路径', () {
      const login = RuleLoginRule(url: '{{baseUrl}}/login');
      expect(login.resolveUrl('https://example.invalid'), 'https://example.invalid/login');

      const relative = RuleLoginRule(url: '/signin');
      expect(relative.resolveUrl('https://example.invalid'), 'https://example.invalid/signin');
    });

    test('登录成功判定使用正则', () {
      const login = RuleLoginRule(successUrlPattern: r'/user/\d+');
      expect(login.matchesSuccess('https://example.invalid/user/42'), isTrue);
      expect(login.matchesSuccess('https://example.invalid/login'), isFalse);

      const invalid = RuleLoginRule(successUrlPattern: '[');
      expect(invalid.matchesSuccess('https://example.invalid/user/42'), isFalse);
    });

    test('缺少 schemaVersion 时抛出 RuleFormatException', () {
      final json = cloneDemoPack()..remove('schemaVersion');

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('字段规则声明多种主取值来源时抛出 RuleFormatException', () {
      final json = cloneDemoPack();
      final search = json['capabilities'] as Map<String, Object?>;
      final searchRule = search['search'] as Map<String, Object?>;
      final fields = searchRule['fields'] as Map<String, Object?>;
      fields['title'] = <String, Object?>{'selector': '.title', 'xpath': '//title'};

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('主取值来源可以与 js 后处理组合', () {
      final json = cloneDemoPack();
      final search = json['capabilities'] as Map<String, Object?>;
      final searchRule = search['search'] as Map<String, Object?>;
      final fields = searchRule['fields'] as Map<String, Object?>;
      fields['title'] = <String, Object?>{'selector': '.title', 'js': 'value => value.trim()'};

      final pack = RulePack.fromJson(json);
      final searchCapability = pack.capabilities[RuleCapability.search]! as SearchCapabilityRule;

      expect(searchCapability.fields['title']?.primarySource, FieldSource.css);
      expect(searchCapability.fields['title']?.script, isNotNull);
    });

    test('未知内容类型时抛出 RuleFormatException', () {
      final json = cloneDemoPack();
      final meta = json['meta'] as Map<String, Object?>;
      meta['type'] = 'game';

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('未支持的 schemaVersion 被拒绝', () {
      final json = cloneDemoPack()..['schemaVersion'] = 2;

      expect(() => RulePack.fromJson(json), throwsA(isA<RuleFormatException>()));
    });

    test('非法 JSON 文本抛出 RuleFormatException', () {
      expect(() => RulePack.parse('{"schemaVersion":'), throwsA(isA<RuleFormatException>()));
    });
  });
}
