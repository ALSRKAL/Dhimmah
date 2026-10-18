import 'dart:math';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/database/daos/debts_dao.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The accounting invariants, re-checked after **every** write.
///
/// A ledger is not a set of screens that happen to agree today: it is a set of
/// numbers that must agree after any sequence of operations a user can produce.
/// This file drives long, deliberately tangled sequences through the real
/// service — both directions, several currencies, single and distributed
/// payments, corrections, deletions, undo, archive and restore, commitments and
/// income — and re-checks the same three invariants after each step:
///
/// 1. **The triple balance.** What the dashboard adds up, what the people's
///    pages add up to between them, and what the records themselves say, agreed
///    per direction and per currency. Three different code paths
///    ([DebtCalculator.totalsByCurrency] over the whole ledger, the same over
///    each person's page, and principal-minus-payments read row by row) must
///    produce one set of numbers.
/// 2. **The closing stamp.** A record carries `closedAt` exactly when nothing is
///    left on it — never closed with money still owed, never open with nothing.
/// 3. **The database itself.** `PRAGMA foreign_key_check` finds no orphaned rows
///    and `PRAGMA integrity_check` finds no structural damage.
///
/// The scripted chain is written so a failure names the step that broke it; the
/// seeded fuzz behind it explores orderings no one would think to write down.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late DateTime now;

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 9, 15, 10);
    service = buildService(db, clock: () => now);
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      incomes: IncomeRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  DateTime today() => dateOnly(now);

  const int window = 7;

  // --- the three readings --------------------------------------------------

  /// `direction|currency` → what is outstanding, in minor units.
  Map<String, int> bucketsFrom(List<CurrencyTotals> totals) {
    final Map<String, int> out = <String, int>{};
    for (final CurrencyTotals total in totals) {
      _add(out, '${DebtDirection.iOwe.name}|${total.currency.code}', total.iOweMinor);
      _add(
        out,
        '${DebtDirection.owedToMe.name}|${total.currency.code}',
        total.owedToMeMinor,
      );
    }
    return out;
  }

  Future<Map<String, int>> dashboardBalances() async {
    final DashboardSnapshot snapshot = await queries
        .watchDashboard(
          dueSoonWindowDays: window,
          defaultCurrency: AppCurrency.inr,
          asOf: today(),
        )
        .first;
    return bucketsFrom(snapshot.totalsByCurrency);
  }

  Future<Map<String, int>> peopleBalances() async {
    final List<PersonDirectoryEntry> entries = await queries
        .watchPersonDirectory(dueSoonWindowDays: window, asOf: today())
        .first;
    final Map<String, int> out = <String, int>{};
    for (final PersonDirectoryEntry entry in entries) {
      _addAll(out, bucketsFrom(entry.totals));
    }
    return out;
  }

  /// What the rows say: principal minus the payments filed against it, per
  /// record, added up by direction and currency.
  Future<Map<String, int>> rowBalances() async {
    final Map<String, int> paid = await _paidByDebt(db);
    final Map<String, int> out = <String, int>{};
    for (final DebtRow row in await db.debtsDao.getAll()) {
      if (row.archivedAt != null) continue;
      final int remaining = DebtCalculator.remainingOf(
        row.principalMinor,
        paid[row.id] ?? 0,
      );
      if (remaining <= 0) continue;
      _add(out, '${row.direction.name}|${row.currencyCode}', remaining);
    }
    return out;
  }

  // --- the invariants -----------------------------------------------------

  Future<void> expectBalancesAgree(String step) async {
    final Map<String, int> dashboard = await dashboardBalances();
    expect(
      await rowBalances(),
      dashboard,
      reason: '$step: the records and the dashboard disagree',
    );
    expect(
      await peopleBalances(),
      dashboard,
      reason: '$step: the people\'s pages and the dashboard disagree',
    );
  }

  Future<void> expectClosingStampsMatchTheMoney() async {
    final Map<String, int> paid = await _paidByDebt(db);
    for (final DebtRow row in await db.debtsDao.getAll()) {
      final int left = DebtCalculator.remainingOf(
        row.principalMinor,
        paid[row.id] ?? 0,
      );
      expect(
        row.closedAt != null,
        left <= 0,
        reason: 'record ${row.id}: principal=${row.principalMinor}, '
            'paid=${paid[row.id] ?? 0}, closedAt=${row.closedAt}',
      );
    }
  }

  Future<void> expectDatabaseSound() async {
    final List<QueryRow> orphans =
        await db.customSelect('PRAGMA foreign_key_check').get();
    expect(
      orphans.map((QueryRow r) => r.data).toList(),
      isEmpty,
      reason: 'rows point at records that no longer exist',
    );
    final String verdict = (await db
            .customSelect('PRAGMA integrity_check')
            .get())
        .single
        .data
        .values
        .first
        .toString();
    expect(verdict, 'ok');
  }

  Future<void> checkAll(String step) async {
    await expectBalancesAgree(step);
    await expectClosingStampsMatchTheMoney();
    await expectDatabaseSound();
  }

  // --- the scenario --------------------------------------------------------

  test('the three balances agree after every step of a tangled sequence',
      () async {
    Future<void> step(String name, Future<void> Function() write) async {
      await write();
      await checkAll(name);
    }

    final Person ahmed =
        await service.createPerson(const PersonDraft(name: 'أحمد'));
    final Person ali =
        await service.createPerson(const PersonDraft(name: 'علي'));
    final Person salem =
        await service.createPerson(const PersonDraft(name: 'سالم'));
    await checkAll('seed: people');

    late Debt rent; // iOwe, INR, monthly — the recurring one
    late Debt loan; // owedToMe, INR
    late Debt dollars; // owedToMe, USD
    late Debt shop; // iOwe, INR, no due date

    await step('add a recurring rent', () async {
      rent = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'إيجار',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today(),
          dueAt: today(),
          recurrence: RecurrenceFrequency.monthly,
        ),
      );
    });
    await step('add a loan in the other direction', () async {
      loan = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ali.id],
          title: 'سلفة',
          principalMinor: 50000,
          currency: AppCurrency.inr,
          issuedAt: today(),
          dueAt: addDays(today(), 3),
        ),
      );
    });
    await step('add a debt in a second currency', () async {
      dollars = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'دولارات',
          principalMinor: 30000,
          currency: AppCurrency.usd,
          issuedAt: today(),
        ),
      );
    });
    await step('add a third person\'s record', () async {
      shop = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[salem.id],
          title: 'متجر',
          principalMinor: 70000,
          currency: AppCurrency.inr,
          issuedAt: today(),
        ),
      );
    });

    await step('part of the rent is paid', () async {
      await service.recordPayment(
        rent.id,
        PaymentDraft(amountMinor: 40000, paidAt: today()),
      );
    });

    late List<Payment> firstSplit;
    await step('a person-level payment is split across their dollars', () async {
      firstSplit = await service.recordPersonPayment(
        PersonPaymentDraft(
          personId: ahmed.id,
          direction: DebtDirection.owedToMe,
          currency: AppCurrency.usd,
          amountMinor: 25000,
          paidAt: today(),
        ),
      );
      expect(firstSplit, hasLength(1), reason: 'one debt, one share');
      expect(firstSplit.single.amountMinor, 25000);
    });

    late Debt secondUsd;
    await step('a second dollar record arrives', () async {
      secondUsd = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id],
          title: 'دولارات ٢',
          principalMinor: 25000,
          currency: AppCurrency.usd,
          // Dated after the first, so the plan's "oldest first" is decided by
          // the dates the user typed rather than by which id was generated
          // first — the split is stable either way, but only this is readable.
          issuedAt: addDays(today(), 1),
        ),
      );
    });

    late List<Payment> settlingSplit;
    await step('one more split settles both dollar records', () async {
      settlingSplit = await service.recordPersonPayment(
        PersonPaymentDraft(
          personId: ahmed.id,
          direction: DebtDirection.owedToMe,
          currency: AppCurrency.usd,
          amountMinor: 40000,
          paidAt: today(),
        ),
      );
      expect(
        settlingSplit.map((Payment p) => p.amountMinor).toList(),
        <int>[5000, 25000],
        reason: 'the older record takes the 5,000 it still needs, the newer one '
            'the 25,000 it needs',
      );
      expect(settlingSplit.map((Payment p) => p.debtId).toList(),
          <String>[dollars.id, secondUsd.id]);
      expect(
        settlingSplit.fold<int>(0, (int sum, Payment p) => sum + p.amountMinor),
        30000,
        reason: 'the record the money could not reach takes nothing, so 10,000 '
            'of the 40,000 the user asked to pay is written nowhere — and the '
            'undo below therefore never takes it back',
      );
    });

    await step('a corrected split share reopens its record', () async {
      await service.updatePayment(
        settlingSplit.first.id,
        PaymentDraft(amountMinor: 2000, paidAt: today()),
      );
      expect(
        (await service.debts.getById(dollars.id))!.closedAt,
        isNull,
        reason: '2,000 does not clear 30,000 minus 25,000',
      );
    });

    await step('the split is undone as one batch', () async {
      final int leftInPlace = await service.deletePaymentsBatch(
        <String>[settlingSplit.first.id, settlingSplit.last.id],
      );
      expect(leftInPlace, 0, reason: 'neither record recurs');
      expect(
        (await service.debts.getById(secondUsd.id))!.closedAt,
        isNull,
        reason: 'undoing the money reopens what it closed',
      );
    });

    late Payment fullRent;
    late int followUpsAfterClosing;
    await step('the rest of the rent closes it and starts the next month',
        () async {
      fullRent = await service.recordPayment(
        rent.id,
        PaymentDraft(
          amountMinor: (await service.debts.getById(rent.id))!.principalMinor -
              40000,
          paidAt: today(),
        ),
      );
      expect((await service.debts.getById(rent.id))!.closedAt, isNotNull);
      followUpsAfterClosing = (await service.debts.getAll()).length;
      expect(followUpsAfterClosing, 6, reason: '4 records + 2 dollars + the '
          'next month of the rent');
    });

    await step('correcting that payment down reopens the rent and takes the '
        'next month back', () async {
      await service.updatePayment(
        fullRent.id,
        PaymentDraft(amountMinor: 10000, paidAt: today()),
      );
      expect((await service.debts.getById(rent.id))!.closedAt, isNull);
      expect(
        (await service.debts.getAll()).length,
        followUpsAfterClosing - 1,
        reason: 'the period that existed only because the rent was settled',
      );
    });

    await step('correcting it back up settles the rent again', () async {
      await service.updatePayment(
        fullRent.id,
        PaymentDraft(amountMinor: 100000, paidAt: today()),
      );
      expect((await service.debts.getById(rent.id))!.closedAt, isNotNull);
      expect((await service.debts.getAll()).length, followUpsAfterClosing);
    });

    await step('deleting that payment takes both the closing and the period',
        () async {
      await service.deletePayment(fullRent.id);
      expect((await service.debts.getById(rent.id))!.closedAt, isNull);
      expect((await service.debts.getAll()).length, followUpsAfterClosing - 1);
    });

    await step('redoing the deleted payment restores both', () async {
      await service.restorePaymentRecord(fullRent);
      expect((await service.debts.getById(rent.id))!.closedAt, isNotNull);
      expect((await service.debts.getAll()).length, followUpsAfterClosing);
    });

    await step('archiving a record takes it out of every total', () async {
      await service.setDebtArchived(shop.id, true);
    });
    await step('and un-archiving brings it back', () async {
      await service.setDebtArchived(shop.id, false);
    });

    await step('the rent is re-tagged to dollars, and its payment follows',
        () async {
      final Debt before = (await service.debts.getById(rent.id))!;
      await service.updateDebt(
        rent.id,
        _draftOf(before, currency: AppCurrency.usd),
      );
      final List<Payment> history =
          await service.payments.forDebt(rent.id);
      expect(history, isNotEmpty);
      for (final Payment payment in history) {
        expect(
          payment.currency,
          AppCurrency.usd,
          reason: 'a payment has no currency of its own — it is the record\'s, '
              'so a retagged record would otherwise keep its old-currency '
              'payments and the two would be added as though they were one unit',
        );
      }
      // The period that was created when this one was settled is *its own*
      // record, with its own history, and the edit above did not reach it.
      //
      // That is deliberate and it is the smaller surprise of the two: the
      // alternative is an edit to one record silently re-tagging a record the
      // user never opened. It is stated here so the behaviour is a decision
      // rather than an accident — the totals below count it in rupees, so a
      // change to this rule cannot pass unnoticed.
      final List<Debt> chain = (await service.debts.getAll())
          .where((Debt debt) => debt.title == 'إيجار')
          .toList();
      expect(chain, hasLength(2), reason: 'the settled one and the next');
      final Debt next =
          chain.firstWhere((Debt debt) => debt.id != rent.id);
      expect(next.currency, AppCurrency.inr);
      expect(next.closedAt, isNull);
    });

    await step('deleting a record and undoing it changes nothing', () async {
      final int before = (await service.debts.getAll()).length;
      final LedgerServiceSnapshot snapshot =
          await service.deleteDebtWithSnapshot(loan.id);
      expect((await service.debts.getAll()).length, before - 1);
      await service.restoreDeleted(snapshot);
      expect((await service.debts.getAll()).length, before);
    });

    await step('a commitment is added and one period of it is paid', () async {
      final Obligation obligation = await service.createObligation(
        ObligationDraft(
          name: 'إنترنت',
          category: ObligationCategory.telecom,
          amountMinor: 120000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: today(),
          dayOfMonth: today().day,
        ),
      );
      await service.ensureOccurrences();
      final List<ObligationInstance> instances = await queries
          .watchObligationInstances(asOf: today())
          .first;
      final ObligationInstance period = instances
          .where((ObligationInstance i) =>
              i.obligation.id == obligation.id && i.occurrence.isPayable)
          .first;
      await service.markObligationPaid(period);
      expect(
        (await service.obligations.getById(obligation.id))!.nextDueAt.isAfter(today()),
        isTrue,
      );
    });

    await step('an income is added', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'راتب',
          amountMinor: 250000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: today(),
          dayOfMonth: 1,
        ),
      );
    });

    // The absolute figures, not only the agreement between readings: three
    // readings can agree on a wrong number, and the arithmetic of this scenario
    // is small enough to state outright.
    expect(
      await dashboardBalances(),
      <String, int>{
        // The shop, and the rent's next period.
        //
        // The next period was created when the rent was settled, in the
        // currency the rent had *then*; re-tagging the settled period moved
        // that record and its own payments, not this one. So rupees.
        'iOwe|INR': 70000 + 100000,
        'owedToMe|INR': 50000,
        // Both dollar records as the batch undo left them: the 25,000 of the
        // first split was never touched, and the corrected 2,000 was undone
        // along with the 25,000, reopening the 5,000 the first split left.
        'owedToMe|USD': 5000 + 25000,
      },
      reason: 'what the ledger is owed and owes at the end',
    );
    expect(await peopleBalances(), await dashboardBalances());
  });

  test('a record whose person was deleted still counts, and says why', () async {
    // The one case where the dashboard and the people's pages legitimately
    // disagree, so it is written down rather than left to be rediscovered.
    //
    // Deleting a person keeps their money — the confirmation says so in as many
    // words ("ستبقى الديون محفوظة لكن بدون ارتباط بهذا الشخص") — so the record
    // stays in the dashboard's totals and on the debts list, and appears on no
    // person's page because there is no person. The dashboard and the rows still
    // agree with each other, which is the part the ledger depends on.
    final Person ahmed =
        await service.createPerson(const PersonDraft(name: 'أحمد'));
    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: today(),
      ),
    );

    await service.deletePerson(ahmed.id);

    expect(
      (await service.debts.getById(debt.id))!.personIds,
      isEmpty,
      reason: 'no link may outlive the person it names',
    );
    final Map<String, int> dashboard = await dashboardBalances();
    expect(dashboard, <String, int>{'iOwe|INR': 100000});
    expect(await rowBalances(), dashboard, reason: 'the rows still agree');
    expect(
      await peopleBalances(),
      isEmpty,
      reason: 'and nobody\'s page claims it',
    );
    final List<DebtView> views = await queries
        .watchDebtViews(dueSoonWindowDays: window, asOf: today())
        .first;
    expect(views.single.displayName, 'قرض',
        reason: 'the record is still reachable, by its title');
    await expectClosingStampsMatchTheMoney();
    await expectDatabaseSound();
  });

  test('the balances hold through a seeded fuzz of writes', () async {
    final Random random = Random(20261018);
    final List<Person> people = <Person>[
      await service.createPerson(const PersonDraft(name: 'أحمد')),
      await service.createPerson(const PersonDraft(name: 'علي')),
      await service.createPerson(const PersonDraft(name: 'سالم')),
    ];
    final PaymentRepositoryImpl paymentRepo = PaymentRepositoryImpl(db);

    Future<Debt?> pickDebt() async {
      final List<Debt> all = await service.debts.getAll();
      if (all.isEmpty) return null;
      return all[random.nextInt(all.length)];
    }

    Future<void> oneWrite(int seat) async {
      switch (seat) {
        case 0: // record money against one record
          final Debt? debt = await pickDebt();
          if (debt == null) return;
          final int amount = 1 + random.nextInt(debt.principalMinor + 50000);
          await service.recordPayment(
            debt.id,
            PaymentDraft(amountMinor: amount, paidAt: today()),
          );
        case 1: // correct a payment
          final List<Payment> all = await paymentRepo.getAll();
          if (all.isEmpty) return;
          final Payment payment = all[random.nextInt(all.length)];
          await service.updatePayment(
            payment.id,
            PaymentDraft(
              amountMinor: 1 + random.nextInt(200000),
              paidAt: payment.paidAt,
            ),
          );
        case 2: // delete a payment, then put it back
          final List<Payment> all = await paymentRepo.getAll();
          if (all.isEmpty) return;
          final Payment payment = all[random.nextInt(all.length)];
          await service.deletePayment(payment.id);
          await service.restorePaymentRecord(payment);
        case 3: // edit a record's amount
          final Debt? debt = await pickDebt();
          if (debt == null) return;
          await service.updateDebt(
            debt.id,
            _draftOf(debt, principalMinor: 1 + random.nextInt(300000)),
          );
        case 4: // re-tag a record's currency, and its history follows
          final Debt? debt = await pickDebt();
          if (debt == null) return;
          final AppCurrency next =
              AppCurrency.values[random.nextInt(AppCurrency.values.length)];
          await service.updateDebt(debt.id, _draftOf(debt, currency: next));
        case 5: // archive and un-archive
          final Debt? debt = await pickDebt();
          if (debt == null) return;
          await service.setDebtArchived(debt.id, true);
          await service.setDebtArchived(debt.id, false);
        case 6: // a person-level payment over whatever is open
          final Person person = people[random.nextInt(people.length)];
          final DebtDirection direction = DebtDirection.values[
              random.nextInt(DebtDirection.values.length)];
          final AppCurrency currency =
              AppCurrency.values[random.nextInt(AppCurrency.values.length)];
          await service.recordPersonPayment(
            PersonPaymentDraft(
              personId: person.id,
              direction: direction,
              currency: currency,
              amountMinor: 1 + random.nextInt(150000),
              paidAt: today(),
            ),
          );
        case 7: // undo a whole group at once
          final List<Payment> all = await paymentRepo.getAll();
          if (all.isEmpty) return;
          final List<String> ids = <String>[
            for (final Payment payment in all)
              if (random.nextBool()) payment.id,
          ];
          if (ids.isEmpty) ids.add(all.first.id);
          await service.deletePaymentsBatch(ids);
        case 8: // a new record
          if ((await service.debts.getAll()).length > 40) return;
          final Person person = people[random.nextInt(people.length)];
          await service.createDebt(
            DebtDraft(
              direction: DebtDirection.values[
                  random.nextInt(DebtDirection.values.length)],
              personIds: <String>[person.id],
              title: 'سجل ${random.nextInt(1000)}',
              principalMinor: 1 + random.nextInt(200000),
              currency:
                  AppCurrency.values[random.nextInt(AppCurrency.values.length)],
              issuedAt: addDays(today(), -random.nextInt(30)),
              dueAt: random.nextBool() ? addDays(today(), random.nextInt(40)) : null,
              recurrence: random.nextInt(4) == 0
                  ? RecurrenceFrequency.monthly
                  : RecurrenceFrequency.none,
            ),
          );
        case 9: // deleting and undoing a whole record
          final Debt? debt = await pickDebt();
          if (debt == null) return;
          final LedgerServiceSnapshot snapshot =
              await service.deleteDebtWithSnapshot(debt.id);
          await service.restoreDeleted(snapshot);
        default: // archiving a person leaves every balance where it was
          final Person person = people[random.nextInt(people.length)];
          await service.setPersonArchived(person.id, archived: true);
          await service.setPersonArchived(person.id, archived: false);
      }
    }

    // Evidence that the fuzz actually drove the ledger somewhere. A sequence
    // that silently skipped every write would have passed every check above
    // while proving nothing at all — and these three facts are what the checks
    // above needed in order to mean anything.
    bool sawPayments = false;
    bool sawClosing = false;
    bool sawSecondCurrency = false;

    for (int i = 0; i < 120; i++) {
      final int seat = random.nextInt(11);
      await oneWrite(seat);
      final List<Debt> state = await service.debts.getAll();
      sawPayments |= (await paymentRepo.getAll()).isNotEmpty;
      sawClosing |= state.any((Debt debt) => debt.closedAt != null);
      sawSecondCurrency |= state.any((Debt debt) => debt.currency != AppCurrency.inr);
      await checkAll('fuzz step $i (write $seat)');
    }

    expect(sawPayments, isTrue, reason: 'money was written at some point');
    expect(sawClosing, isTrue, reason: 'a record was settled at some point');
    expect(sawSecondCurrency, isTrue, reason: 'a second currency was in play');
    expect(
      (await service.debts.getAll()).length,
      greaterThan(4),
      reason: 'the sequence ended with more than the four records it began with',
    );
  });
}

