import 'package:drift/drift.dart';

import '../app_database.dart';

part 'incomes_dao.g.dart';

/// Queries for recurring income and the schedule it lands on.
@DriftAccessor(tables: <Type>[Incomes])
class IncomesDao extends DatabaseAccessor<AppDatabase> with _$IncomesDaoMixin {
  IncomesDao(super.db);

  /// Every income, active first, then by name.
  ///
  /// Ordered in SQL rather than in Dart because the list a person sees is short
  /// and stable: a salary is read on every visit to the obligations screen, and
  /// the order must not depend on the order rows happen to come back in.
  Stream<List<IncomeRow>> watchAll({bool includeArchived = true}) {
    final SimpleSelectStatement<$IncomesTable, IncomeRow> query =
        select(incomes);
    if (!includeArchived) {
      query.where((Incomes t) => t.archivedAt.isNull());
    }
    query.orderBy(<OrderingTerm Function($IncomesTable)>[
      (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return query.watch();
  }

  Future<List<IncomeRow>> getAll({bool includeArchived = true}) {
    final SimpleSelectStatement<$IncomesTable, IncomeRow> query =
        select(incomes);
    if (!includeArchived) {
      query.where((Incomes t) => t.archivedAt.isNull());
    }
    query.orderBy(<OrderingTerm Function($IncomesTable)>[
      (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
      (t) => OrderingTerm.asc(t.name),
    ]);
    return query.get();
  }

  Future<IncomeRow?> getById(String id) =>
      (select(incomes)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<IncomeRow?> watchById(String id) =>
      (select(incomes)..where((t) => t.id.equals(id))).watchSingleOrNull();

  /// Writes the row, updating it when it already exists.
  ///
  /// Written through a companion with every value present, for the same reason
  /// the obligation DAO does it: `insertOnConflictUpdate` given the row itself
  /// skips its null fields, so clearing a day of the month or a note would
  /// appear to work and then quietly revert on the next read.
  Future<void> upsert(IncomeRow row) async {
    await transaction(() async {
      final int changed = await (update(incomes)
            ..where((t) => t.id.equals(row.id)))
          .write(row.toCompanion(false));
      if (changed == 0) await into(incomes).insert(row);
    });
  }

  /// Soft-archives or restores a record, leaving its history in place.
  Future<void> setArchivedAt(
    String id,
    DateTime? archivedAt,
    DateTime updatedAt,
  ) {
    return (update(incomes)..where((t) => t.id.equals(id))).write(
      IncomesCompanion(
        archivedAt: Value<DateTime?>(archivedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  /// Removes the row for good. Deleting an income removes a *rule*, never a
  /// payment: no money record is derived from this table, so nothing else has to
  /// be unwound afterwards.
  Future<int> deleteById(String id) =>
      (delete(incomes)..where((t) => t.id.equals(id))).go();
}
