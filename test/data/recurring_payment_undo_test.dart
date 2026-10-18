import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// Undoing a payment that settled a recurring debt.
///
/// A recurring record is a series: settling one period creates the next one, so
/// the ledger holds a closed period and the open period that follows it. That
/// follow-up is a *consequence* of the closing — and an undo that reopens the
/// debt without taking the consequence away leaves the person owing the money
/// twice, once on the reopened period and once on a period that was only ever
/// created because the first one was paid.
///
/// Nothing here asserts on the shape of the rows: the judgement is the same one
/// every screen makes — what the person still owes.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late DateTime now;

  setUp(() async {
    db = AppDatabase.memory();
    now = DateTime(2026, 9, 15, 10);
    service = buildService(db, clock: () => now);
  });
  tearDown(() async => db.close());

  const int rent = 500000;

  Future<Person> tenant() =>
      service.createPerson(const PersonDraft(name: 'أحمد'));

  /// One monthly record, due on the 15th.
  Future<Debt> monthly(Person person, {DateTime? dueAt}) => service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'إيجار',
          principalMinor: rent,
          currency: AppCurrency.inr,
          issuedAt: dueAt ?? dateOnly(now),
          dueAt: dueAt ?? dateOnly(now),
          recurrence: RecurrenceFrequency.monthly,
        ),
      );

  /// What the person still owes, in total, on the side the money is owed to.
  ///
  /// Summed the way the person's page sums it, from the records and their
  /// payments — never from anything the write under test returns.
  Future<int> owed(Person person) async {
    int total = 0;
    for (final Debt debt in await service.debts.forPerson(person.id)) {
      final List<Payment> payments = await service.payments.forDebt(debt.id);
      total += DebtCalculator.remainingOf(
        debt.principalMinor,
        DebtCalculator.totalPaid(payments),
      );
    }
    return total;
  }

  /// The records of a recurring series, closed first.
  Future<List<Debt>> records(Person person) async {
    final List<Debt> debts = await service.debts.forPerson(person.id);
    debts.sort((Debt a, Debt b) => a.issuedAt.compareTo(b.issuedAt));
    return debts;
  }

  test('settling a period creates the next one, and that is one debt, not two',
      () async {
    final Person ahmed = await tenant();
    await monthly(ahmed);

    final List<Payment> written = await service.recordPersonPayment(
      PersonPaymentDraft(
        personId: ahmed.id,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: rent,
        paidAt: dateOnly(now),
      ),
    );

    expect(written, hasLength(1));
    final List<Debt> series = await records(ahmed);
    expect(series, hasLength(2), reason: 'the settled period and the next one');
    expect(series.first.closedAt, isNotNull);
    expect(series.last.closedAt, isNull);
    expect(
      await owed(ahmed),
      rent,
      reason: 'the next period is what is owed now — not the paid one as well',
    );
  });

  test('undoing the payment takes the next period back with it', () async {
    final Person ahmed = await tenant();
    await monthly(ahmed);

    final List<Payment> written = await service.recordPersonPayment(
      PersonPaymentDraft(
        personId: ahmed.id,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: rent,
        paidAt: dateOnly(now),
      ),
    );
    expect(await owed(ahmed), rent);

    await service.deletePaymentsBatch(<String>[written.single.id]);

    expect(
      await owed(ahmed),
      rent,
      reason: 'the ledger is back where it started, not twice as deep',
    );
    final List<Debt> series = await records(ahmed);
    expect(
      series,
      hasLength(1),
      reason: 'the period created by the closing went with it',
    );
    expect(series.single.closedAt, isNull, reason: 'and the period reopened');
  });

  test('the same holds for one payment deleted on its own', () async {
    final Person ahmed = await tenant();
    final Debt period = await monthly(ahmed);

    final Payment payment = await service.recordPayment(
      period.id,
      PaymentDraft(amountMinor: rent, paidAt: dateOnly(now)),
    );
    expect(await owed(ahmed), rent);

    await service.deletePayment(payment.id);

    expect(await owed(ahmed), rent);
    expect(
      await records(ahmed),
      hasLength(1),
      reason: 'deleting one payment is the same undo, so it behaves the same',
    );
  });

  test('redoing the payment brings the next period back', () async {
    final Person ahmed = await tenant();
    await monthly(ahmed);

    final List<Payment> written = await service.recordPersonPayment(
      PersonPaymentDraft(
        personId: ahmed.id,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: rent,
        paidAt: dateOnly(now),
      ),
    );
    await service.deletePaymentsBatch(<String>[written.single.id]);
    expect(await records(ahmed), hasLength(1));

    await service.restorePaymentRecord(written.single);

    final List<Debt> series = await records(ahmed);
    expect(series, hasLength(2), reason: 'undo then redo is where it was');
    expect(series.first.closedAt, isNotNull);
    expect(series.last.closedAt, isNull);
    expect(await owed(ahmed), rent);
  });

  test('a next period that has money on it is never taken away', () async {
    // Rent for one month is paid off, which records the following month. That
    // following month then receives money of its own. Undoing the *first*
    // payment must not delete a record someone has already paid into — the
    // money would have nowhere to live. It stays, and the two periods are what
    // the ledger honestly holds.
    final Person ahmed = await tenant();
    final Debt period = await monthly(ahmed);

    final Payment first = await service.recordPayment(
      period.id,
      PaymentDraft(amountMinor: rent, paidAt: dateOnly(now)),
    );
    final List<Debt> afterSettle = await records(ahmed);
    final Debt next = afterSettle.last;
    expect(next.closedAt, isNull);

    await service.recordPayment(
      next.id,
      PaymentDraft(amountMinor: 10000, paidAt: dateOnly(now)),
    );

    await service.deletePayment(first.id);

    final List<Debt> series = await records(ahmed);
    expect(series, hasLength(2), reason: 'the paid-into period survives');
    expect(
      series.first.closedAt,
      isNull,
      reason: 'and the period whose payment was undone is open again',
    );
    expect(
      await owed(ahmed),
      rent + (rent - 10000),
      reason: 'the money that was applied to the following period is still there',
    );
  });
}
