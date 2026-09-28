import 'package:drift/drift.dart';

import '../../../core/utils/dates.dart';
import '../app_database.dart';

part 'debts_dao.g.dart';

/// One debt's payments, summed.
class DebtPaymentTotals {
  const DebtPaymentTotals({
    required this.debtId,
    required this.paidMinor,
    required this.count,
    this.lastPaidAt,
  });

  final String debtId;
  final int paidMinor;
  final int count;
  final DateTime? lastPaidAt;
}

/// Queries for debts and their payments.
@DriftAccessor(tables: <Type>[Debts, DebtPeople, Payments])
class DebtsDao extends DatabaseAccessor<AppDatabase> with _$DebtsDaoMixin {
  DebtsDao(super.db);

  /// Every debt, archived ones last.
  Stream<List<DebtRow>> watchAll() {
    return (select(debts)
          ..orderBy(<OrderingTerm Function($DebtsTable)>[
            (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<DebtRow>> getAll() => select(debts).get();

  /// The records a reminder could be planned from, soonest first.
  ///
  /// Deliberately narrow, because this is the query every save runs: only
  /// unarchived records, only those with a due date inside the window, and only
  /// those that ask for a reminder at all (`reminder_leads` is empty for a
  /// record with none, and such a record can never produce a notification). The
  /// ordering plus [limit] is what lets the caller walk the window from the
  /// soonest due date outwards and stop as soon as it has planned enough, rather
  /// than loading a whole ledger to build a few hundred notifications.
  ///
  /// Index-backed by `idx_debts_due`.
  Future<List<DebtRow>> reminderCandidates({
    required DateTime from,
    required DateTime to,
    required int limit,
    int offset = 0,
  }) {
    return (select(debts)
          ..where(
            (Debts t) =>
                t.archivedAt.isNull() &
                t.dueAt.isNotNull() &
                // A converted column compares in its stored form, which is
                // `yyyy-MM-dd`, so the range is inclusive and lexicographic.
                t.dueAt.isBetweenValues(toIsoDate(from), toIsoDate(to)) &
                t.reminderLeads.isNotValue(''),
          )
          ..orderBy(<OrderingTerm Function($DebtsTable)>[
            (t) => OrderingTerm.asc(t.dueAt),
            // A stable tie-break, so paging cannot return the same row twice.
            (t) => OrderingTerm.asc(t.id),
          ])
          ..limit(limit, offset: offset))
        .get();
  }

  /// Every participant link, as rows.
  ///
  /// A backup needs the link table itself — the order the user chose and when
  /// each link was made — not just the ids, so a round trip cannot reorder
  /// anyone or invent a link that was never there.
  Future<List<DebtPersonRow>> allParticipantRows() =>
      (select(debtPeople)
            ..orderBy(<OrderingTerm Function($DebtPeopleTable)>[
              (t) => OrderingTerm.asc(t.debtId),
              (t) => OrderingTerm.asc(t.position),
            ]))
          .get();

  /// Payment totals for one page of records.
  ///
  /// The plan needs to know which records are already settled, and asking for
  /// the totals of the few hundred rows in hand costs a fraction of summing the
  /// whole payments table on every save.
  Future<List<DebtPaymentTotals>> paymentTotalsFor(
    Iterable<String> debtIds,
  ) async {
    final List<String> ids = debtIds.toList(growable: false);
    if (ids.isEmpty) return const <DebtPaymentTotals>[];
    final $PaymentsTable p = payments;
    final Expression<int> paid = p.amountMinor.sum();
    final Expression<int> count = p.id.count();
    final Expression<String> last = p.paidAt.max();

    final List<TypedResult> rows = await (selectOnly(p)
          ..addColumns(<Expression<Object>>[p.debtId, paid, count, last])
          ..where(p.debtId.isIn(ids))
          ..groupBy(<Expression<Object>>[p.debtId]))
        .get();

    return rows
        .map((TypedResult r) => DebtPaymentTotals(
              debtId: r.read(p.debtId)!,
              paidMinor: r.read(paid) ?? 0,
              count: r.read(count) ?? 0,
              lastPaidAt: tryParseIsoDate(r.read(last)),
            ))
        .toList(growable: false);
  }

  Stream<DebtRow?> watchById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<DebtRow?> getById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
  ///
  /// [personIds] is the record's participant list. The row is written and the
  /// links replaced in the *same* transaction, so a debt can never be readable
  /// with one half of the change applied.
  Future<void> upsert(DebtRow row, {List<String>? personIds}) async {
    // A caller that passes no list means the row's own `person_id` is the one
    // person it is with, which is how a row written by hand — a migrated record,
    // a test fixture — is stored with a link like any other. The alternative,
    // writing the column and leaving the list empty, is the one state the rest of
    // the code must never see: a record that names somebody it is not linked to.
    final List<String> people = personIds ??
        (row.personId == null ? const <String>[] : <String>[row.personId!]);
    await transaction(() async {
      final DebtsCompanion companion = row.toCompanion(false).copyWith(
        // Kept equal to the first link, so the two can never disagree.
        personId: Value<String?>(people.isEmpty ? null : people.first),
      );
      final int changed = await (update(debts)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(companion);
      if (changed == 0) await into(debts).insert(companion);
      await _writeParticipants(row.id, people);
    });
  }

  /// Replaces a debt's participant list.
  ///
  /// Used on its own when only the people changed, which is a real path: the
  /// edit form can add or drop a participant without touching any other field.
  Future<void> setParticipants(String debtId, List<String> personIds) {
    return transaction(() => _writeParticipants(debtId, personIds));
  }

  /// One person no longer linked, everyone else untouched.
  Future<void> removeParticipant(String debtId, String personId) {
    return transaction(() async {
      await (delete(debtPeople)
            ..where((t) => t.debtId.equals(debtId) & t.personId.equals(personId)))
          .go();
      await _refreshPrimaryPerson(debtId);
    });
  }

  /// Who a debt is with, in the order the user chose them.
  Future<List<String>> participantsFor(String debtId) async {
    final List<DebtPersonRow> rows = await (select(debtPeople)
          ..where((t) => t.debtId.equals(debtId))
          ..orderBy(<OrderingTerm Function($DebtPeopleTable)>[
            (t) => OrderingTerm.asc(t.position),
          ]))
        .get();
    return rows.map((DebtPersonRow row) => row.personId).toList(growable: false);
  }

  /// Every debt's participants in one query, grouped by debt.
  ///
  /// One scan for a whole ledger read rather than one query per row: the ledger
  /// re-reads on every write, and 2,500 debts would otherwise mean 2,500
  /// participant lookups on every screen.
  Future<Map<String, List<String>>> allParticipants() async {
    final List<DebtPersonRow> rows = await (select(debtPeople)
          ..orderBy(<OrderingTerm Function($DebtPeopleTable)>[
            (t) => OrderingTerm.asc(t.position),
          ]))
        .get();
    final Map<String, List<String>> out = <String, List<String>>{};
    for (final DebtPersonRow row in rows) {
      (out[row.debtId] ??= <String>[]).add(row.personId);
    }
    return out;
  }

  /// Who a set of debts is with, grouped by debt.
  ///
  /// The person page reads one person's debts, which is a handful of rows; asking
  /// for those participants is cheaper than grouping the whole link table.
  Future<Map<String, List<String>>> participantsForDebts(
    List<String> debtIds,
  ) async {
    if (debtIds.isEmpty) return <String, List<String>>{};
    final List<DebtPersonRow> rows = await (select(debtPeople)
          ..where((t) => t.debtId.isIn(debtIds))
          ..orderBy(<OrderingTerm Function($DebtPeopleTable)>[
            (t) => OrderingTerm.asc(t.position),
          ]))
        .get();
    final Map<String, List<String>> out = <String, List<String>>{};
    for (final DebtPersonRow row in rows) {
      (out[row.debtId] ??= <String>[]).add(row.personId);
    }
    return out;
  }

  /// Replaces the links, updating the row's one-value column to match.
  ///
  /// Delete-then-insert rather than a diff: a debt has a handful of participants
  /// at most, and rewriting them cannot leave a stale link behind the way a
  /// partial diff can.
  Future<void> _writeParticipants(String debtId, List<String> personIds) async {
    await (delete(debtPeople)..where((t) => t.debtId.equals(debtId))).go();
    final DateTime now = DateTime.now();
    for (int index = 0; index < personIds.length; index++) {
      await into(debtPeople).insert(
        DebtPeopleCompanion.insert(
          debtId: debtId,
          personId: personIds[index],
          position: Value<int>(index),
          createdAt: now,
        ),
      );
    }
    await (update(debts)..where((t) => t.id.equals(debtId))).write(
      DebtsCompanion(
        personId: Value<String?>(personIds.isEmpty ? null : personIds.first),
      ),
    );
  }

  /// Re-points a debt at its first remaining participant.
  Future<void> _refreshPrimaryPerson(String debtId) async {
    final List<String> remaining = await participantsFor(debtId);
    await (update(debts)..where((t) => t.id.equals(debtId))).write(
      DebtsCompanion(
        personId: Value<String?>(remaining.isEmpty ? null : remaining.first),
      ),
    );
  }

  /// Moves a debt in or out of the archive without touching its other fields.
  Future<void> setArchivedAt(String id, DateTime? archivedAt, DateTime updatedAt) {
    return (update(debts)..where((t) => t.id.equals(id))).write(
      DebtsCompanion(
        archivedAt: Value<DateTime?>(archivedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  /// Stamps or clears the moment the balance reached zero.
  Future<void> setClosedAt(String id, DateTime? closedAt, DateTime updatedAt) {
    return (update(debts)..where((t) => t.id.equals(id))).write(
      DebtsCompanion(
        closedAt: Value<DateTime?>(closedAt),
        updatedAt: Value<DateTime>(updatedAt),
      ),
    );
  }

  Future<int> deleteById(String id) =>
      (delete(debts)..where((t) => t.id.equals(id))).go();

  /// Re-links every debt of [fromPersonId] to [toPersonId]. Used when merging
  /// two people the user recorded twice.
  ///
  /// The links move first and a link that already exists is dropped rather than
  /// duplicated, because `(debt_id, person_id)` is the key. A debt that [to]
  /// already shares keeps its place in the group.
  Future<void> reassignPerson(String fromPersonId, String? toPersonId) async {
    await transaction(() async {
      if (toPersonId == null) {
        await (delete(debtPeople)
              ..where((t) => t.personId.equals(fromPersonId)))
            .go();
        await (update(debts)..where((t) => t.personId.equals(fromPersonId)))
            .write(const DebtsCompanion(personId: Value<String?>(null)));
        return;
      }
      // The person being merged in is already on some of these records.
      await customStatement(
        'DELETE FROM debt_people WHERE person_id = ? AND debt_id IN '
        '(SELECT debt_id FROM debt_people WHERE person_id = ?)',
        <Object?>[toPersonId, fromPersonId],
      );
      await (update(debtPeople)
            ..where((t) => t.personId.equals(fromPersonId)))
          .write(DebtPeopleCompanion(personId: Value<String>(toPersonId)));
      await (update(debts)..where((t) => t.personId.equals(fromPersonId)))
          .write(DebtsCompanion(personId: Value<String?>(toPersonId)));
    });
  }

  // --- Payments ------------------------------------------------------------

  Stream<List<PaymentRow>> watchAllPayments() {
    return (select(payments)
          ..orderBy(<OrderingTerm Function($PaymentsTable)>[
            (t) => OrderingTerm.desc(t.paidAt),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<PaymentRow>> getAllPayments() => select(payments).get();

  /// Debts one person is part of, filtered by the database rather than after
  /// loading the table.
  Future<List<DebtRow>> getForPerson(String personId) {
    final BaseSelectStatement<dynamic> ids = selectOnly(debtPeople)
      ..addColumns(<Expression<Object>>[debtPeople.debtId])
      ..where(debtPeople.personId.equals(personId));
    return (select(debts)..where((t) => t.id.isInQuery(ids))).get();
  }

  /// Paid total, payment count and last payment date for every debt, summed by
  /// SQLite.
  ///
  /// The alternative — reading every payment and reducing in Dart — cost 499 ms
  /// at 10,000 payments where this costs 20 ms, and the ledger read runs on
  /// every screen and every write.
  ///
  /// The expressions are built by drift's query builder, so the debt id is bound
  /// as a parameter and never interpolated into SQL text.
  Future<List<DebtPaymentTotals>> paymentTotalsByDebt() async {
    final $PaymentsTable p = payments;
    final Expression<int> paid = p.amountMinor.sum();
    final Expression<int> count = p.id.count();
    // `paid_at` is stored as `yyyy-MM-dd` text, so its maximum is a string; the
    // converter turns it back into a date when the entity is built.
    final Expression<String> last = p.paidAt.max();

    final List<TypedResult> rows = await (selectOnly(p)
          ..addColumns(<Expression<Object>>[p.debtId, paid, count, last])
          ..where(p.debtId.isNotNull())
          ..groupBy(<Expression<Object>>[p.debtId]))
        .get();

    return rows
        .map((TypedResult r) => DebtPaymentTotals(
              debtId: r.read(p.debtId)!,
              paidMinor: r.read(paid) ?? 0,
              count: r.read(count) ?? 0,
              lastPaidAt: tryParseIsoDate(r.read(last)),
            ))
        .toList(growable: false);
  }

  Stream<List<PaymentRow>> watchPaymentsForDebt(String debtId) {
    return (select(payments)
          ..where((t) => t.debtId.equals(debtId))
          ..orderBy(<OrderingTerm Function($PaymentsTable)>[
            (t) => OrderingTerm.desc(t.paidAt),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
        .watch();
  }

  Future<List<PaymentRow>> getPaymentsForDebt(String debtId) {
    return (select(payments)..where((t) => t.debtId.equals(debtId))).get();
  }

  Stream<List<PaymentRow>> watchPaymentsForPerson(String personId) {
    return (select(payments)
          ..where((t) => t.personId.equals(personId))
          ..orderBy(<OrderingTerm Function($PaymentsTable)>[
            (t) => OrderingTerm.desc(t.paidAt),
          ]))
        .watch();
  }

  Future<PaymentRow?> getPaymentById(String id) =>
      (select(payments)..where((t) => t.id.equals(id))).getSingleOrNull();

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Without both, clearing a payment note or a period's paid stamp
  /// appears to work and then quietly reverts.
    Future<void> upsertPayment(PaymentRow row) async {
    await transaction(() async {
      final int changed = await (update(payments)
            ..where((t) => t.id.equals(row.id)))
          .write(row.toCompanion(false));
      if (changed == 0) await into(payments).insert(row);
    });
  }

  Future<int> deletePayment(String id) =>
      (delete(payments)..where((t) => t.id.equals(id))).go();

  Future<void> deletePaymentsForDebt(String debtId) =>
      (delete(payments)..where((t) => t.debtId.equals(debtId))).go();
}
