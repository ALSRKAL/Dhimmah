import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/activity_entry.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/activity_enums.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One payment against everything a person owes.
///
/// The write is judged by what it leaves behind: balances that add up, debts
/// closed exactly when they reach zero, a feed that says what happened, and an
/// undo that puts all of it back. Nothing here asserts on the shape of the
/// rows — the whole design rests on writing ordinary payments, so these tests
/// check the ledger, not the implementation.
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

  Future<Person> person([String name = 'أحمد']) =>
      service.createPerson(PersonDraft(name: name));

  Future<Debt> debtFor(
    Person person, {
    required int amountMinor,
    required String title,
    required DebtDirection direction,
    required AppCurrency currency,
    DateTime? dueAt,
    DateTime? issuedAt,
    RecurrenceFrequency recurrence = RecurrenceFrequency.none,
    int recurrenceInterval = 1,
  }) {
    return service.createDebt(
      DebtDraft(
        direction: direction,
        personIds: <String>[person.id],
        title: title,
        principalMinor: amountMinor,
        currency: currency,
        issuedAt: issuedAt ?? dateOnly(now),
        dueAt: dueAt,
        recurrence: recurrence,
        recurrenceInterval: recurrenceInterval,
      ),
    );
  }

  PersonPaymentDraft draftFor(
    Person person, {
    required int amountMinor,
    required DebtDirection direction,
    required AppCurrency currency,
    Set<String> excluded = const <String>{},
    PaymentAllocationOrder order = PaymentAllocationOrder.mostUrgent,
    String? note,
  }) {
    return PersonPaymentDraft(
      personId: person.id,
      direction: direction,
      currency: currency,
      amountMinor: amountMinor,
      paidAt: dateOnly(now),
      note: note,
      order: order,
      excludedDebtIds: excluded,
    );
  }

  /// Every debt of this person with its outstanding balance, by title.
  ///
  /// Computed the way every screen computes it — the debt, its payments, and the
  /// calculator — rather than from anything this feature writes.
  Future<Map<String, int>> balances(Person person) async {
    final List<Debt> debts = await service.debts.forPerson(person.id);
    final Map<String, int> out = <String, int>{};
    for (final Debt debt in debts) {
      final List<Payment> payments = await service.payments.forDebt(debt.id);
      out[debt.title] =
          DebtCalculator.remainingOf(debt.principalMinor, DebtCalculator.totalPaid(payments));
    }
    return out;
  }

  /// The person's debts, so a test can name one without knowing its id.
  Future<List<Debt>> debtsOf(Person person) =>
      service.debts.forPerson(person.id);

  group('the split', () {
    test('pays the oldest due debt first and stops when the money runs out',
        () async {
      final Person ahmed = await person();
      await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 1000,
        title: 'متأخر',
        dueAt: addDays(dateOnly(now), -10),
      );
      await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 2000,
        title: 'قريب',
        dueAt: addDays(dateOnly(now), 5),
      );

      final List<Payment> written = await service.recordPersonPayment(
        draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500),
      );

      expect(written, hasLength(2));
      expect(
        <String, int>{'متأخر': 0, 'قريب': 1500},
        await balances(ahmed),
        reason: 'the late one is cleared, the rest goes to the next',
      );
    });

    test('a partial split leaves the remainder on the debt it landed on',
        () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 3000, title: 'أول', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 3000, title: 'ثاني', dueAt: addDays(dateOnly(now), 1));

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000));

      expect(<String, int>{'أول': 2000, 'ثاني': 3000}, await balances(ahmed));
    });

    test('one payment per debt, each carrying its own share', () async {
      final Person ahmed = await person();
      final Debt first =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      final Debt second = await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 1000,
        title: 'ثاني',
        dueAt: addDays(dateOnly(now), 1),
      );

      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500));

      expect(written.map((Payment p) => p.amountMinor), <int>[1000, 500]);
      expect(written.map((Payment p) => p.debtId), <String>[first.id, second.id]);
      expect(
        written.every((Payment p) => p.personId == ahmed.id),
        isTrue,
        reason: 'the person is stamped on each share',
      );
      // And each debt reads its own share through the ordinary path.
      expect(await service.payments.forDebt(first.id), hasLength(1));
      expect(await service.payments.forDebt(second.id), hasLength(1));
    });

    test('money that reaches nothing is refused rather than written', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));

      final List<Payment> written = await service.recordPersonPayment(
        draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 500, excluded: <String>{'nothing'}),
      );
      expect(written, hasLength(1));

      // Excluding the only debt leaves nothing to apply; the write is a no-op
      // and no empty payment is filed.
      final String onlyId = (await debtsOf(ahmed)).single.id;
      final List<Payment> none = await service.recordPersonPayment(
        draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 500, excluded: <String>{onlyId}),
      );
      expect(none, isEmpty);
      expect(await balances(ahmed), <String, int>{'أول': 500});
    });
  });

  group('what it leaves behind', () {
    test('a debt paid in full is closed, with its closure announced', () async {
      final Person ahmed = await person();
      final Debt only =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 2500, title: 'إيجار', dueAt: dateOnly(now));

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 2500));

      final Debt? stored = await service.debts.getById(only.id);
      expect(stored!.closedAt, isNotNull);

      final List<ActivityEntry> feed =
          await service.activity.forEntity(RelatedEntityType.debt, only.id);
      expect(
        feed.map((ActivityEntry e) => e.type),
        containsAll(<ActivityType>[
          ActivityType.paymentRecorded,
          ActivityType.debtClosed,
        ]),
      );
    });

    test('a debt left partly paid stays open', () async {
      final Person ahmed = await person();
      final Debt only = await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 5000, title: 'قرض');

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 2000));

      expect((await service.debts.getById(only.id))!.closedAt, isNull);
    });

    test('a recurring debt settled by the split gets its next period', () async {
      final Person ahmed = await person();
      final Debt original = await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 1000,
        title: 'إيجار',
        dueAt: DateTime(2026, 9),
        issuedAt: DateTime(2026, 9),
        recurrence: RecurrenceFrequency.monthly,
      );

      await service.recordPersonPayment(
        draftFor(
          ahmed,
          direction: DebtDirection.iOwe,
          currency: AppCurrency.inr,
          amountMinor: 1000,
        ),
      );

      final List<Debt> all = await debtsOf(ahmed);
      expect(all, hasLength(2), reason: 'the next period was created');
      // Named by id, not by position: `forPerson` returns the rows in whatever
      // order the database prefers, so "the one that came second" means nothing.
      final Debt followUp =
          all.firstWhere((Debt d) => d.id != original.id);
      expect(
        followUp.dueAt,
        DateTime(2026, 10),
        reason: 'and it is the next month, anchored on the original',
      );
      expect(followUp.principalMinor, original.principalMinor);
    });

    test('each debt gets its own feed entry, so its page is complete', () async {
      final Person ahmed = await person();
      final Debt first =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      final Debt second = await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 1000,
        title: 'ثاني',
        dueAt: addDays(dateOnly(now), 1),
      );

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500));

      final List<ActivityEntry> forFirst =
          await service.activity.forEntity(RelatedEntityType.debt, first.id);
      final List<ActivityEntry> forSecond =
          await service.activity.forEntity(RelatedEntityType.debt, second.id);
      expect(forFirst.where((ActivityEntry e) => e.type == ActivityType.paymentRecorded), hasLength(1));
      expect(forSecond.where((ActivityEntry e) => e.type == ActivityType.paymentRecorded), hasLength(1));
      expect(
        forFirst.firstWhere((ActivityEntry e) => e.type == ActivityType.paymentRecorded).amountMinor,
        1000,
      );
      expect(
        forSecond.firstWhere((ActivityEntry e) => e.type == ActivityType.paymentRecorded).amountMinor,
        500,
      );
    });

    test('the note travels to every share', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'ثاني', dueAt: addDays(dateOnly(now), 1));

      final List<Payment> written = await service.recordPersonPayment(
        draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500, note: 'تحويل بنكي'),
      );
      expect(written.every((Payment p) => p.note == 'تحويل بنكي'), isTrue);
    });
  });

  group('what it refuses to touch', () {
    test('a debt on the other side of the ledger is not paid', () async {
      final Person ahmed = await person();
      await debtFor(currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'لي', direction: DebtDirection.owedToMe);
      await debtFor(currency: AppCurrency.inr, ahmed, amountMinor: 2000, title: 'عليّ', direction: DebtDirection.iOwe);

      await service.recordPersonPayment(
        draftFor(currency: AppCurrency.inr, ahmed, amountMinor: 500, direction: DebtDirection.iOwe),
      );

      expect(
        <String, int>{'لي': 1000, 'عليّ': 1500},
        await balances(ahmed),
        reason: 'the two sides never settle each other',
      );
    });

    test('another currency is not paid, and not converted', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, ahmed, amountMinor: 1000, title: 'دينار', currency: AppCurrency.inr);
      await debtFor(direction: DebtDirection.iOwe, ahmed, amountMinor: 1000, title: 'دولار', currency: AppCurrency.usd);

      await service.recordPersonPayment(
        draftFor(direction: DebtDirection.iOwe, ahmed, amountMinor: 400, currency: AppCurrency.inr),
      );

      expect(<String, int>{'دينار': 600, 'دولار': 1000}, await balances(ahmed));
    });

    test('an archived debt is left alone', () async {
      final Person ahmed = await person();
      final Debt archived =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'مؤرشف', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'مفتوح', dueAt: addDays(dateOnly(now), 1));
      await service.setDebtArchived(archived.id, true);

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000));

      expect(<String, int>{'مؤرشف': 1000, 'مفتوح': 0}, await balances(ahmed));
    });

    test('a settled debt takes nothing even when it sorts first', () async {
      final Person ahmed = await person();
      final Debt first =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'مسدَّد', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'مفتوح', dueAt: addDays(dateOnly(now), 1));
      await service.recordPayment(
        first.id,
        PaymentDraft(amountMinor: 1000, paidAt: dateOnly(now)),
      );

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 300));

      expect(<String, int>{'مسدَّد': 0, 'مفتوح': 700}, await balances(ahmed));
    });

    test('a legacy shared record is refused, and the rest is still paid',
        () async {
      final Person ahmed = await person();
      final Person khalid = await person('خالد');
      // A shared record cannot be created through the service any more, so one
      // is written straight in — which is exactly how it exists on a phone.
      await db.debtsDao.upsert(
        DebtRow(
          id: 'shared',
          personId: ahmed.id,
          direction: DebtDirection.iOwe,
          title: 'مشترك',
          principalMinor: 1000,
          currencyCode: 'INR',
          issuedAt: dateOnly(now),
          dueAt: dateOnly(now),
          reminderLeads: const <ReminderLead>[],
          recurrence: RecurrenceFrequency.none,
          recurrenceInterval: 0,
          createdAt: now,
          updatedAt: now,
        ),
        personIds: <String>[ahmed.id, khalid.id],
      );
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 800, title: 'عادي', dueAt: dateOnly(now));

      // The shared record sorts first (same due date, same issued day, lower id)
      // and would abort the whole transaction if it were allowed in. It is not.
      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 500));

      expect(written, hasLength(1));
      expect(await balances(ahmed), <String, int>{'مشترك': 1000, 'عادي': 300});
    });
  });

  group('undo', () {
    test('removes every share and puts the balances back', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 2000, title: 'ثاني', dueAt: addDays(dateOnly(now), 1));

      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500));
      expect(await balances(ahmed), <String, int>{'أول': 0, 'ثاني': 1500});

      await service.deletePaymentsBatch(
        written.map((Payment p) => p.id).toList(),
      );

      expect(<String, int>{'أول': 1000, 'ثاني': 2000}, await balances(ahmed));
      expect(await service.payments.getAll(), isEmpty);
    });

    test('reopens a debt the payment had closed', () async {
      final Person ahmed = await person();
      final Debt only =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'قرض', dueAt: dateOnly(now));
      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000));
      expect((await service.debts.getById(only.id))!.closedAt, isNotNull);

      await service.deletePaymentsBatch(<String>[written.single.id]);

      expect((await service.debts.getById(only.id))!.closedAt, isNull);
      expect(await balances(ahmed), <String, int>{'قرض': 1000});
    });

    test('writes one deletion entry per debt, carrying what came off it',
        () async {
      final Person ahmed = await person();
      final Debt first =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      final Debt second = await debtFor(
        ahmed,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 1000,
        title: 'ثاني',
        dueAt: addDays(dateOnly(now), 1),
      );

      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1500));
      await service.deletePaymentsBatch(
        written.map((Payment p) => p.id).toList(),
      );

      Future<int> removedFor(Debt debt) async {
        final List<ActivityEntry> feed =
            await service.activity.forEntity(RelatedEntityType.debt, debt.id);
        return feed
            .firstWhere((ActivityEntry e) => e.type == ActivityType.paymentDeleted)
            .amountMinor!;
      }

      expect(await removedFor(first), 1000);
      expect(await removedFor(second), 500);
    });

    test('an id that is already gone is skipped, not fatal', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'قرض', dueAt: dateOnly(now));
      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 400));

      await service.deletePaymentsBatch(<String>[
        'not-a-real-payment',
        written.single.id,
      ]);

      expect(await balances(ahmed), <String, int>{'قرض': 1000});
    });

    test('an empty list does nothing at all', () async {
      await expectLater(
        service.deletePaymentsBatch(const <String>[]),
        completes,
      );
    });
  });

  group('accounting', () {
    test('the debt reads the split back through the ordinary totals', () async {
      final Person ahmed = await person();
      final Debt only =
          await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'قرض', dueAt: dateOnly(now));

      // Two person-level payments against the same debt, plus a hand-recorded
      // one: all three have to add up the same way.
      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 200));
      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 300));
      await service.recordPayment(
        only.id,
        PaymentDraft(amountMinor: 100, paidAt: dateOnly(now)),
      );

      expect(await balances(ahmed), <String, int>{'قرض': 400});
    });

    test('a monthly report sees the shares as ordinary payments', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'أول', dueAt: dateOnly(now));
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'ثاني', dueAt: addDays(dateOnly(now), 1));

      await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1200));

      final int paid = await db.debtsDao.debtPaymentsTotalBetween(
        currencyCode: 'INR',
        from: dateOnly(now),
        to: dateOnly(now),
      );
      expect(paid, 1200, reason: 'the month is told what moved, not how');
    });

    test('money beyond what is owed is not written', () async {
      final Person ahmed = await person();
      await debtFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 1000, title: 'قرض', dueAt: dateOnly(now));

      // The sheet caps the field, but the service is the last line: it applies
      // what is owed and stops, rather than filing a payment larger than any
      // debt to explain.
      final List<Payment> written =
          await service.recordPersonPayment(draftFor(direction: DebtDirection.iOwe, currency: AppCurrency.inr, ahmed, amountMinor: 5000));

      expect(written.single.amountMinor, 1000);
      expect(await balances(ahmed), <String, int>{'قرض': 0});
    });
  });
}
