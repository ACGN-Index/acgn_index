import 'package:acgn_index/features/sources/rule_editor/rule_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RuleDraft', () {
    test('保留未识别字段并在写回时格式化', () {
      final draft = RuleDraft.parse(
        '{"schemaVersion":1,"meta":{"id":"a.b"},"x-extra":true}',
      );

      draft.mutate((json) => ensureJsonMap(json, 'meta')['name'] = '名字');

      final roundTrip = RuleDraft.parse(draft.toJsonText()).json;
      expect(roundTrip['x-extra'], isTrue);
      expect(asJsonMapOrNull(roundTrip['meta'])?['name'], '名字');
    });

    test('顶层不是对象时抛出 FormatException', () {
      expect(() => RuleDraft.parse('[]'), throwsFormatException);
    });

    test('mutate 会通知监听者', () {
      final draft = RuleDraft.parse('{"schemaVersion":1}');
      var notified = 0;
      draft.addListener(() => notified++);

      draft.mutate((json) => json['schemaVersion'] = 1);

      expect(notified, 1);
    });
  });

  group('pruneFieldRule', () {
    test('去掉未设置的可选键但保留取值来源', () {
      final result = pruneFieldRule(<String, Object?>{
        'selector': '',
        'attr': '',
        'regex': '',
        'group': 1,
        'multiple': false,
        'html': true,
        'prefix': '',
      });

      expect(result, <String, Object?>{'selector': '', 'html': true});
    });

    test('递归清理 items 与 fields', () {
      final result = pruneFieldRule(<String, Object?>{
        'items': <String, Object?>{'jsonPath': r'$.data[*]'},
        'fields': <String, Object?>{
          'title': <String, Object?>{'jsonPath': r'$.title', 'attr': '', 'absolute': false},
        },
      });

      expect(result, <String, Object?>{
        'items': <String, Object?>{'jsonPath': r'$.data[*]'},
        'fields': <String, Object?>{
          'title': <String, Object?>{'jsonPath': r'$.title'},
        },
      });
    });
  });

  group('defaultCapabilityJson', () {
    test('content 使用内容类型的默认 mode', () {
      expect(defaultCapabilityJson('content', contentMode: 'images')['mode'], 'images');
      expect(defaultCapabilityJson('content').containsKey('mode'), isFalse);
    });

    test('每种能力都带 url', () {
      for (final key in <String>['search', 'detail', 'toc', 'content']) {
        expect(defaultCapabilityJson(key)['url'], '', reason: key);
      }
    });

    test('内容类型映射到默认内容形式', () {
      expect(defaultContentMode('anime'), 'video');
      expect(defaultContentMode('comic'), 'images');
      expect(defaultContentMode('novel'), 'text');
      expect(defaultContentMode('unknown'), isNull);
    });
  });
}
