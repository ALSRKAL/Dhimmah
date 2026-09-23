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
@DriftAccessor(tables: <Type>[Debts, Payments])
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

  Stream<DebtRow?> watchById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).watchSingleOrNull();

  Future<DebtRow?> getById(String id) =>
      (select(debts)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<DebtRow>> watchForPerson(String personId) {
    return (select(debts)
          ..where((t) => t.personId.equals(personId))
          ..orderBy(<OrderingTerm Function($DebtsTable)>[
            (t) => OrderingTerm.asc(t.archivedAt.isNotNull()),
            (t) => OrderingTerm.desc(t.issuedAt),
          ]))
        .watch();
  }

  /// Writes the row, updating it when it already exists.
  ///
  /// An explicit update-or-insert rather than drift's `insertOnConflictUpdate`,
  /// and written through a companion so that nulls are stored rather than
  /// skipped. Both matter: without them, clearing a due date, a note or a person
  /// link appears to work and then quietly reverts on the next read.
    Future<void> upsert(DebtRow row) async {
    await transaction(() async {
      final int changed = await (update(debts)
            ..where((t) => t.id.equals(row.id)))
          // The companion is written with every value present, so clearing a
          // nullable column actually stores NULL instead of being skipped.
          .write(row.toCompanion(false));
      if (changed == 0) await into(debts).insert(row);
    });
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
  Future<void> reassignPerson(String fromPersonId, String? toPersonId) {
    return (update(debts)..where((t) => t.personId.equals(fromPersonId)))
        .write(DebtsCompanion(personId: Value<String?>(toPersonId)));
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

  /// Debts belonging to one person, filtered by the database rather than after
  /// loading the table.
  Future<List<DebtRow>> getForPerson(String personId) {
    return (select(debts)..where((t) => t.personId.equals(personId))).get();
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
