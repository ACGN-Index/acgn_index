import 'dart:convert';

import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/db/daos/source_dao.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/rule_engine/models/rule_pack.dart';
import 'package:drift/drift.dart';

/// 基于 Drift 的规则源存储。
class DriftRuleSourceRepository implements RuleSourceRepository {
  DriftRuleSourceRepository(this._dao);

  final SourceDao _dao;

  @override
  Stream<List<RuleSource>> watchAll() => _dao.watchAll().map(_toEntities);

  @override
  Future<List<RuleSource>> getAll() async => _toEntities(await _dao.getAll());

  @override
  Future<void> save(RuleSource source) {
    final meta = source.pack.meta;
    final record = SourceRecordsCompanion.insert(
      id: meta.id,
      name: meta.name,
      baseUrl: meta.baseUrl,
      rulePackJson: jsonEncode(source.pack.toJson()),
      version: Value(meta.version),
      schemaVersion: Value(source.pack.schemaVersion),
      enabled: Value(source.enabled),
      installedAt: Value(source.installedAt),
      updatedAt: Value(DateTime.now()),
    );
    return _dao.upsert(record);
  }

  @override
  Future<void> delete(String id) async {
    await _dao.deleteById(id);
  }

  List<RuleSource> _toEntities(List<SourceRecord> rows) =>
      rows.map(_toEntity).toList(growable: false);

  RuleSource _toEntity(SourceRecord row) => RuleSource(
    pack: RulePack.parse(row.rulePackJson),
    enabled: row.enabled,
    installedAt: row.installedAt,
  );
}
