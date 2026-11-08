import 'package:acgn_index/data/builtin/builtin_rule_seeder.dart';
import 'package:acgn_index/data/db/app_database.dart';
import 'package:acgn_index/data/repositories/drift_rule_source_repository.dart';
import 'package:acgn_index/domain/entities/rule_source.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  late DriftRuleSourceRepository repository;
  late BuiltinRuleSeeder seeder;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftRuleSourceRepository(database.sourceDao);
    seeder = BuiltinRuleSeeder(repository);
  });

  tearDown(() => database.close());

  test('首次启动写入内置规则集', () async {
    final result = await seeder.seed();

    expect(result.installed, hasLength(4));
    final sources = await repository.getAll();
    expect(sources, hasLength(4));
    expect(sources.every((source) => source.isBuiltin), isTrue);
    expect(sources.every((source) => source.readOnly), isTrue);

    final byId = <String, RuleSource>{for (final source in sources) source.id: source};
    expect(byId['builtin.bangumi.anime']?.enabled, isTrue);
    expect(byId['builtin.bangumi.comic']?.enabled, isTrue);
    expect(byId['builtin.lnovel.novel']?.enabled, isFalse);
    expect(byId['builtin.wenku8.novel']?.enabled, isFalse);
    expect(byId['builtin.wenku8.novel']?.priority, 3);
  });

  test('重复启动不会重复写入', () async {
    await seeder.seed();
    final result = await seeder.seed();

    expect(result.isEmpty, isTrue);
    expect(await repository.getAll(), hasLength(4));
  });

  test('更新内置规则时保留用户的启用状态', () async {
    await seeder.seed();
    await repository.setEnabled('builtin.bangumi.anime', false);

    await seeder.seed();

    final sources = await repository.getAll();
    final anime = sources.firstWhere((source) => source.id == 'builtin.bangumi.anime');
    expect(anime.enabled, isFalse);
  });
}
