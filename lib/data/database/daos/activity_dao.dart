import 'package:drift/drift.dart';

import '../../../domain/enums/activity_enums.dart';
import '../../../domain/enums/obligation_enums.dart';
import '../app_database.dart';

part 'activity_dao.g.dart';

/// Queries for the append-only activity feed and the cached monthly summaries.
@DriftAccessor(tables: <Type>[ActivityEntries, MonthlySummaries])
class ActivityDao extends DatabaseAccessor<AppDatabase>
    with _$ActivityDaoMixin {
  ActivityDao(super.db);

  /// The most recent [limit] entries, newest first.
  Stream<List<ActivityEntryRow>> watchRecent({int limit = 30}) {
    return (select(activityEntries)
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ])
          ..limit(limit))
        .watch();
  }

  Future<List<ActivityEntryRow>> getRecent({int limit = 30}) {
    return (select(activityEntries)
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ])
          ..limit(limit))
        .get();
  }

  /// Activity for one record, used by the debt and person timelines.
  Stream<List<ActivityEntryRow>> watchForEntity(RelatedEntityType type, String id) {
    return (select(activityEntries)
          ..where((t) => t.entityType.equalsValue(type) & t.entityId.equals(id))
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  Stream<List<ActivityEntryRow>> watchForEntities(
    RelatedEntityType type,
    List<String> ids,
  ) {
    if (ids.isEmpty) return Stream<List<ActivityEntryRow>>.value(const []);
    return (select(activityEntries)
          ..where((t) => t.entityType.equalsValue(type) & t.entityId.isIn(ids))
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  Stream<List<ActivityEntryRow>> watchAll() {
    return (select(activityEntries)
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }

  Future<void> insert(ActivityEntryRow row) => into(activityEntries).insert(row);

  Future<void> insertAll(List<ActivityEntryRow> rows) async {
    if (rows.isEmpty) return;
    await batch((Batch b) => b.insertAll(activityEntries, rows));
  }

  Future<void> deleteById(String id) =>
      (delete(activityEntries)..where((t) => t.id.equals(id))).go();

  /// Removes entries pointing at records that no longer exist. Used after a
  /// hard delete so the feed never links to a dead id.
  Future<void> deleteForEntity(RelatedEntityType type, String id) {
    return (delete(activityEntries)
          ..where((t) => t.entityType.equalsValue(type) & t.entityId.equals(id)))
        .go();
  }

  Future<void> deleteAll() => delete(activityEntries).go();

  // --- Monthly summaries ---------------------------------------------------

  Stream<MonthlySummaryRow?> watchSummary(int year, int month, String currencyCode) {
    return (select(monthlySummaries)
          ..where(
            (t) => t.year.equals(year) &
                t.month.equals(month) &
                t.currencyCode.equals(currencyCode),
          ))
        .watchSingleOrNull();
  }

  Future<MonthlySummaryRow?> getSummary(int year, int month, String currencyCode) {
    return (select(monthlySummaries)
          ..where(
            (t) => t.year.equals(year) &
                t.month.equals(month) &
                t.currencyCode.equals(currencyCode),
          ))
        .getSingleOrNull();
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than skipped.
    Future<void> upsertSummary(MonthlySummaryRow row) async {
    await transaction(() async {
      final int changed = await (update(monthlySummaries)
            ..where((t) => t.id.equals(row.id)))
          .write(row.toCompanion(false));
      if (changed == 0) await into(monthlySummaries).insert(row);
    });
  }

  Future<int> deleteSummary(String id) =>
      (delete(monthlySummaries)..where((t) => t.id.equals(id))).go();

  Future<int> deleteSummaryForMonth(int year, int month) {
    return (delete(monthlySummaries)
          ..where((t) => t.year.equals(year) & t.month.equals(month)))
        .go();
  }

  Future<int> deleteAllSummaries() => delete(monthlySummaries).go();

  /// Every activity entry of one type, oldest first. Used when rebuilding a
  /// month's report.
  Future<List<ActivityEntryRow>> byTypeInRange(
    ActivityType type,
    DateTime from,
    DateTime to,
  ) {
    final int start = from.millisecondsSinceEpoch;
    final int end = to.millisecondsSinceEpoch;
    return (select(activityEntries)
          ..where((t) => t.type.equalsValue(type))
          ..where((t) => t.occurredAt.isBetweenValues(start, end)))
        .get();
  }

  /// Every entry inside a date range, newest first.
  Stream<List<ActivityEntryRow>> watchRange(DateTime from, DateTime to) {
    final int start = from.millisecondsSinceEpoch;
    final int end = to.millisecondsSinceEpoch;
    return (select(activityEntries)
          ..where((t) => t.occurredAt.isBetweenValues(start, end))
          ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
            (t) => OrderingTerm.desc(t.occurredAt),
          ]))
        .watch();
  }
}
