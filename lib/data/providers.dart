import 'dart:async';

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
