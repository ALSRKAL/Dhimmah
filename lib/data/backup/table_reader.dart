import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// Reads whole tables in pages, so the frame thread gets a turn between them.
///
/// The problem this exists for is measured, not imagined: on the phone a backup
/// of 500 people / 2,500 records / 10,000 payments took 723 ms and drew **two**
/// frames — one stall from beginning to end. Reading a table in one `SELECT` means
/// the drift row mapping (≈68% of a read) runs as a single synchronous stretch on
/// the thread that draws the screen. Paging it turns that one stall into a
/// sequence of short ones, which is the difference between a frozen spinner and a
/// moving one.
///
/// Two things make it safe to use in the backup path:
///
/// * **Keyset paging, not offsets.** Each page asks for rows whose key is greater
///   than the last key seen, so no row can be skipped or repeated even if SQLite's
///   scan order changes between statements. Offset paging would rely on an
///   ordering the SQL does not guarantee.
/// * **A count guard.** When the pages are collected, the total is compared with
///   the database's own `COUNT(*)` for that table. If they disagree — a schema
///   change, a key that is not unique, anything — the reader falls back to one
///   full read and the result is still complete. An optimisation in this path must
///   not be able to lose a row silently, so it checks its own completeness against
///   the source of truth on every run.
class TableReader {
  TableReader({
    required AppDatabase database,
    this.pageSize = 500,
    this.onProgress,
  }) : _db = database;

  final AppDatabase _db;

  /// Rows per page. Small enough that one page's mapping is a frame-sized piece
  /// of work, large enough that the per-statement cost stays irrelevant.
  final int pageSize;

  /// How many rows have been read so far, across every table read so far.
  ///
  /// This is a count of work actually done, which is why it can be shown to the
  /// user as it stands — "2,500 of 10,000 records" is a fact, not an animation.
  final void Function(int rowsRead)? onProgress;

  int _read = 0;

