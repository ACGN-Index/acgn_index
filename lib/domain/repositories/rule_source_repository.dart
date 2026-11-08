import 'package:acgn_index/domain/entities/rule_source.dart';

/// 规则源的持久化入口。实现方负责规则包 JSON 的序列化与反序列化。
abstract interface class RuleSourceRepository {
  Stream<List<RuleSource>> watchAll();

  Future<List<RuleSource>> getAll();

  /// 以 `pack.meta.id` 为键新增或覆盖。
  Future<void> save(RuleSource source);

  /// 只切换启用状态，不改动规则内容。
  Future<void> setEnabled(String id, bool enabled);

  Future<void> delete(String id);
}
