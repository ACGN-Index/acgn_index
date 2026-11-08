import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/pipeline/template_renderer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('renderTemplate', () {
    test('替换已知变量并保留其它字符', () {
      expect(
        renderTemplate('/search?q={{key}}&page={{page}}', <String, Object?>{
          'key': 'dart',
          'page': 2,
        }),
        '/search?q=dart&page=2',
      );
    });

    test('未知变量抛出规则错误', () {
      expect(
        () => renderTemplate('{{missing}}', const <String, Object?>{}),
        throwsA(isA<RuleFormatException>()),
      );
    });

    test('null 变量渲染为空字符串', () {
      expect(
        renderTemplate('a{{value}}b', const <String, Object?>{'value': null}),
        'ab',
      );
    });
  });
}
