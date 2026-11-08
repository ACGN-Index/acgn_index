import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/repositories/drift_rule_source_repository.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rule_engine/demo_pack_helpers.dart';

void main() {
  late AppDatabase database;
  late DriftRuleSourceRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRuleSourceRepository(database.sourceDao);
  });

  tearDown(() => database.close());

  RuleSource buildSource({bool enabled = true}) => RuleSource(
    pack: RulePack.fromJson(loadDemoPack()),
    enabled: enabled,
    installedAt: DateTime(2026, 3, 15),
  );

  test('保存后能完整读回规则源', () async {
    await repository.save(buildSource());

    final sources = await repository.getAll();

    expect(sources, hasLength(1));
    final source = sources.single;
    expect(source.id, 'demo.mock');
    expect(source.enabled, isTrue);
    expect(source.pack.capabilities.length, RuleCapability.values.length);
    expect(source.pack.meta.type.wireName, 'comic');
  });

  test('同 id 再次保存会覆盖而不是新增', () async {
    await repository.save(buildSource());
    await repository.save(buildSource(enabled: false));

    final sources = await repository.getAll();

    expect(sources, hasLength(1));
    expect(sources.single.enabled, isFalse);
  });

  test('按 id 删除后列表为空', () async {
    await repository.save(buildSource());

    await repository.delete('demo.mock');

    expect(await repository.getAll(), isEmpty);
  });

  test('watchAll 会推送最新数据', () async {
    expect(await repository.watchAll().first, isEmpty);

    await repository.save(buildSource());
    final sources = await repository.watchAll().first;

    expect(sources, hasLength(1));
  });
}
