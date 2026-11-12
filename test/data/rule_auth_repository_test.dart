import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/repositories/drift_rule_auth_repository.dart';
import 'package:acgn_index/data/repositories/drift_rule_source_repository.dart';
import 'package:acgn_index/domain/entities/rule_auth.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:acgn_index/rule_engine/rule_engine.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../rule_engine/demo_pack_helpers.dart';

void main() {
  late AppDatabase database;
  late DriftRuleAuthRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRuleAuthRepository(database.sourceAuthDao);
  });

  tearDown(() => database.close());

  RuleAuth buildAuth() => RuleAuth(
    ruleId: 'demo.mock',
    cookies: const <String, String>{'sessionid': 'abc'},
    headers: const <String, String>{'Authorization': 'Bearer token'},
    updatedAt: DateTime(2026, 3, 15),
  );

  test('保存后能完整读回凭据', () async {
    await repository.save(buildAuth());

    final auth = await repository.find('demo.mock');

    expect(auth, isNotNull);
    expect(auth!.cookies['sessionid'], 'abc');
    expect(auth.headers['Authorization'], 'Bearer token');
    expect(auth.updatedAt, DateTime(2026, 3, 15));
  });

  test('空凭据等价于删除', () async {
    await repository.save(buildAuth());
    await repository.save(RuleAuth(ruleId: 'demo.mock', updatedAt: DateTime(2026)));

    expect(await repository.find('demo.mock'), isNull);
  });

  test('delete 会移除凭据', () async {
    await repository.save(buildAuth());

    await repository.delete('demo.mock');

    expect(await repository.find('demo.mock'), isNull);
  });

  test('watchLoggedInRuleIds 推送登录状态', () async {
    expect(await repository.watchLoggedInRuleIds().first, isEmpty);

    await repository.save(buildAuth());

    expect(await repository.watchLoggedInRuleIds().first, <String>{'demo.mock'});
  });

  test('删除规则时一并清理登录凭据', () async {
    final sourceRepository = DriftRuleSourceRepository(database.sourceDao);
    await sourceRepository.save(
      RuleSource(
        pack: RulePack.fromJson(loadDemoPack()),
        enabled: true,
        installedAt: DateTime(2026),
      ),
    );
    await repository.save(buildAuth());

    await sourceRepository.delete('demo.mock');

    expect(await sourceRepository.getAll(), isEmpty);
    expect(await repository.find('demo.mock'), isNull);
  });
}
