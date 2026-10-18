import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The places two features meet and quietly disagree.
///
/// Each feature here is correct on its own: a payment closes a debt, an edit
/// changes what a debt owes, a delete removes money, an undo puts it back, and a
/// recurring record grows a next period when it is settled. The defects live in
/// the seams — an edit that does not re-decide the closing, a correction that
/// does not take back the period it created, an undo that runs after the record
/// it was written against has been deleted.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late DateTime now;

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 9, 15, 10);
    service = buildService(db, clock: () => now);
  });
  tearDown(() async => db.close());

  final DateTime today = dateOnly(DateTime(2026, 9, 15));

  Future<Person> person([String name = 'أحمد']) =>
      service.createPerson(PersonDraft(name: name));

  const int rent = 500000;

  /// One monthly record due today.
  Future<Debt> monthlyRent(Person owner) => service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[owner.id],
          title: 'إيجار',
          principalMinor: rent,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: today,
          recurrence: RecurrenceFrequency.monthly,
        ),
      );

  DebtDraft draftOf(
    Debt debt, {
    int? principalMinor,
    AppCurrency? currency,
    DebtDirection? direction,
    String? title,
  }) =>
      DebtDraft(
        direction: direction ?? debt.direction,
        personIds: debt.personIds,
        title: title ?? debt.title,
        principalMinor: principalMinor ?? debt.principalMinor,
        currency: currency ?? debt.currency,
        issuedAt: debt.issuedAt,
        dueAt: debt.dueAt,
        recurrence: debt.recurrence,
        recurrenceInterval: debt.recurrenceInterval,
      );

  Future<int> rentRecords() async => (await service.debts.getAll())
      .where((Debt debt) => debt.title == 'إيجار')
      .length;

  group('editing a record that already has money on it', () {
    test('lowering the amount to what was paid closes it, and starts the next '
        'period exactly as a final payment would', () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 200000, paidAt: today),
      );
      expect(await rentRecords(), 1);

      await service.updateDebt(debt.id, draftOf(debt, principalMinor: 200000));

      final Debt after = (await service.debts.getById(debt.id))!;
      expect(after.closedAt, isNotNull, reason: 'nothing is left on it');
      expect(await rentRecords(), 2, reason: 'and next month exists');
      expect(
        (await service.debts.getAll())
            .where((Debt d) => d.id != debt.id)
            .single
            .closedAt,
        isNull,
      );
    });

    test('lowering it below what was paid also closes it', () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 300000, paidAt: today),
      );

      await service.updateDebt(debt.id, draftOf(debt, principalMinor: 100000));

      expect((await service.debts.getById(debt.id))!.closedAt, isNotNull);
      expect(await rentRecords(), 2);
    });

    test('raising it past what was paid reopens it and takes the next period '
        'back', () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 200000, paidAt: today),
      );
      await service.updateDebt(debt.id, draftOf(debt, principalMinor: 200000));
      expect(await rentRecords(), 2);

      final Debt closed = (await service.debts.getById(debt.id))!;
      await service.updateDebt(closed.id, draftOf(closed, principalMinor: 400000));

      final Debt reopened = (await service.debts.getById(debt.id))!;
      expect(reopened.closedAt, isNull);
      expect(
        DebtCalculator.remainingOf(reopened.principalMinor, 200000),
        200000,
      );
      expect(
        await rentRecords(),
        1,
        reason: 'the period that only existed because it was settled',
      );
    });

    test('editing an already-settled record does not add a second next period',
        () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: rent, paidAt: today),
      );
      expect(await rentRecords(), 2);

      final Debt settled = (await service.debts.getById(debt.id))!;
      await service.updateDebt(settled.id, draftOf(settled, title: 'إيجار البيت'));

      expect(
        (await service.debts.getAll())
            .where((Debt d) => d.title == 'إيجار')
            .length,
        1,
        reason: 'the follow-up kept its own title, and no second one appeared',
      );
      expect((await service.debts.getById(debt.id))!.closedAt, isNotNull);
    });

    test('retagging the currency takes the record\'s payments with it', () async {
      final Person ahmed = await person();
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'سلفة',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 40000, paidAt: today),
      );

      await service.updateDebt(debt.id, draftOf(debt, currency: AppCurrency.usd));

      final List<Payment> history = await service.payments.forDebt(debt.id);
      expect(history.single.currency, AppCurrency.usd);
      // The balance is the same money, now read in the currency the user chose:
      // a rupee payment left behind would have been added to a dollar principal.
      final DebtView view = DebtCalculator.buildView(
        debt: (await service.debts.getById(debt.id))!,
        payments: history,
        asOf: today,
        dueSoonWindowDays: 7,
      );
      expect(view.currency, AppCurrency.usd);
      expect(view.paidMinor, 40000);
      expect(view.remainingMinor, 60000);
      expect(
        (await service.payments.getAll()).first.currency,
        AppCurrency.usd,
        reason: 'nothing is left in the old currency',
      );
    });

    test('changing the side moves the balance to the other bucket', () async {
      final Person ahmed = await person();
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'سلفة',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 40000, paidAt: today),
      );

      await service.updateDebt(
        debt.id,
        draftOf(debt, direction: DebtDirection.owedToMe),
      );

      final Debt moved = (await service.debts.getById(debt.id))!;
      expect(moved.direction, DebtDirection.owedToMe);
      // A record is one fact with one side; correcting the side must not leave
      // its history pointing the other way. Payments have no direction of their
      // own, so nothing else has to move for this to hold.
      expect(await service.payments.forDebt(debt.id), hasLength(1));
      final List<DebtView> views = <DebtView>[
        DebtCalculator.buildView(
          debt: moved,
          payments: await service.payments.forDebt(debt.id),
          asOf: today,
          dueSoonWindowDays: 7,
        ),
      ];
      final List<CurrencyTotals> totals = DebtCalculator.totalsByCurrency(
        views,
        asOf: today,
        dueSoonWindowDays: 7,
      );
      expect(totals.single.iOweMinor, 0);
      expect(totals.single.owedToMeMinor, 60000);
    });
  });

  group('correcting a payment that settled a recurring record', () {
    test('correcting it down reopens the period and takes the next one back',
        () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: rent, paidAt: today),
      );
      expect(await rentRecords(), 2);
      expect((await service.debts.getById(debt.id))!.closedAt, isNotNull);

      await service.updatePayment(
        payment.id,
        PaymentDraft(amountMinor: rent - 10000, paidAt: today),
      );

      expect((await service.debts.getById(debt.id))!.closedAt, isNull);
      expect(DebtCalculator.remainingOf(rent, rent - 10000), 10000);
      expect(await rentRecords(), 1, reason: 'no next month any more');
    });

    test('correcting it back up settles the record again and rebuilds the '
        'period', () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: rent, paidAt: today),
      );
      await service.updatePayment(
        payment.id,
        PaymentDraft(amountMinor: rent - 10000, paidAt: today),
      );
      expect(await rentRecords(), 1);

      await service.updatePayment(
        payment.id,
        PaymentDraft(amountMinor: rent, paidAt: today),
      );

      expect((await service.debts.getById(debt.id))!.closedAt, isNotNull);
      expect(await rentRecords(), 2);
    });

    test('a correction upwards can be the payment that settles it', () async {
      final Person ahmed = await person();
      final Debt debt = await monthlyRent(ahmed);
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 200000, paidAt: today),
      );
      expect(await rentRecords(), 1);

      await service.updatePayment(
        payment.id,
        PaymentDraft(amountMinor: rent, paidAt: today),
      );

      expect((await service.debts.getById(debt.id))!.closedAt, isNotNull);
      expect(await rentRecords(), 2);
    });
  });

  group('an undo that runs after the record was deleted', () {
    test('the batch undo survives losing one of its records', () async {
      final Person ahmed = await person();
      final Debt first = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'أول',
          principalMinor: 200000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final Debt second = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'ثانٍ',
          principalMinor: 200000,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, 1),
        ),
      );
      final List<Payment> written = await service.recordPersonPayment(
        PersonPaymentDraft(
          personId: ahmed.id,
          direction: DebtDirection.owedToMe,
          currency: AppCurrency.inr,
          amountMinor: 250000,
          paidAt: today,
        ),
      );
      expect(written, hasLength(2), reason: '200,000 then 50,000');

      // The user deletes one of the two records while the undo is still on
      // screen — the undo must not fail over a record that is already gone.
      await service.deleteDebt(first.id);

      final int leftInPlace = await service.deletePaymentsBatch(
        written.map((Payment p) => p.id).toList(),
      );

      expect(leftInPlace, 0);
      expect(await service.payments.getAll(), isEmpty);
      expect(
        (await service.debts.getById(second.id))!.closedAt,
        isNull,
        reason: 'the record that is still there reopens',
      );
      expect(
        await db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    });

    test('undoing a payment to a record that was later deleted does not throw',
        () async {
      final Person ahmed = await person();
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 40000, paidAt: today),
      );
      await service.deletePayment(payment.id);
      await service.deleteDebt(debt.id);

      // What the SnackBar's undo button runs. There is nothing left to attach
      // the money to, and the user's later decision to delete the record wins;
      // what must not happen is a foreign-key error thrown out of a callback.
      await expectLater(service.restorePaymentRecord(payment), completes);
      expect(await service.payments.getAll(), isEmpty);
      expect(
        await db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      expect(await service.debts.getAll(), isEmpty);
    });

    test('undoing a payment whose person was deleted keeps the money and drops '
        'the person', () async {
      final Person ahmed = await person();
      final Person salem = await person('سالم');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[salem.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final List<Payment> payment = await service.recordPersonPayment(
        PersonPaymentDraft(
          personId: salem.id,
          direction: DebtDirection.iOwe,
          currency: AppCurrency.inr,
          amountMinor: 40000,
          paidAt: today,
        ),
      );
      expect(payment, hasLength(1));

      await service.deletePayment(payment.single.id);
      await service.deletePerson(salem.id);

      await expectLater(
        service.restorePaymentRecord(payment.single),
        completes,
      );
      final Payment restored = (await service.payments.getAll()).single;
      expect(
        restored.personId,
        isNull,
        reason: 'the payment stays; the person it was recorded by is gone',
      );
      expect(restored.amountMinor, 40000);
      expect(await service.debts.getAll(), hasLength(1));
      expect(ahmed.name, 'أحمد');
    });
  });
}