  /// Every person, in key order.
  Future<List<PersonRow>> people() => _collect<PersonRow>(
        page: (String? after) => (_db.select(_db.people)
              ..where((People t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($PeopleTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (PersonRow row) => row.id,
        count: () => _count(_db.people),
        fullRead: _db.peopleDao.getAll,
      );

  /// Every record, in key order.
  Future<List<DebtRow>> debts() => _collect<DebtRow>(
        page: (String? after) => (_db.select(_db.debts)
              ..where((Debts t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($DebtsTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (DebtRow row) => row.id,
        count: () => _count(_db.debts),
        fullRead: _db.debtsDao.getAll,
      );

  /// Every participant link.
  ///
  /// The link table has no single key — it is keyed by the pair it joins — so the
  /// cursor is the pair, and the comparison is the one the database can do with
  /// its own index: a later record, or the same record at a later position.
  Future<List<DebtPersonRow>> links() async {
    final List<DebtPersonRow> out = <DebtPersonRow>[];
    String? debtId;
    int position = -1;
    while (true) {
      final List<DebtPersonRow> rows = await (_db.select(_db.debtPeople)
            ..where((DebtPeople t) => debtId == null
                ? const Constant(true)
                : t.debtId.isBiggerThanValue(debtId) |
                    (t.debtId.equals(debtId) & t.position.isBiggerThanValue(position)))
            ..orderBy(<OrderingTerm Function($DebtPeopleTable)>[
              (t) => OrderingTerm.asc(t.debtId),
              (t) => OrderingTerm.asc(t.position),
            ])
            ..limit(pageSize))
          .get();
      if (rows.isEmpty) break;
      out.addAll(rows);
      _report(out.length);
      if (rows.length < pageSize) break;
      debtId = rows.last.debtId;
      position = rows.last.position;
      await _breathe();
    }
    final int expected = await _count(_db.debtPeople);
    if (out.length != expected) {
      return _db.debtsDao.allParticipantRows();
    }
    return out;
  }

  /// Every payment, in key order.
  Future<List<PaymentRow>> payments() => _collect<PaymentRow>(
        page: (String? after) => (_db.select(_db.payments)
              ..where((Payments t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($PaymentsTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (PaymentRow row) => row.id,
        count: () => _count(_db.payments),
        fullRead: _db.debtsDao.getAllPayments,
      );

  /// Every commitment, in key order.
  Future<List<ObligationRow>> obligations() => _collect<ObligationRow>(
        page: (String? after) => (_db.select(_db.obligations)
              ..where((Obligations t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($ObligationsTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (ObligationRow row) => row.id,
        count: () => _count(_db.obligations),
        fullRead: _db.obligationsDao.getAll,
      );

  /// Every period, in key order.
  Future<List<ObligationOccurrenceRow>> occurrences() =>
      _collect<ObligationOccurrenceRow>(
        page: (String? after) => (_db.select(_db.obligationOccurrences)
              ..where((ObligationOccurrences t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($ObligationOccurrencesTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (ObligationOccurrenceRow row) => row.id,
        count: () => _count(_db.obligationOccurrences),
        fullRead: _db.obligationsDao.getOccurrences,
      );

  /// Every reminder, in key order.
  Future<List<ReminderRow>> reminders() => _collect<ReminderRow>(
        page: (String? after) => (_db.select(_db.reminders)
              ..where((Reminders t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($RemindersTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (ReminderRow row) => row.id,
        count: () => _count(_db.reminders),
        fullRead: _db.remindersDao.getAll,
      );

  /// Every monthly summary, in key order.
  Future<List<MonthlySummaryRow>> summaries() => _collect<MonthlySummaryRow>(
        page: (String? after) => (_db.select(_db.monthlySummaries)
              ..where((MonthlySummaries t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($MonthlySummariesTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (MonthlySummaryRow row) => row.id,
        count: () => _count(_db.monthlySummaries),
        fullRead: _db.activityDao.getAllSummaries,
      );

  /// The activity log, newest first, capped by [limit].
  ///
  /// The only table whose read is not "all of it": the log grows without limit
  /// and the backup carries the newest [limit] entries.
  Future<List<ActivityEntryRow>> activity({required int limit}) =>
      _collect<ActivityEntryRow>(
        page: (String? after) => (_db.select(_db.activityEntries)
              ..where((ActivityEntries t) =>
                  after == null ? const Constant(true) : t.id.isBiggerThanValue(after))
              ..orderBy(<OrderingTerm Function($ActivityEntriesTable)>[
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(pageSize))
            .get(),
        key: (ActivityEntryRow row) => row.id,
        count: () => _count(_db.activityEntries),
        fullRead: () => _db.activityDao.getAll(limit: limit),
        take: limit,
      );

  // --- Internals ------------------------------------------------------------

  /// Pages [page] until it is exhausted, checking the total against [count].
  Future<List<T>> _collect<T>({
    required Future<List<T>> Function(String? after) page,
    required String Function(T row) key,
    required Future<int> Function() count,
    required Future<List<T>> Function() fullRead,
    int? take,
  }) async {
    final List<T> out = <T>[];
    String? after;
    while (true) {
      final List<T> rows = await page(after);
      if (rows.isEmpty) break;
      out.addAll(rows);
      _report(out.length);
      if (rows.length < pageSize) break;
      if (take != null && out.length >= take) break;
      after = key(rows.last);
      await _breathe();
    }

    // The guard: the pages must add up to what the table says it holds. If they
    // do not, the fast path is abandoned rather than trusted.
    final int expected = await count();
    final int wanted = take == null ? expected : (expected < take ? expected : take);
    if (out.length != wanted) {
      // One full read, in whatever order the database prefers. Slower, and
      // correct — which is the only acceptable trade in this path.
      return fullRead();
    }
    return out;
  }

  void _report(int rows) {
    _read = rows;
    onProgress?.call(_read);
  }

  Future<int> _count(TableInfo<Table, dynamic> table) async {
    final Expression<int> count = table.$columns.first.count();
    final TypedResult row =
        await (_db.selectOnly(table)..addColumns(<Expression<Object>>[count]))
            .getSingle();
    return row.read(count) ?? 0;
  }

  /// Lets the event loop run, so a frame can be drawn between pages.
  Future<void> _breathe() => Future<void>.delayed(Duration.zero);
}
