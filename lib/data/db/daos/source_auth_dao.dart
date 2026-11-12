import 'package:acgn_index/data/db/app_database.dart';
import 'package:drift/drift.dart';

part 'source_auth_dao.g.dart';

@DriftAccessor(tables: [SourceAuthRecords])
class SourceAuthDao extends DatabaseAccessor<AppDatabase> with _$SourceAuthDaoMixin {
  SourceAuthDao(super.attachedDatabase);

  Stream<List<SourceAuthRecord>> watchAll() => select(sourceAuthRecords).watch();

  Future<SourceAuthRecord?> findById(String ruleId) =>
      (select(sourceAuthRecords)..where((table) => table.ruleId.equals(ruleId))).getSingleOrNull();

  Future<void> upsert(SourceAuthRecordsCompanion record) =>
      into(sourceAuthRecords).insertOnConflictUpdate(record);

  Future<int> deleteById(String ruleId) =>
      (delete(sourceAuthRecords)..where((table) => table.ruleId.equals(ruleId))).go();
}
