import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/domain/services/participant_rules.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One record, several people.
///
/// The whole feature turns on a single invariant: **the money is counted once**.
/// A debt linked to three people is one amount in the ledger, one line in a
/// report, one payment history — and it appears on each participant's page as
/// one of their own debts, in full and once: never multiplied by the number of
/// people on it, and never divided between them either, because the product has
/// no notion of a per-person share to divide by.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;

  setUp(() {
    db = AppDatabase.memory();
    service = buildService(db);
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  final DateTime today = dateOnly(DateTime.now());

  Future<Person> addPerson(String name) =>
      service.createPerson(PersonDraft(name: name));

  Future<List<DebtView>> views() => queries
      .watchDebtViews(dueSoonWindowDays: 7, asOf: today)
      .first;

  Future<Debt> sharedDinner({
    required List<Person> withPeople,
    int principalMinor = 150000,
  }) =>
      service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: withPeople.map((Person p) => p.id).toList(),
          title: 'فاتورة العشاء',
          principalMinor: principalMinor,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

  group('one record, several participants', () {
    test('is stored as one debt with one link per person', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');

      final Debt debt = await sharedDinner(
        withPeople: <Person>[ahmed, ali, mohammed],
      );

      // One debt row — not one per person, which is the shape this feature
      // exists to prevent.
      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(
        await db.debtsDao.participantsFor(debt.id),
        <String>[ahmed.id, ali.id, mohammed.id],
        reason: 'the order is the user\'s, and it decides which person '
            'single-valued fields read',
      );
      expect(debt.isShared, isTrue);
      expect(debt.personId, ahmed.id, reason: 'the first person named');
    });

    test('keeps the record visible on every participant’s page', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed, ali]);

      for (final Person person in <Person>[ahmed, ali]) {
        final PersonLedger? ledger = await queries
            .watchPersonLedger(person.id, dueSoonWindowDays: 7, asOf: today)
            .first;
        expect(ledger, isNotNull);
        expect(
          ledger!.debts.map((DebtView v) => v.debt.id),
          <String>[debt.id],
          reason: '${person.name} is on this record',
        );
        expect(ledger.debts.single.participants, hasLength(2));
      }
    });

    test('counts the amount once in the ledger, not once per person', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await sharedDinner(withPeople: <Person>[ahmed, ali, mohammed]);

      final List<DebtView> all = await views();
      expect(all, hasLength(1));

      final CurrencyTotals totals = DebtCalculator.totalsByCurrency(
        all,
        asOf: today,
        dueSoonWindowDays: 7,
      ).single;
      expect(totals.owedToMeMinor, 150000);
      expect(totals.owedToMeCount, 1);
    });

    test('reads as one of each participant’s own debts', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await sharedDinner(withPeople: <Person>[ahmed, ali]);

      final PersonLedger ledger = (await queries
          .watchPersonLedger(ahmed.id, dueSoonWindowDays: 7, asOf: today)
          .first)!;

      // Ahmed's page is about Ahmed's side of the record, so the record is one
      // of his debts: 1,500 is the amount he sees — not a share of it, and not
      // three times it.
      expect(ledger.debts.single.displayNameFor(ahmed.id), 'فاتورة العشاء');
      expect(ledger.totals.single.owedToMeMinor, 150000);
      expect(ledger.totals.single.owedToMeCount, 1);
      expect(ledger.totals.single.totalCount, 1);
      expect(ledger.openDebtCount, 1, reason: 'it is still open money');
    });

    test('does not multiply a record by the number of people on it', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await sharedDinner(withPeople: <Person>[ahmed, ali, mohammed]);

      // Each page states the record once, and the ledger — the only place the app
      // adds records together — holds the same 1,500. There is no 4,500
      // anywhere, and no page shows a fraction either.
      for (final Person person in <Person>[ahmed, ali, mohammed]) {
        final PersonLedger ledger = (await queries
            .watchPersonLedger(person.id, dueSoonWindowDays: 7, asOf: today)
            .first)!;
        expect(
          ledger.totals.single.owedToMeMinor,
          150000,
          reason: '${person.name} sees the record as one of their debts',
        );
      }

      final int ledgerTotal = (await views()).fold<int>(
        0,
        (int sum, DebtView v) => sum + v.remainingMinor,
      );
      expect(ledgerTotal, 150000);
    });

    test('counts it once on each page of the people directory too', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person salem = await addPerson('سالم');
      await sharedDinner(withPeople: <Person>[ahmed, ali]);

      // Salem's own debt, so the directory also holds a one-person record.
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[salem.id],
          title: 'سلفة',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      final List<PersonDirectoryEntry> directory = await queries
          .watchPersonDirectory(dueSoonWindowDays: 7, asOf: today)
          .first;
      final Map<String, PersonDirectoryEntry> byId = <String, PersonDirectoryEntry>{
        for (final PersonDirectoryEntry e in directory) e.person.id: e,
      };

      expect(byId[ahmed.id]!.totals.single.owedToMeMinor, 150000);
      expect(byId[ali.id]!.totals.single.owedToMeMinor, 150000);
      expect(byId[salem.id]!.totals.single.owedToMeMinor, 100000);

      // The ledger is the aggregate view and counts each record once. Pages are
      // views of one relationship each, so they can show the same record; what
      // must never happen is the *ledger* counting it twice.
      final int ledgerTotal = (await views()).fold<int>(
        0,
        (int sum, DebtView v) => sum + v.remainingMinor,
      );
      expect(ledgerTotal, 250000, reason: '1,500 + 1,000, each record once');
    });

    test('is one payment history and one remaining balance', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await sharedDinner(
        withPeople: <Person>[ahmed, ali, mohammed],
      );

      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 50000, paidAt: today),
      );

      final List<Payment> payments = await service.payments.forDebt(debt.id);
      expect(payments, hasLength(1), reason: 'a payment is against the record');
      expect(payments.single.amountMinor, 50000);

      final DebtView view = (await views()).single;
      expect(view.paidMinor, 50000);
      expect(view.remainingMinor, 100000);
    });

    test('names nobody and is refused rather than stored', () async {
      await expectLater(
        () => service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            title: 'بلا شخص',
            principalMinor: 100000,
            currency: AppCurrency.inr,
            issuedAt: today,
          ),
        ),
        throwsA(isA<MissingParticipantsException>()),
      );
      expect(await db.debtsDao.getAll(), isEmpty);
    });

    test('drops a repeated person instead of linking them twice', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');

      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id, ali.id, ahmed.id, '  '],
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      expect(debt.personIds, <String>[ahmed.id, ali.id]);
      expect(await db.debtsDao.participantsFor(debt.id), hasLength(2));
    });

    test('refuses to link a person who does not exist, writing nothing', () async {
      await addPerson('أحمد');
      await expectLater(
        () => service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>['does-not-exist'],
            principalMinor: 100000,
            currency: AppCurrency.inr,
            issuedAt: today,
          ),
        ),
        throwsA(anything),
      );
      // The row was written first and then rolled back with the links: a debt
      // that names somebody who is not there is not a debt.
      expect(await db.debtsDao.getAll(), isEmpty);
      expect(await db.debtsDao.allParticipants(), isEmpty);
    });
  });

  group('editing the participants', () {
    test('adds and removes people without touching the debt', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed, ali]);
      // Stored as epoch milliseconds, so that is the precision to compare at.
      final int createdAt = debt.createdAt.millisecondsSinceEpoch;

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: debt.direction,
          personIds: <String>[ahmed.id, mohammed.id],
          title: debt.title,
          principalMinor: debt.principalMinor,
          currency: debt.currency,
          issuedAt: debt.issuedAt,
        ),
      );

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.id, debt.id);
      expect(reloaded.createdAt.millisecondsSinceEpoch, createdAt);
      expect(reloaded.personIds, <String>[ahmed.id, mohammed.id]);
      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(await db.debtsDao.participantsFor(debt.id), hasLength(2));
    });

    test('keeps the payments when the participants change', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed, ali]);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 30000, paidAt: today),
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: debt.direction,
          personIds: <String>[ahmed.id, mohammed.id],
          principalMinor: 120000,
          currency: debt.currency,
          issuedAt: debt.issuedAt,
        ),
      );

      final DebtView view = (await views()).single;
      expect(view.paymentCount, 1);
      expect(view.paidMinor, 30000);
      expect(view.remainingMinor, 90000, reason: 'recomputed from 120,000');
      expect(view.status.isOpen, isTrue);
    });

    test('re-points the one-value column at the first person left', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed, ali]);
      expect((await db.debtsDao.getById(debt.id))!.personId, ahmed.id);

      await db.debtsDao.removeParticipant(debt.id, ahmed.id);

      expect((await db.debtsDao.getById(debt.id))!.personId, ali.id);
      expect(await db.debtsDao.participantsFor(debt.id), <String>[ali.id]);
    });

    test('refuses to leave a record with nobody on it', () async {
      final Person ahmed = await addPerson('أحمد');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed]);

      await expectLater(
        () => service.updateDebt(
          debt.id,
          DebtDraft(
            direction: debt.direction,
            principalMinor: debt.principalMinor,
            currency: debt.currency,
            issuedAt: debt.issuedAt,
          ),
        ),
        throwsA(isA<MissingParticipantsException>()),
      );

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, <String>[ahmed.id]);
    });
  });

  group('saving twice and saving concurrently', () {
    test('two rapid edits leave one debt and no duplicated links', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed]);

      // The shape a double-tapped Save produces: the same draft applied twice,
      // overlapping, with no await between the calls.
      final DebtDraft draft = DebtDraft(
        direction: debt.direction,
        personIds: <String>[ahmed.id, ali.id],
        title: debt.title,
        principalMinor: 200000,
        currency: debt.currency,
        issuedAt: debt.issuedAt,
      );
      await Future.wait<void>(<Future<void>>[
        service.updateDebt(debt.id, draft),
        service.updateDebt(debt.id, draft),
      ]);

      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(await db.debtsDao.participantsFor(debt.id), hasLength(2));
      final DebtView view = (await views()).single;
      expect(view.debt.principalMinor, 200000);
    });

    test('the stored one-value column always equals the first link', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await sharedDinner(withPeople: <Person>[ahmed, ali]);

      Future<void> checkInvariant() async {
        final Map<String, List<String>> links =
            await db.debtsDao.allParticipants();
        for (final DebtRow row in await db.debtsDao.getAll()) {
          final List<String> people = links[row.id] ?? const <String>[];
          expect(
            row.personId,
            people.isEmpty ? null : people.first,
            reason: 'debt ${row.id}: person_id and debt_people disagree',
          );
        }
      }

      await checkInvariant();
      await db.debtsDao.setParticipants(debt.id, <String>[ali.id, ahmed.id]);
      await checkInvariant();
      await db.debtsDao.removeParticipant(debt.id, ali.id);
      await checkInvariant();
    });
  });

  group('removing a person', () {
    test('takes them off a shared record and keeps the rest', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await sharedDinner(
        withPeople: <Person>[ahmed, ali, mohammed],
      );

      await service.deletePerson(ali.id);

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, <String>[ahmed.id, mohammed.id]);
      expect((await db.debtsDao.getById(debt.id))!.personId, ahmed.id);
      expect(await db.debtsDao.allParticipants(), hasLength(1));
    });

    test('keeps a single-person debt’s money but unlinks it', () async {
      final Person ahmed = await addPerson('أحمد');
      await addPerson('سالم');
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

      await service.deletePerson(ahmed.id);

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, isEmpty);
      expect(reloaded.principalMinor, 100000, reason: 'the money is still owed');
      expect((await views()).single.displayName, 'قرض');
    });

    test('leaves no links behind for the person who is gone', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await sharedDinner(withPeople: <Person>[ahmed, ali]);
      await service.deletePerson(ahmed.id);

      final Map<String, List<String>> links = await db.debtsDao.allParticipants();
      expect(
        links.values.expand((List<String> ids) => ids),
        isNot(contains(ahmed.id)),
        reason: 'no link may outlive the person it names',
      );
      expect(await db.peopleDao.getById(ahmed.id), isNull);
      expect(links.values.expand((List<String> ids) => ids), contains(ali.id));
    });
  });

  group('merging two people', () {
    test('moves the links without duplicating a shared record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person duplicate = await addPerson('أحمد ٢');

      final Debt shared = await sharedDinner(
        withPeople: <Person>[ahmed, ali],
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[duplicate.id],
          title: 'دين مكرر',
          principalMinor: 50000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      await service.debts.reassignPerson(duplicate.id, ahmed.id);

      expect(
        await db.debtsDao.participantsFor(shared.id),
        <String>[ahmed.id, ali.id],
        reason: 'Ahmed is already on this record, so the link is not doubled',
      );
      final List<Debt> ahmedDebts = await service.debts.forPerson(ahmed.id);
      expect(ahmedDebts, hasLength(2));
    });
  });

  group('notifications', () {
    test('one record produces one reminder, not one per participant', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final DateTime due = addDays(today, 3);
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, ali.id, mohammed.id],
          title: 'فاتورة العشاء',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: due,
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );

      final List<NotificationIntent> intents = NotificationPlanner.plan(
        debts: await views(),
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: AppSettings.initial.copyWith(
          defaultCurrency: AppCurrency.inr,
        ),
        now: today,
      );

      final List<NotificationIntent> forTheDebt = intents
          .where((NotificationIntent i) =>
              i.kind == NotificationKind.debtDueSoon ||
              i.kind == NotificationKind.debtDueToday)
          .toList();
      expect(
        forTheDebt,
        hasLength(1),
        reason: 'three participants on one record is still one thing to be '
            'reminded about',
      );
      expect(forTheDebt.single.payload, 'debt:${debt.id}');
    });
  });

  group('the report', () {
    test('counts a shared debt once, whatever the number of people', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await sharedDinner(withPeople: <Person>[ahmed, ali, mohammed]);

      final MonthlyReport report = await queries
          .watchMonthlyReport(
            year: today.year,
            month: today.month,
            currency: AppCurrency.inr,
            trendMonths: 6,
            asOf: today,
          )
          .first;

      expect(report.activeDebts, 1, reason: 'one record, three participants');
      expect(report.openOwedToMeMinor, 150000);
      expect(report.newDebtMinor, 150000);
    });
  });

  group('the statement and the report', () {
    test('prints a multi-person record as an ordinary line, once', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await sharedDinner(withPeople: <Person>[ahmed, ali]);
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'سلفة',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      final PersonLedger ledger = (await queries
          .watchPersonLedger(ahmed.id, dueSoonWindowDays: 7, asOf: today)
          .first)!;
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
      final StatementData data = StatementService(
        localizations: l10n,
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: l10n,
        ),
      ).buildData(
        ledger: ledger,
        payments: await service.payments.getAll(),
        currency: AppCurrency.inr,
        now: today,
      );

      // Ahmed's statement is Ahmed's page in print: both records are his, each
      // counted once — 1,500 + 1,000, never 1,500 three times.
      expect(data.totalMinor, 250000);
      expect(data.debts, hasLength(2));

      // The history table follows the same rule as the totals: the running
      // balance it ends on is the remaining figure printed at the top.
      final int lastBalance = data.entries.last.balanceAfterMinor;
      expect(lastBalance, data.remainingMinor);
    });
  });
}
