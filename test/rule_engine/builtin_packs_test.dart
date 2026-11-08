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

    expect(packs, hasLength(7));

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

  test('Kazumi 改写规则默认关闭且全为动漫源', () {
    final manifest = readJson('$assetDir/index.json');
    final kazumiPacks = (manifest['packs'] as List<Object?>)
        .cast<Map<String, Object?>>()
        .where((entry) => (entry['id']! as String).startsWith('builtin.kazumi.'))
        .toList();

    expect(kazumiPacks, hasLength(3));
    for (final entry in kazumiPacks) {
      expect(entry['enabledByDefault'], isFalse, reason: '${entry['id']}');
      final pack = RulePack.fromJson(readJson('$assetDir/${entry['file']}'));
      expect(pack.meta.type.wireName, 'anime', reason: pack.id);
      expect(pack.meta.notice, contains('KazumiRules'), reason: pack.id);
    }
  });

  test('视频规则能从目录直链播放，其余规则至少提供目录', () {
    for (final file in <String>['girigirilove.anime.acgn.json', 'mxdm.anime.acgn.json']) {
      final pack = RulePack.fromJson(readJson('$assetDir/$file'));
      final content = pack.capabilities[RuleCapability.content]! as ContentCapabilityRule;
      expect(content.mode, ContentMode.video, reason: file);
      expect(pack.capabilities[RuleCapability.toc], isNotNull, reason: file);
    }

    final girigiri = RulePack.fromJson(readJson('$assetDir/girigirilove.anime.acgn.json'));
    final content = girigiri.capabilities[RuleCapability.content]! as ContentCapabilityRule;
    expect(content.url.trim(), isEmpty, reason: '播放地址由目录条目提供');
    expect(content.fields['url']?.constant, contains('chapter.url'));

    for (final file in <String>['tvtfun.anime.acgn.json']) {
      final pack = RulePack.fromJson(readJson('$assetDir/$file'));
      expect(pack.capabilities[RuleCapability.content], isNull, reason: file);
      expect(pack.capabilities[RuleCapability.toc], isNotNull, reason: file);
    }
  });
}
