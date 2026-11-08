import 'dart:async';

import 'package:acgn_index/data/builtin/builtin_rule_seeder.dart';
import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/repositories/drift_rule_source_repository.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全局数据库实例。测试时用 `ProviderScope(overrides: [...])` 换成内存库。
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(() {
    unawaited(database.close());
  });
  return database;
});

final Provider<RuleSourceRepository> ruleSourceRepositoryProvider = Provider<RuleSourceRepository>(
  (ref) => DriftRuleSourceRepository(ref.watch(databaseProvider).sourceDao),
);

final Provider<BuiltinRuleSeeder> builtinRuleSeederProvider = Provider<BuiltinRuleSeeder>(
  (ref) => BuiltinRuleSeeder(ref.watch(ruleSourceRepositoryProvider)),
);

/// 启动时同步一次内置规则集；失败只会记录日志，不阻断进入应用。
final FutureProvider<BuiltinRuleSeedResult> builtinRuleSeedProvider =
    FutureProvider<BuiltinRuleSeedResult>((ref) => ref.watch(builtinRuleSeederProvider).seed());