/// Every payment filed against each record, summed — read here rather than
/// through the views so the check is independent of the code under test.
Future<Map<String, int>> _paidByDebt(AppDatabase db) async {
  final List<DebtPaymentTotals> totals = await db.debtsDao.paymentTotalsByDebt();
  return <String, int>{
    for (final DebtPaymentTotals total in totals) total.debtId: total.paidMinor,
  };
}

/// The edit form's own shape, built from a stored record: everything the form
/// owns, with only the field a test wants to change replaced.
DebtDraft _draftOf(
  Debt debt, {
  int? principalMinor,
  AppCurrency? currency,
}) =>
    DebtDraft(
      direction: debt.direction,
      personIds: debt.personIds,
      title: debt.title,
      principalMinor: principalMinor ?? debt.principalMinor,
      currency: currency ?? debt.currency,
      issuedAt: debt.issuedAt,
      dueAt: debt.dueAt,
      note: debt.note,
      reminderLeads: debt.reminderLeads,
      recurrence: debt.recurrence,
      recurrenceInterval: debt.recurrenceInterval,
      recurrenceEndAt: debt.recurrenceEndAt,
    );

void _add(Map<String, int> into, String key, int amount) {
  if (amount == 0) return;
  into[key] = (into[key] ?? 0) + amount;
}

void _addAll(Map<String, int> into, Map<String, int> other) {
  other.forEach((String key, int amount) => _add(into, key, amount));
}
