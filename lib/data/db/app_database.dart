import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/data/db/daos/source_dao.dart';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

/// 已安装的规则源。
///
/// `rulePackJson` 保存规则原文（唯一事实来源），`name`/`baseUrl`/`version`
/// 是为了列表查询免解析而冗余的列，写入时必须与 JSON 保持一致。
class SourceRecords extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get baseUrl => text()();
  TextColumn get version => text().withDefault(const Constant('0.0.0'))();
  IntColumn get schemaVersion => integer().withDefault(const Constant(1))();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get rulePackJson => text()();
  DateTimeColumn get installedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(tables: [SourceRecords], daos: [SourceDao])
class AppDatabase extends _$AppDatabase {
  /// 传入 `NativeDatabase.memory()` 即可在测试中使用内存库。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
