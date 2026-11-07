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

    test('未声明 types 只产生 warning', () {
      final json = cloneDemoPack();
      (json['meta'] as Map<String, Object?>).remove('types');
      final result = validator.validate(json);

      expect(result.isValid, isTrue, reason: describe(result));
      expect(result.warnings.map((issue) => issue.path), contains('meta.types'));
    });
  });
}
