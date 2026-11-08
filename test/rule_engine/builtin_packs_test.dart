import 'dart:convert';
import 'dart:io';

import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// 校验 `assets/rules/builtin` 下的内置规则集可以安装。
///
/// 这里只做结构与契约校验，不访问网络。
void main() {
  const assetDir = 'assets/rules/builtin';
  const validator = RulePackValidator();

  Map<String, Object?> readJson(String path) =>
      jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;

  test('清单中的每个内置规则包都存在且 id 一致', () {
    final manifest = readJson('$assetDir/index.json');
    final packs = (manifest['packs'] as List<Object?>).cast<Map<String, Object?>>();

    expect(packs, hasLength(4));

    for (final entry in packs) {
      final id = entry['id']! as String;
      final file = entry['file']! as String;
      final path = '$assetDir/$file';
      expect(File(path).existsSync(), isTrue, reason: '$path 不存在');

      final json = readJson(path);
      final result = validator.validate(json);
      expect(result.isValid, isTrue, reason: '$file: ${result.issues.join('; ')}');

      final pack = RulePack.fromJson(json);
      expect(pack.id, id);
      expect(pack.meta.version, isNotEmpty);
      expect(pack.meta.notice, isNotEmpty);
    }
  });

  test('内置规则覆盖动漫 / 漫画 / 小说三类', () {
    final manifest = readJson('$assetDir/index.json');
    final types = <String>{};
    for (final entry in (manifest['packs'] as List<Object?>).cast<Map<String, Object?>>()) {
      final pack = RulePack.fromJson(readJson('$assetDir/${entry['file']}'));
      types.add(pack.meta.type.wireName);
    }

    expect(types, containsAll(<String>['anime', 'comic', 'novel']));
  });

  test('小说源具备按卷扇出的目录与正文能力', () {
    final pack = RulePack.fromJson(readJson('$assetDir/lnovel.novel.acgn.json'));
    final toc = pack.capabilities[RuleCapability.toc]! as TocCapabilityRule;
    final content = pack.capabilities[RuleCapability.content]! as ContentCapabilityRule;

    expect(toc.fanOutFrom, 'detail.volumes');
    expect(toc.group?.idField, 'id');
    expect(content.mode, ContentMode.text);
    expect(content.url, contains('{{chapter.id}}'));
  });

  test('索引搜索的规则声明了本地过滤条件', () {
    for (final file in <String>['lnovel.novel.acgn.json', 'wenku8.novel.acgn.json']) {
      final pack = RulePack.fromJson(readJson('$assetDir/$file'));
      final search = pack.capabilities[RuleCapability.search]! as SearchCapabilityRule;
      expect(search.mode, SearchMode.localIndex, reason: file);
      expect(search.index, isNotNull, reason: file);
      expect(search.filter?.script, isNotNull, reason: file);
    }
  });
}
