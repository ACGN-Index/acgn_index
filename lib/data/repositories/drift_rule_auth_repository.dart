import 'dart:convert';

import 'package:acgn_index/core/logging/app_logger.dart';
import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/db/daos/source_auth_dao.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:drift/drift.dart';

/// 基于 Drift 的规则登录凭据存储。
class DriftRuleAuthRepository implements RuleAuthRepository {
  DriftRuleAuthRepository(this._dao);

  final SourceAuthDao _dao;

  @override
  Stream<Set<String>> watchLoggedInRuleIds() =>
      _dao.watchAll().map((rows) => rows.map((row) => row.ruleId).toSet());

  @override
  Future<RuleAuth?> find(String ruleId) async {
    final row = await _dao.findById(ruleId);
    return row == null ? null : _toEntity(row);
  }

  @override
  Future<void> save(RuleAuth auth) async {
    if (auth.isEmpty) {
      await _dao.deleteById(auth.ruleId);
      return;
    }
    await _dao.upsert(
      SourceAuthRecordsCompanion.insert(
        ruleId: auth.ruleId,
        cookiesJson: Value(jsonEncode(auth.cookies)),
        headersJson: Value(jsonEncode(auth.headers)),
        updatedAt: Value(auth.updatedAt),
      ),
    );
  }

  @override
  Future<void> delete(String ruleId) => _dao.deleteById(ruleId);

  RuleAuth _toEntity(SourceAuthRecord row) => RuleAuth(
    ruleId: row.ruleId,
    cookies: _decodeMap(row.ruleId, row.cookiesJson),
    headers: _decodeMap(row.ruleId, row.headersJson),
    updatedAt: row.updatedAt,
  );

  Map<String, String> _decodeMap(String ruleId, String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error, stackTrace) {
      AppLogger.of('rule-auth').warning('登录凭据 JSON 解析失败：$ruleId', error, stackTrace);
      return const <String, String>{};
    }
    if (decoded is! Map) {
      return const <String, String>{};
    }
    return <String, String>{
      for (final entry in decoded.entries) entry.key.toString(): entry.value.toString(),
    };
  }
}
