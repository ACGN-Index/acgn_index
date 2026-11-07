import 'package:acgn_index/data/db/app_database.dart';
import 'package:drift/drift.dart';

part 'source_dao.g.dart';

@DriftAccessor(tables: [SourceRecords])
class SourceDao extends DatabaseAccessor<AppDatabase> with _$SourceDaoMixin {
  SourceDao(super.attachedDatabase);

  Stream<List<SourceRecord>> watchAll() {
    final query = select(sourceRecords)..orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<List<SourceRecord>> getAll() => select(sourceRecords).get();

  Future<SourceRecord?> findById(String id) =>
      (select(sourceRecords)..where((table) => table.id.equals(id))).getSingleOrNull();

  Future<void> upsert(SourceRecordsCompanion record) =>
      into(sourceRecords).insertOnConflictUpdate(record);

  Future<int> deleteById(String id) =>
      (delete(sourceRecords)..where((table) => table.id.equals(id))).go();
}
