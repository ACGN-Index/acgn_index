import 'package:acgn_index/domain/entities/rule_auth.dart';

/// 规则登录凭据的本地存储。
abstract interface class RuleAuthRepository {
  /// 订阅当前有登录凭据的规则 id，供规则列表展示登录状态。
  Stream<Set<String>> watchLoggedInRuleIds();

  Future<RuleAuth?> find(String ruleId);

  /// 保存凭据；[RuleAuth.isEmpty] 为 true 时等价于删除。
  Future<void> save(RuleAuth auth);

  Future<void> delete(String ruleId);
}
