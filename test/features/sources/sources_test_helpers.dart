import 'dart:async';

import 'package:acgn_index/core/models/media_type.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/domain/repositories/rule_source_repository.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';

/// 内存仓储，避免 widget 测试依赖 Drift 的异步查询。
class FakeRuleSourceRepository implements RuleSourceRepository {
  FakeRuleSourceRepository([List<RuleSource> sources = const <RuleSource>[]])
    : _sources = List<RuleSource>.of(sources);

  final List<RuleSource> _sources;
  final StreamController<List<RuleSource>> _controller =
      StreamController<List<RuleSource>>.broadcast();

  @override
  Stream<List<RuleSource>> watchAll() async* {
    yield List<RuleSource>.unmodifiable(_sources);
    yield* _controller.stream;
  }

  @override
  Future<List<RuleSource>> getAll() async => List<RuleSource>.unmodifiable(_sources);

  @override
  Future<void> save(RuleSource source) async {
    _sources.removeWhere((item) => item.id == source.id);
    _sources.add(source);
    _emit();
  }

  @override
  Future<void> setEnabled(String id, bool enabled) async {
    final index = _sources.indexWhere((item) => item.id == id);
    if (index < 0) {
      return;
    }
    _sources[index] = _sources[index].copyWith(enabled: enabled);
    _emit();
  }

  @override
  Future<void> delete(String id) async {
    _sources.removeWhere((item) => item.id == id);
    _emit();
  }

  void _emit() => _controller.add(List<RuleSource>.unmodifiable(_sources));

  Future<void> close() => _controller.close();
}

/// 构造一个最小可用的已导入规则源，供删除等交互测试使用。
RuleSource importedSource({
  required String id,
  required String name,
  MediaType type = MediaType.comic,
  bool enabled = true,
}) => RuleSource(
  pack: RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: RuleMeta(
      id: id,
      name: name,
      type: type,
      baseUrl: 'https://example.invalid',
      version: '1.0.0',
      author: 'tester',
      lang: 'zh',
    ),
    capabilities: <RuleCapability, CapabilityRule>{
      RuleCapability.search: const SearchCapabilityRule(
        url: '/search?q={{key}}',
        fields: <String, FieldRule>{'title': FieldRule(selector: '.title')},
      ),
    },
  ),
  enabled: enabled,
  installedAt: DateTime(2026, 3, 15),
);

/// 构造一个最小可用的内置规则源，供 UI 测试使用。
RuleSource builtinSource({
  required String id,
  required String name,
  required MediaType type,
  required bool enabled,
  required int priority,
}) => RuleSource(
  pack: RulePack(
    schemaVersion: kSupportedSchemaVersion,
    meta: RuleMeta(
      id: id,
      name: name,
      type: type,
      baseUrl: 'https://example.invalid',
      version: '1.0.0',
      author: 'acgn_index',
      lang: 'zh',
      notice: '测试用内置规则',
    ),
    capabilities: <RuleCapability, CapabilityRule>{
      RuleCapability.search: const SearchCapabilityRule(
        url: '/search?q={{key}}',
        fields: <String, FieldRule>{'title': FieldRule(selector: '.title')},
      ),
    },
  ),
  enabled: enabled,
  installedAt: DateTime(2026, 3, 15),
  origin: RuleSourceOrigin.builtin,
  readOnly: true,
  priority: priority,
);
