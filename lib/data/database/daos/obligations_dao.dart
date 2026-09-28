import 'package:drift/drift.dart';

import '../../../core/utils/dates.dart';
import '../../../domain/enums/obligation_enums.dart';
import '../app_database.dart';

part 'obligations_dao.g.dart';

/// Queries for recurring commitments and the periods they generate.
@DriftAccessor(tables: <Type>[Obligations, ObligationOccurrences])
class ObligationsDao extends DatabaseAccessor<AppDatabase>
    with _$ObligationsDaoMixin {
  ObligationsDao(super.db);

  Stream<List<ObligationRow>> watchAll() {
    return (select(obligations)
          ..orderBy(<OrderingTerm Function($ObligationsTable)>[
            (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
            (t) => OrderingTerm.asc(t.nextDueAt),
          ]))
        .watch();
  }

  Future<List<ObligationRow>> getAll() => select(obligations).get();

  Stream<ObligationRow?> watchById(String id) =>
      (select(obligations)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<ObligationRow?> getById(String id) =>
      (select(obligations)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
    Future<void> upsert(ObligationRow row) async {
    await transaction(() async {
      final int changed = await (update(obligations)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(row.toCompanion(false));
      if (changed == 0) await into(obligations).insert(row);
    });
  }

  Future<void> setArchivedAt(
    String id,
    DateTime? archivedAt,
    DateTime updatedAt,
  ) {
    return (update(obligations)..where((t) => t.id.equals(id))).write(
      ObligationsCompanion(
        archivedAt: Value<DateTime?>(archivedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(obligations)..where((t) => t.id.equals(id))).go();

  // --- Occurrences ---------------------------------------------------------

  Stream<List<ObligationOccurrenceRow>> watchOccurrences() {
    return (select(obligationOccurrences)
          ..orderBy(<OrderingTerm Function($ObligationOccurrencesTable)>[
            (t) => OrderingTerm.asc(t.dueAt),
          ]))
        .watch();
  }

  Future<List<ObligationOccurrenceRow>> getOccurrences() =>
      select(obligationOccurrences).get();

  /// The unpaid periods that fall inside a window, with the commitments they
  /// belong to.
  ///
  /// What a reminder plan needs, and no more: a period that is already paid, or
  /// that falls outside the window, cannot produce a notification. Index-backed
  /// by `idx_occurrences_due`, where reading every period of every commitment
  /// costs a full scan on each save.
  Future<List<ObligationOccurrenceRow>> occurrencesBetween({
    required DateTime from,
    required DateTime to,
  }) {
    return (select(obligationOccurrences)
          ..where(
            (ObligationOccurrences t) =>
                t.dueAt.isBetweenValues(toIsoDate(from), toIsoDate(to)) &
                // "Open" is the domain's own rule, so a status added later
                // cannot quietly fall out of the reminder plan.
                t.status.isIn(
                  ObligationStatus.values
                      .where((ObligationStatus s) => s.isOpen)
                      .map((ObligationStatus s) => s.name)
                      .toList(),
                ),
          )
          ..orderBy(<OrderingTerm Function($ObligationOccurrencesTable)>[
            (t) => OrderingTerm.asc(t.dueAt),
          ]))
        .get();
  }

  /// The commitments behind a set of periods.
  Future<List<ObligationRow>> getByIds(Iterable<String> ids) {
    final List<String> wanted = ids.toSet().toList(growable: false);
    if (wanted.isEmpty) {
      return Future<List<ObligationRow>>.value(const <ObligationRow>[]);
    }
    return (select(obligations)..where((t) => t.id.isIn(wanted))).get();
  }

  Stream<List<ObligationOccurrenceRow>> watchOccurrencesFor(String obligationId) {
    return (select(obligationOccurrences)
          ..where((t) => t.obligationId.equals(obligationId))
          ..orderBy(<OrderingTerm Function($ObligationOccurrencesTable)>[
            (t) => OrderingTerm.desc(t.dueAt),
          ]))
        .watch();
  }

  Future<List<ObligationOccurrenceRow>> getOccurrencesFor(String obligationId) {
    return (select(obligationOccurrences)
          ..where((t) => t.obligationId.equals(obligationId)))
        .get();
  }

  Future<ObligationOccurrenceRow?> getOccurrenceById(String id) {
    return (select(obligationOccurrences)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Period keys already materialised for an obligation.
  ///
  /// Used when extending a schedule so the same period is never generated
  /// twice; the unique constraint on `(obligation_id, period_key)` is the
  /// backstop.
  Future<Set<String>> existingPeriodKeys(String obligationId) async {
    final JoinedSelectStatement<$ObligationOccurrencesTable,
            ObligationOccurrenceRow>
        query = selectOnly(obligationOccurrences)
          ..addColumns(<Expression<Object>>[obligationOccurrences.periodKey])
          ..where(obligationOccurrences.obligationId.equals(obligationId));
    final List<TypedResult> rows = await query.get();
    return rows
        .map((TypedResult row) => row.read(obligationOccurrences.periodKey))
        .whereType<String>()
        .toSet();
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Without both, clearing a payment note or a period's paid stamp
  /// appears to work and then quietly reverts.
    Future<void> upsertOccurrence(ObligationOccurrenceRow row) async {
    await transaction(() async {
      final int changed = await (update(obligationOccurrences)
            ..where((t) => t.id.equals(row.id)))
          .write(row);
      if (changed == 0) await into(obligationOccurrences).insert(row);
    });
  }

  /// Writes several periods at once, in one transaction.
  ///
  /// Used when materialising a schedule. A handful of rows per obligation, so the
  /// per-row update-or-insert is cheap and keeps the null-handling rule in one
  /// place rather than having a second write path with different semantics.
  Future<void> upsertOccurrences(List<ObligationOccurrenceRow> rows) async {
    if (rows.isEmpty) return;
    await transaction(() async {
      for (final ObligationOccurrenceRow row in rows) {
        final int changed = await (update(obligationOccurrences)
              ..where((t) => t.id.equals(row.id)))
            .write(row);
        if (changed == 0) await into(obligationOccurrences).insert(row);
      }
    });
  }

  Future<void> deleteOccurrence(String id) =>
      (delete(obligationOccurrences)..where((t) => t.id.equals(id))).go();

  Future<void> deleteOccurrencesFor(String obligationId) {
    return (delete(obligationOccurrences)
          ..where((t) => t.obligationId.equals(obligationId)))
        .go();
  }
}
