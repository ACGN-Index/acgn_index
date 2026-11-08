import 'dart:convert';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/core/utils/json_utils.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:acgn_index/rule_engine/pipeline/rule_pack_validator.dart';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

/// 内置规则集的清单条目。
class _ManifestEntry {
  const _ManifestEntry({
    required this.id,
    required this.file,
    required this.enabledByDefault,
  });

  final String id;
  final String file;
  final bool enabledByDefault;
}

/// 一次播种的结果，供日志与测试断言。
class BuiltinRuleSeedResult {
  const BuiltinRuleSeedResult({
    this.installed = const <String>[],
    this.updated = const <String>[],
    this.skipped = const <String>[],
  });

  final List<String> installed;
  final List<String> updated;
  final List<String> skipped;

  bool get isEmpty => installed.isEmpty && updated.isEmpty && skipped.isEmpty;
}

/// 把 `assets/rules/builtin` 下的规则包写入本地库。
///
/// 约定：内置包只读；用户改动过的同 id 包不会被覆盖；版本号更高时才更新，
/// 并保留用户的启用状态。单个包失败只记录日志，不影响其它包与启动流程。
class BuiltinRuleSeeder {
  BuiltinRuleSeeder(
    this._repository, {
    AssetBundle? bundle,
    this.assetDir = 'assets/rules/builtin',
  }) : _bundle = bundle ?? rootBundle;

  static const String _manifestFile = 'index.json';

  final RuleSourceRepository _repository;
  final AssetBundle _bundle;
  final String assetDir;
  final Logger _logger = AppLogger.of('builtin-rules');

  Future<BuiltinRuleSeedResult> seed() async {
    final installed = <String>[];
    final updated = <String>[];
    final skipped = <String>[];

    final List<_ManifestEntry> entries;
    try {
      entries = await _loadManifest();
    } on Object catch (error, stackTrace) {
      _logger.severe('读取内置规则清单失败', error, stackTrace);
      return const BuiltinRuleSeedResult();
    }

    final existing = <String, RuleSource>{
      for (final source in await _repository.getAll()) source.id: source,
    };

    for (var index = 0; index < entries.length; index++) {
      final entry = entries[index];
      try {
        final pack = await _loadPack(entry);
        if (pack == null) {
          skipped.add(entry.id);
          continue;
        }
        final current = existing[entry.id];
        if (current == null) {
          await _repository.save(
            _builtinSource(
              pack: pack,
              enabled: entry.enabledByDefault,
              priority: index,
              installedAt: DateTime.now(),
            ),
          );
          installed.add(entry.id);
          continue;
        }
        if (current.origin != RuleSourceOrigin.builtin) {
          // 用户自己导入过同 id 的规则，尊重用户版本。
          skipped.add(entry.id);
          continue;
        }
        if (!_isNewerVersion(pack.meta.version, current.version)) {
          continue;
        }
        await _repository.save(
          _builtinSource(
            pack: pack,
            enabled: current.enabled,
            priority: index,
            installedAt: current.installedAt,
          ),
        );
        updated.add(entry.id);
      } on Object catch (error, stackTrace) {
        _logger.severe('写入内置规则 ${entry.id} 失败', error, stackTrace);
        skipped.add(entry.id);
      }
    }

    _logger.info(
      '内置规则同步完成：新增 ${installed.length}，更新 ${updated.length}，跳过 ${skipped.length}',
    );
    return BuiltinRuleSeedResult(installed: installed, updated: updated, skipped: skipped);
  }

  RuleSource _builtinSource({
    required RulePack pack,
    required bool enabled,
    required int priority,
    required DateTime installedAt,
  }) => RuleSource(
    pack: pack,
    enabled: enabled,
    installedAt: installedAt,
    origin: RuleSourceOrigin.builtin,
    readOnly: true,
    priority: priority,
  );

  Future<List<_ManifestEntry>> _loadManifest() async {
    final raw = await _bundle.loadString('$assetDir/$_manifestFile');
    final json = asJsonMap(jsonDecode(raw), path: 'builtinIndex');
    final packs = json.listOrNull('packs') ?? const <Object?>[];
    final entries = <_ManifestEntry>[];
    for (final item in packs) {
      final map = asJsonMap(item, path: 'builtinIndex.packs');
      final id = map.stringOrNull('id');
      final file = map.stringOrNull('file');
      if (id == null || id.isEmpty || file == null || file.isEmpty) {
        _logger.warning('忽略无效的内置规则清单条目：$map');
        continue;
      }
      entries.add(
        _ManifestEntry(
          id: id,
          file: file,
          enabledByDefault: map.boolOrNull('enabledByDefault') ?? false,
        ),
      );
    }
    return entries;
  }

  Future<RulePack?> _loadPack(_ManifestEntry entry) async {
    final raw = await _bundle.loadString('$assetDir/${entry.file}');
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      _logger.severe('内置规则 ${entry.file} 不是合法 JSON：${error.message}');
      return null;
    }
    final json = asJsonMap(decoded, path: entry.file);
    final validation = const RulePackValidator().validate(json);
    if (!validation.isValid) {
      _logger.severe(
        '内置规则 ${entry.id} 未通过校验：'
        '${validation.errors.map((issue) => issue.toString()).join('; ')}',
      );
      return null;
    }
    final pack = RulePack.fromJson(json);
    if (pack.id != entry.id) {
      _logger.severe('内置规则 ${entry.file} 的 id 与清单不一致：${pack.id}');
      return null;
    }
    return pack;
  }
}

/// 逐段比较 `1.2.3` 形式的版本号，`a` 比 `b` 新时返回 true。
bool _isNewerVersion(String a, String b) {
  final left = _splitVersion(a);
  final right = _splitVersion(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final l = index < left.length ? left[index] : 0;
    final r = index < right.length ? right[index] : 0;
    if (l != r) {
      return l > r;
    }
  }
  return false;
}

List<int> _splitVersion(String value) {
  final main = value.split('+').first.split('-').first;
  return main.split('.').map((part) => int.tryParse(part.trim()) ?? 0).toList(growable: false);
}
