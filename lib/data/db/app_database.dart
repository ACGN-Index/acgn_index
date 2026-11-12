import 'package:acgn_index/core/constants/app_constants.dart';
import 'package:acgn_index/data/db/daos/source_auth_dao.dart';
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

  /// 冗余的内容类型，避免列表查询解析规则 JSON。
  TextColumn get type => text().withDefault(const Constant('comic'))();

  /// `builtin` / `imported`，内置规则随应用更新。
  TextColumn get origin => text().withDefault(const Constant('imported'))();
  BoolColumn get readOnly => boolean().withDefault(const Constant(false))();

  /// 来源与合规说明，展示在规则列表。
  TextColumn get notice => text().withDefault(const Constant(''))();

  /// 聚合搜索时的排序权重，数值越小越靠前。
  IntColumn get priority => integer().withDefault(const Constant(0))();

  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  TextColumn get rulePackJson => text()();
  DateTimeColumn get installedAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

/// 规则登录凭据。
///
/// 与规则源分开存储：规则包只描述登录方式，真实 Cookie / 请求头不会进入
/// `rulePackJson`，也不会随规则导出。
class SourceAuthRecords extends Table {
  TextColumn get ruleId => text()();
  TextColumn get cookiesJson => text().withDefault(const Constant('{}'))();
  TextColumn get headersJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{ruleId};
}

@DriftDatabase(
  tables: [SourceRecords, SourceAuthRecords],
  daos: [SourceDao, SourceAuthDao],
)
class AppDatabase extends _$AppDatabase {
  /// 传入 `NativeDatabase.memory()` 即可在测试中使用内存库。
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: AppConstants.databaseName));

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => migrator.createAll(),
    onUpgrade: (migrator, from, to) async {
      if (from < 2) {
        await migrator.addColumn(sourceRecords, sourceRecords.type);
        await migrator.addColumn(sourceRecords, sourceRecords.origin);
        await migrator.addColumn(sourceRecords, sourceRecords.readOnly);
        await migrator.addColumn(sourceRecords, sourceRecords.notice);
        await migrator.addColumn(sourceRecords, sourceRecords.priority);
      }
      if (from < 3) {
        await migrator.createTable(sourceAuthRecords);
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
