import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'demo_pack_helpers.dart';

/// 收集错误信息，失败时可直接看到全部问题。
String describe(ValidationResult result) =>
    result.issues.map((issue) => issue.toString()).join('\n');

void main() {
  const validator = RulePackValidator();

  group('RulePackValidator', () {
    test('示例规则包没有任何问题', () {
      final result = validator.validate(loadDemoPack());

      expect(result.isValid, isTrue, reason: describe(result));
      expect(result.issues, isEmpty, reason: describe(result));
    });

    test('未知顶层字段只产生 warning，不阻止安装', () {
      final json = cloneDemoPack()..['futureField'] = true;
      final result = validator.validate(json);

      expect(result.isValid, isTrue, reason: describe(result));
      expect(result.warnings, isNotEmpty);
      expect(result.warnings.first.path, 'futureField');
    });

    test('缺少 meta.baseUrl 报错', () {
      final json = cloneDemoPack();
      (json['meta'] as Map<String, Object?>).remove('baseUrl');
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('meta.baseUrl'));
    });

    test('baseUrl 非 http(s) 报错', () {
      final json = cloneDemoPack();
      (json['meta'] as Map<String, Object?>)['baseUrl'] = 'ftp://example.invalid';
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('meta.baseUrl'));
    });

    test('不支持的 schemaVersion 报错', () {
      final json = cloneDemoPack()..['schemaVersion'] = 99;
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('schemaVersion'));
    });

    test('缺少 capabilities 报错', () {
      final json = cloneDemoPack()..remove('capabilities');
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('capabilities'));
    });

    test('列表选择器没有取值来源时报错', () {
      final json = cloneDemoPack();
      final search =
          (json['capabilities'] as Map<String, Object?>)['search'] as Map<String, Object?>;
      search['list'] = <String, Object?>{'attr': 'href'};
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.path),
        contains('capabilities.search.list'),
      );
    });

    test('主取值来源可以与 js 后处理组合', () {
      final json = cloneDemoPack();
      final search =
          (json['capabilities'] as Map<String, Object?>)['search'] as Map<String, Object?>;
      final fields = search['fields'] as Map<String, Object?>;
      fields['title'] = <String, Object?>{'selector': '.title', 'js': 'value => value.trim()'};
      final result = validator.validate(json);

      expect(result.isValid, isTrue, reason: describe(result));
    });

    test('声明多个主取值来源报错', () {
      final json = cloneDemoPack();
      final search =
          (json['capabilities'] as Map<String, Object?>)['search'] as Map<String, Object?>;
      final fields = search['fields'] as Map<String, Object?>;
      fields['title'] = <String, Object?>{'selector': '.title', 'xpath': '//title'};
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.path),
        contains('capabilities.search.fields.title'),
      );
    });

    test('非法正则表达式报错', () {
      final json = cloneDemoPack();
      final capabilities = json['capabilities'] as Map<String, Object?>;
      final search = capabilities['search'] as Map<String, Object?>;
      final fields = search['fields'] as Map<String, Object?>;
      fields['id'] = <String, Object?>{'selector': 'a', 'attr': 'href', 'regex': '('};
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.path),
        contains('capabilities.search.fields.id.regex'),
      );
    });

    test('缺少 meta.type 报错', () {
      final json = cloneDemoPack();
      (json['meta'] as Map<String, Object?>).remove('type');
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('meta.type'));
    });

    test('未知 meta.type 报错', () {
      final json = cloneDemoPack();
      (json['meta'] as Map<String, Object?>)['type'] = 'game';
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('meta.type'));
    });

    test('content 缺少 mode 报错', () {
      final json = cloneDemoPack();
      final content =
          (json['capabilities'] as Map<String, Object?>)['content'] as Map<String, Object?>;
      content.remove('mode');
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('capabilities.content.mode'));
    });

    test('video 正文 url 可留空，但必须有内联地址', () {
      final json = cloneDemoPack();
      final content =
          (json['capabilities'] as Map<String, Object?>)['content'] as Map<String, Object?>;
      content['mode'] = 'video';
      content.remove('url');

      final missing = validator.validate(json);
      expect(missing.isValid, isFalse);
      expect(missing.errors.map((issue) => issue.path), contains('capabilities.content.url'));

      content['fields'] = <String, Object?>{
        'url': <String, Object?>{'const': '{{chapter.url}}'},
      };
      final inline = validator.validate(json);
      expect(inline.isValid, isTrue, reason: describe(inline));

      content['resolve'] = <String, Object?>{'url': '/resolve/{{chapter.id}}'};
      final withResolve = validator.validate(json);
      expect(withResolve.isValid, isFalse);
      expect(
        withResolve.errors.map((issue) => issue.path),
        contains('capabilities.content.resolve'),
      );
    });

    test('留空的 url 只对 video 生效', () {
      final json = cloneDemoPack();
      final content =
          (json['capabilities'] as Map<String, Object?>)['content'] as Map<String, Object?>;
      content.remove('url');
      content['fields'] = <String, Object?>{
        'url': <String, Object?>{'const': '{{chapter.url}}'},
      };
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('capabilities.content.url'));
    });

    test('index 搜索缺少 filter 报错', () {
      final json = cloneDemoPack();
      final search =
          (json['capabilities'] as Map<String, Object?>)['search'] as Map<String, Object?>;
      search['mode'] = 'index';
      search['index'] = <String, Object?>{
        'url': '/index.json',
        'list': <String, Object?>{'jsonPath': r'$.data[*]'},
      };
      search.remove('filter');
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('capabilities.search.filter'));
    });

    test('toc 的 group 必须与 fanOutFrom 一起使用', () {
      final json = cloneDemoPack();
      final toc = (json['capabilities'] as Map<String, Object?>)['toc'] as Map<String, Object?>;
      toc['group'] = <String, Object?>{'id': 'vid', 'title': 'title'};
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('capabilities.toc.group'));
    });

    test('items 与取值来源同时声明报错', () {
      final json = cloneDemoPack();
      final detail =
          (json['capabilities'] as Map<String, Object?>)['detail'] as Map<String, Object?>;
      final volumes = (detail['fields'] as Map<String, Object?>)['volumes'] as Map<String, Object?>;
      volumes['selector'] = '.volumes li';
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(
        result.errors.map((issue) => issue.path),
        contains('capabilities.detail.fields.volumes'),
      );
    });

    test('未支持的 schemaVersion 报版本不兼容', () {
      final json = cloneDemoPack()..['schemaVersion'] = 2;
      final result = validator.validate(json);

      expect(result.isValid, isFalse);
      expect(result.errors.map((issue) => issue.path), contains('schemaVersion'));
    });
  });
}
