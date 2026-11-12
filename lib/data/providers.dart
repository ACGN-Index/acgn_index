import 'dart:async';

import 'package:acgn_index/data/builtin/builtin_rule_seeder.dart';
import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/network/authenticated_rule_http_client.dart';
import 'package:acgn_index/data/network/dio_rule_http_client.dart';
import 'package:acgn_index/data/repositories/dandanplay_danmaku_repository.dart';
import 'package:acgn_index/data/repositories/drift_rule_auth_repository.dart';
import 'package:acgn_index/data/repositories/drift_rule_source_repository.dart';
import 'package:acgn_index/data/repositories/rule_content_source_repository.dart';
import 'package:acgn_index/data/repositories/rule_discover_feed_repository.dart';
import 'package:acgn_index/data/repositories/rule_work_repository.dart';
import 'package:acgn_index/data/repositories/rule_work_search_repository.dart';
import 'package:acgn_index/data/sandbox/flutter_js_runtime.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/content_source_repository.dart';
import 'package:acgn_index/domain/repositories/danmaku_library_repository.dart';
import 'package:acgn_index/domain/repositories/discover_feed_repository.dart';
import 'package:acgn_index/domain/repositories/rule_auth_repository.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/domain/repositories/work_repository.dart';
import 'package:acgn_index/domain/repositories/work_search_repository.dart';
import 'package:acgn_index/rule_engine/network/rule_http_client.dart';
import 'package:acgn_index/rule_engine/pipeline/content_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/detail_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/field_evaluator.dart';
import 'package:acgn_index/rule_engine/pipeline/search_pipeline.dart';
import 'package:acgn_index/rule_engine/pipeline/toc_pipeline.dart';
import 'package:acgn_index/rule_engine/sandbox/js_runtime.dart';
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

/// 规则登录凭据；与规则包分开存储，避免凭据进入规则 JSON。
final Provider<RuleAuthRepository> ruleAuthRepositoryProvider = Provider<RuleAuthRepository>(
  (ref) => DriftRuleAuthRepository(ref.watch(databaseProvider).sourceAuthDao),
);

final StreamProvider<Set<String>> loggedInRuleIdsProvider = StreamProvider<Set<String>>(
  (ref) => ref.watch(ruleAuthRepositoryProvider).watchLoggedInRuleIds(),
);

final Provider<BuiltinRuleSeeder> builtinRuleSeederProvider = Provider<BuiltinRuleSeeder>(
  (ref) => BuiltinRuleSeeder(ref.watch(ruleSourceRepositoryProvider)),
);

final StreamProvider<List<RuleSource>> ruleSourcesProvider = StreamProvider<List<RuleSource>>(
  (ref) => ref.watch(ruleSourceRepositoryProvider).watchAll(),
);

/// 启动时同步一次内置规则集；失败只会记录日志，不阻断进入应用。
final FutureProvider<BuiltinRuleSeedResult> builtinRuleSeedProvider =
    FutureProvider<BuiltinRuleSeedResult>((ref) => ref.watch(builtinRuleSeederProvider).seed());

final Provider<RuleHttpClient> ruleHttpClientProvider = Provider<RuleHttpClient>((ref) {
  final client = AuthenticatedRuleHttpClient(
    DioRuleHttpClient(),
    ref.watch(ruleAuthRepositoryProvider),
  );
  ref.onDispose(client.close);
  return client;
});

/// 外部弹幕库；凭证由用户在播放器面板里配置，不内置。
final Provider<DanmakuLibraryRepository> danmakuLibraryRepositoryProvider =
    Provider<DanmakuLibraryRepository>(
      (ref) => DandanplayDanmakuRepository(httpClient: ref.watch(ruleHttpClientProvider)),
    );

final Provider<JsRuntime> jsRuntimeProvider = Provider<JsRuntime>((ref) {
  final runtime = FlutterJsRuntime();
  ref.onDispose(() {
    unawaited(runtime.dispose());
  });
  return runtime;
});

final Provider<FieldEvaluator> fieldEvaluatorProvider = Provider<FieldEvaluator>(
  (ref) => FieldEvaluator(jsRuntime: ref.watch(jsRuntimeProvider)),
);

final Provider<RuleSearchPipeline> ruleSearchPipelineProvider = Provider<RuleSearchPipeline>(
  (ref) => RuleSearchPipeline(
    httpClient: ref.watch(ruleHttpClientProvider),
    evaluator: ref.watch(fieldEvaluatorProvider),
  ),
);

final Provider<RuleDetailService> ruleDetailPipelineProvider = Provider<RuleDetailService>(
  (ref) => RuleDetailPipeline(
    httpClient: ref.watch(ruleHttpClientProvider),
    evaluator: ref.watch(fieldEvaluatorProvider),
  ),
);

final Provider<RuleTocService> ruleTocPipelineProvider = Provider<RuleTocService>(
  (ref) => RuleTocPipeline(
    httpClient: ref.watch(ruleHttpClientProvider),
    evaluator: ref.watch(fieldEvaluatorProvider),
  ),
);

final Provider<RuleContentService> ruleContentPipelineProvider = Provider<RuleContentService>(
  (ref) => RuleContentPipeline(
    httpClient: ref.watch(ruleHttpClientProvider),
    evaluator: ref.watch(fieldEvaluatorProvider),
  ),
);

final Provider<DiscoverFeedRepository> discoverFeedRepositoryProvider =
    Provider<DiscoverFeedRepository>(
      (ref) => RuleDiscoverFeedRepository(
        ref.watch(ruleSourceRepositoryProvider),
        ref.watch(ruleSearchPipelineProvider),
        ref.watch(ruleAuthRepositoryProvider),
      ),
    );

final Provider<WorkRepository> workRepositoryProvider = Provider<WorkRepository>(
  (ref) => RuleWorkRepository(
    ref.watch(ruleSourceRepositoryProvider),
    ref.watch(ruleDetailPipelineProvider),
    ref.watch(ruleTocPipelineProvider),
    ref.watch(ruleContentPipelineProvider),
    ref.watch(ruleAuthRepositoryProvider),
  ),
);

/// 跨规则搜索：并发请求所有启用规则的 `search` 接口，结果按规则分组。
final Provider<WorkSearchRepository> workSearchRepositoryProvider = Provider<WorkSearchRepository>(
  (ref) => RuleWorkSearchRepository(
    ref.watch(ruleSourceRepositoryProvider),
    ref.watch(ruleSearchPipelineProvider),
    ref.watch(ruleAuthRepositoryProvider),
  ),
);

/// 仅资料源详情页的跨源检索；与发现页聚合共用搜索流水线。
final Provider<ContentSourceRepository> contentSourceRepositoryProvider =
    Provider<ContentSourceRepository>(
      (ref) => RuleContentSourceRepository(
        ref.watch(ruleSourceRepositoryProvider),
        ref.watch(ruleSearchPipelineProvider),
        ref.watch(ruleAuthRepositoryProvider),
      ),
    );
