import 'package:drift/drift.dart';

import '../app_database.dart';

part 'people_dao.g.dart';

/// Queries for the people directory.
@DriftAccessor(tables: <Type>[People, Debts])
class PeopleDao extends DatabaseAccessor<AppDatabase> with _$PeopleDaoMixin {
  PeopleDao(super.db);

  /// Everyone, active first, then alphabetically.
  ///
  /// `COLLATE NOCASE` only affects Latin text; Arabic letters already sort in
  /// alphabetical order by code point, so one index serves both languages.
  Stream<List<PersonRow>> watchAll() {
    return (select(people)
          ..orderBy(<OrderingTerm Function($PeopleTable)>[
            (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
            (t) => OrderingTerm.asc(t.name.collate(Collate.noCase)),
          ]))
        .watch();
  }

  Future<List<PersonRow>> getAll() => select(people).get();

  Stream<PersonRow?> watchById(String id) =>
      (select(people)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<PersonRow?> getById(String id) =>
      (select(people)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Case-insensitive duplicate check used by the form validator.
  Future<PersonRow?> findByName(String name) {
    return (select(people)
          ..where((t) => t.name.lower().equals(name.trim().toLowerCase()))
          ..limit(1))
        .getSingleOrNull();
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
    Future<void> upsert(PersonRow row) async {
    await transaction(() async {
      final int changed = await (update(people)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(row.toCompanion(false));
      if (changed == 0) await into(people).insert(row);
    });
  }

  Future<void> setArchived(String id, DateTime? archivedAt, DateTime updatedAt) {
    return (update(people)..where((t) => t.id.equals(id))).write(
      PeopleCompanion(
        archivedAt: Value<DateTime?>(archivedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(people)..where((t) => t.id.equals(id))).go();

  /// How many people are not archived.
  Future<int> countActive() async {
    final Expression<int> count = people.id.count();
    final JoinedSelectStatement<$PeopleTable, PersonRow> query = selectOnly(people)
      ..addColumns(<Expression<Object>>[count])
      ..where(people.archivedAt.isNull());
    final List<TypedResult> rows = await query.get();
    return rows.isEmpty ? 0 : (rows.first.read(count) ?? 0);
  }
}
