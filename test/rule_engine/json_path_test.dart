import 'dart:convert';

import 'package:acgn_index/core/errors/app_exception.dart';
import 'package:acgn_index/rule_engine/pipeline/json_path.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = jsonDecode('''
{
  "data": [
    {"id": 1, "name": "A", "tags": [{"name": "x"}, {"name": "y"}]},
    {"id": 2, "name": "B", "tags": []}
  ],
  "total": 2
}
''');

  group('evaluateJsonPath', () {
    test('读取嵌套属性', () {
      expect(evaluateJsonPath(root, r'$.total'), <Object?>[2]);
      expect(evaluateJsonPath(root, r'$.data[0].name'), <Object?>['A']);
    });

    test('通配符遍历数组并继续取属性', () {
      expect(evaluateJsonPath(root, r'$.data[*].id'), <Object?>[1, 2]);
      expect(evaluateJsonPath(root, r'$.data[*].tags[*].name'), <Object?>['x', 'y']);
    });

    test('支持方括号键与负下标', () {
      expect(evaluateJsonPath(root, r"$['total']"), <Object?>[2]);
      expect(evaluateJsonPath(root, r'$.data[-1].name'), <Object?>['B']);
    });

    test('无匹配返回空列表', () {
      expect(evaluateJsonPath(root, r'$.missing'), isEmpty);
      expect(evaluateJsonPath(null, r'$.total'), isEmpty);
    });

    test('非法语法抛出规则错误', () {
      expect(
        () => evaluateJsonPath(root, 'data[*]'),
        throwsA(isA<RuleFormatException>()),
      );
      expect(
        () => evaluateJsonPath(root, r'$.data..name'),
        throwsA(isA<RuleFormatException>()),
      );
    });
  });
}
