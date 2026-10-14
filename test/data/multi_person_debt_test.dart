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

/// One debt per person.
///
/// Naming several people when recording a debt is a shortcut for recording the
/// same debt with each of them: every participant gets an independent record
/// carrying the full amount, and settling one record never touches another's
/// balance. A full payment from one participant's page used to zero everyone
/// at once, because the record was one shared pot — that is the bug this file
/// pins shut.
///
/// Rows written before the fan-out still exist as one record naming several
/// people. They are kept readable, refuse new payments until the user splits
/// them after reviewing their history, and convert on demand.
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

  /// The same dinner with each of the people: one independent debt apiece.
  Future<List<Debt>> dinnerFor({
    required List<Person> withPeople,
    int principalMinor = 150000,
  }) =>
      service.createDebts(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: withPeople.map((Person p) => p.id).toList(),
          title: 'فاتورة العشاء',
          principalMinor: principalMinor,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

  /// The old shape: one row naming everyone, for the tests that cover how
  /// surviving rows are read, paused and split.
  Future<Debt> legacyDinner({
    required List<Person> withPeople,
    int principalMinor = 150000,
  }) =>
      createLegacySharedDebt(
        service,
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: withPeople.map((Person p) => p.id).toList(),
          title: 'فاتورة العشاء',
          principalMinor: principalMinor,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

  group('fan-out on create', () {
    test('records one independent debt per participant, in full', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');

      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed, ali, mohammed],
      );

      // Three rows — not one shared row, which is the shape that settled
      // everyone at once.
      expect(created, hasLength(3));
      expect(await db.debtsDao.getAll(), hasLength(3));
      for (final Debt debt in created) {
        expect(debt.personIds, hasLength(1));
        expect(debt.isShared, isFalse);
        expect(debt.principalMinor, 150000);
      }
      expect(
        created.map((Debt d) => d.personIds.single).toSet(),
        <String>{ahmed.id, ali.id, mohammed.id},
      );
    });

    test('createDebt hands back the first of the independent debts',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');

      final Debt first = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, ali.id],
          title: 'فاتورة العشاء',
          principalMinor: 150000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      expect(first.personIds, <String>[ahmed.id]);
      expect(await db.debtsDao.getAll(), hasLength(2));
    });

    test('a single participant still records exactly one debt', () async {
      final Person ahmed = await addPerson('أحمد');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );

      expect(created, hasLength(1));
      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(created.single.personIds, <String>[ahmed.id]);
    });

    test('every participant’s page holds only their own record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await dinnerFor(withPeople: <Person>[ahmed, ali]);

      for (final Person person in <Person>[ahmed, ali]) {
        final PersonLedger? ledger = await queries
            .watchPersonLedger(person.id, dueSoonWindowDays: 7, asOf: today)
            .first;
        expect(ledger, isNotNull);
        expect(ledger!.debts, hasLength(1));
        expect(ledger.debts.single.debt.personIds, <String>[person.id]);
        expect(ledger.debts.single.participants, hasLength(1));
        expect(ledger.totals.single.owedToMeMinor, 150000);
        expect(ledger.openDebtCount, 1);
      }
    });

    test('the ledger counts each independent record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await dinnerFor(withPeople: <Person>[ahmed, ali, mohammed]);

      final List<DebtView> all = await views();
      expect(all, hasLength(3));

      final CurrencyTotals totals = DebtCalculator.totalsByCurrency(
        all,
        asOf: today,
        dueSoonWindowDays: 7,
      ).single;
      // Three people each owe the full 1,500: three independent records.
      expect(totals.owedToMeMinor, 450000);
      expect(totals.owedToMeCount, 3);
    });
  });

  group('settling one record leaves the others alone', () {
    test('a full payment settles only its own record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed, ali],
      );
      final Debt ahmedDebt = created.firstWhere(
        (Debt d) => d.personIds.single == ahmed.id,
      );

      await service.recordPayment(
        ahmedDebt.id,
        PaymentDraft(amountMinor: 150000, paidAt: today),
      );

      final List<DebtView> all = await views();
      expect(all, hasLength(2));
      final DebtView settled = all.firstWhere(
        (DebtView v) => v.debt.id == ahmedDebt.id,
      );
      expect(settled.remainingMinor, 0);
      expect(settled.isSettled, isTrue);
      final DebtView open =
          all.firstWhere((DebtView v) => v.debt.id != ahmedDebt.id);
      expect(open.remainingMinor, 150000);
      expect(open.isOpen, isTrue);

      final PersonLedger aliLedger = (await queries
          .watchPersonLedger(ali.id, dueSoonWindowDays: 7, asOf: today)
          .first)!;
      expect(aliLedger.debts.single.remainingMinor, 150000);
      expect(aliLedger.openDebtCount, 1);
    });

    test('a partial payment touches only its own record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed, ali],
      );
      final Debt ahmedDebt = created.firstWhere(
        (Debt d) => d.personIds.single == ahmed.id,
      );

      await service.recordPayment(
        ahmedDebt.id,
        PaymentDraft(amountMinor: 50000, paidAt: today),
      );

      final List<DebtView> all = await views();
      final DebtView paid = all.firstWhere(
        (DebtView v) => v.debt.id == ahmedDebt.id,
      );
      expect(paid.paidMinor, 50000);
      expect(paid.remainingMinor, 100000);
      final DebtView untouched =
          all.firstWhere((DebtView v) => v.debt.id != ahmedDebt.id);
      expect(untouched.paidMinor, 0);
      expect(untouched.remainingMinor, 150000);
    });
  });

  group('validation', () {
    test('names nobody and is refused rather than stored', () async {
      await expectLater(
        () => service.createDebts(
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

    test('drops a repeated person instead of recording them twice', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');

      final List<Debt> created = await service.createDebts(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id, ali.id, ahmed.id, '  '],
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );

      expect(created, hasLength(2));
      expect(
        created.map((Debt d) => d.personIds.single).toSet(),
        <String>{ahmed.id, ali.id},
      );
      expect(await db.debtsDao.getAll(), hasLength(2));
    });

    test('refuses to link a person who does not exist, writing nothing',
        () async {
      await addPerson('أحمد');
      await expectLater(
        () => service.createDebts(
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

  group('legacy shared debts', () {
    test('still load as one row naming everyone', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');

      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali, mohammed],
      );

      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(
        await db.debtsDao.participantsFor(debt.id),
        <String>[ahmed.id, ali.id, mohammed.id],
      );
      expect(debt.isShared, isTrue);
    });

    test('refuse new payments, writing nothing', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali],
      );

      await expectLater(
        () => service.recordPayment(
          debt.id,
          PaymentDraft(amountMinor: 150000, paidAt: today),
        ),
        throwsA(isA<SharedDebtPaymentBlockedException>()),
      );
      expect(await service.payments.forDebt(debt.id), isEmpty);
      final DebtView view = (await views()).single;
      expect(view.remainingMinor, 150000);
      expect(view.isOpen, isTrue);
    });

    test('refuse corrected payments too', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali],
      );
      final Payment payment = await recordLegacyPayment(
        service,
        debt,
        amountMinor: 50000,
        paidAt: today,
      );

      await expectLater(
        () => service.updatePayment(
          payment.id,
          PaymentDraft(amountMinor: 60000, paidAt: today),
        ),
        throwsA(isA<SharedDebtPaymentBlockedException>()),
      );
      expect(
        (await service.payments.forDebt(debt.id)).single.amountMinor,
        50000,
      );
    });

    test('split into independent debts, keeping the history on the first',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali, mohammed],
      );
      await recordLegacyPayment(
        service,
        debt,
        amountMinor: 50000,
        paidAt: today,
      );

      final List<Debt> split = await service.splitSharedDebt(debt.id);

      expect(split, hasLength(3));
      // The original row stays the first participant's debt, with its id and
      // its payment history untouched.
      expect(split.first.id, debt.id);
      expect(split.first.personIds, <String>[ahmed.id]);
      expect(
        split.map((Debt d) => d.personIds.single).toList(),
        <String>[ahmed.id, ali.id, mohammed.id],
      );
      for (final Debt single in split) {
        expect(single.isShared, isFalse);
        expect(single.principalMinor, 150000);
        expect(single.title, 'فاتورة العشاء');
        expect(single.direction, DebtDirection.owedToMe);
        expect(single.currency, AppCurrency.inr);
      }
      final List<Payment> kept = await service.payments.forDebt(debt.id);
      expect(kept, hasLength(1));
      expect(kept.single.amountMinor, 50000);
      for (final Debt single in split.skip(1)) {
        expect(await service.payments.forDebt(single.id), isEmpty);
      }

      final List<DebtView> all = await views();
      expect(all, hasLength(3));
      expect(
        all
            .firstWhere((DebtView v) => v.debt.id == debt.id)
            .remainingMinor,
        100000,
      );
      for (final DebtView v in all.where((DebtView v) => v.debt.id != debt.id)) {
        expect(v.remainingMinor, 150000);
      }
    });

    test('splitting a single debt returns it unchanged', () async {
      final Person ahmed = await addPerson('أحمد');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );

      final List<Debt> split =
          await service.splitSharedDebt(created.single.id);

      expect(split, hasLength(1));
      expect(split.single.id, created.single.id);
      expect(await db.debtsDao.getAll(), hasLength(1));
    });

    test('splitting a missing debt throws rather than writing', () async {
      await expectLater(
        () => service.splitSharedDebt('does-not-exist'),
        throwsA(isA<StateError>()),
      );
    });

    test('a split debt settles independently afterwards', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali],
      );
      final List<Debt> split = await service.splitSharedDebt(debt.id);
      final Debt aliDebt = split.firstWhere(
        (Debt d) => d.personIds.single == ali.id,
      );

      await service.recordPayment(
        aliDebt.id,
        PaymentDraft(amountMinor: 150000, paidAt: today),
      );

      final List<DebtView> all = await views();
      expect(
        all.firstWhere((DebtView v) => v.debt.id == aliDebt.id).isSettled,
        isTrue,
      );
      expect(
        all.firstWhere((DebtView v) => v.debt.id == debt.id).isOpen,
        isTrue,
      );
    });
  });

  group('refusing new shared pots', () {
    test('widening a single debt to several people is refused', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );
      final Debt debt = created.single;

      await expectLater(
        () => service.updateDebt(
          debt.id,
          DebtDraft(
            direction: debt.direction,
            personIds: <String>[ahmed.id, ali.id],
            title: debt.title,
            principalMinor: debt.principalMinor,
            currency: debt.currency,
            issuedAt: debt.issuedAt,
          ),
        ),
        throwsA(isA<NewSharedDebtBlockedException>()),
      );

      // Nothing was written: the record still names Ahmed alone.
      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, <String>[ahmed.id]);
      expect(reloaded.principalMinor, 150000);
      expect(await db.debtsDao.getAll(), hasLength(1));
    });

    test('narrowing a legacy record down to one person stays allowed',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);
      await recordLegacyPayment(
        service,
        debt,
        amountMinor: 30000,
        paidAt: today,
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: debt.direction,
          personIds: <String>[ahmed.id],
          title: debt.title,
          principalMinor: debt.principalMinor,
          currency: debt.currency,
          issuedAt: debt.issuedAt,
        ),
      );

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, <String>[ahmed.id]);
      expect(reloaded.isShared, isFalse);
      final DebtView view = (await views()).single;
      expect(view.paidMinor, 30000);
      expect(view.remainingMinor, 120000);
    });

    test('maintaining a legacy record’s own participants stays allowed',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);

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

      expect(
        (await service.debts.getById(debt.id))!.personIds,
        <String>[ahmed.id, mohammed.id],
      );
    });

    test('splitting a settled legacy record is refused', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(
        withPeople: <Person>[ahmed, ali],
      );
      await recordLegacyPayment(
        service,
        debt,
        amountMinor: 150000,
        paidAt: today,
      );

      await expectLater(
        () => service.splitSharedDebt(debt.id),
        throwsA(isA<StateError>()),
      );

      // The settled pot is untouched: one row, still shared, still settled.
      expect(await db.debtsDao.getAll(), hasLength(1));
      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.isShared, isTrue);
      expect((await views()).single.isSettled, isTrue);
    });
  });

  group('editing the participants', () {
    test('adds and removes people without touching the debt', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);
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
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);
      await recordLegacyPayment(
        service,
        debt,
        amountMinor: 30000,
        paidAt: today,
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
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);
      expect((await db.debtsDao.getById(debt.id))!.personId, ahmed.id);

      await db.debtsDao.removeParticipant(debt.id, ahmed.id);

      expect((await db.debtsDao.getById(debt.id))!.personId, ali.id);
      expect(await db.debtsDao.participantsFor(debt.id), <String>[ali.id]);
    });

    test('refuses to leave a record with nobody on it', () async {
      final Person ahmed = await addPerson('أحمد');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );
      final Debt debt = created.single;

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
      await addPerson('علي');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );
      final Debt debt = created.single;

      // The shape a double-tapped Save produces: the same draft applied twice,
      // overlapping, with no await between the calls.
      final DebtDraft draft = DebtDraft(
        direction: debt.direction,
        personIds: <String>[ahmed.id],
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
      expect(await db.debtsDao.participantsFor(debt.id), <String>[ahmed.id]);
      final DebtView view = (await views()).single;
      expect(view.debt.principalMinor, 200000);
    });

    test('two rapid widenings are both refused and write nothing', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final List<Debt> created = await dinnerFor(
        withPeople: <Person>[ahmed],
      );
      final Debt debt = created.single;

      final DebtDraft draft = DebtDraft(
        direction: debt.direction,
        personIds: <String>[ahmed.id, ali.id],
        title: debt.title,
        principalMinor: 200000,
        currency: debt.currency,
        issuedAt: debt.issuedAt,
      );
      await Future.wait<void>(<Future<void>>[
        expectLater(
          () => service.updateDebt(debt.id, draft),
          throwsA(isA<NewSharedDebtBlockedException>()),
        ),
        expectLater(
          () => service.updateDebt(debt.id, draft),
          throwsA(isA<NewSharedDebtBlockedException>()),
        ),
      ]);

      expect(await db.debtsDao.getAll(), hasLength(1));
      expect(await db.debtsDao.participantsFor(debt.id), <String>[ahmed.id]);
      expect((await views()).single.debt.principalMinor, 150000);
    });

    test('the stored one-value column always equals the first link', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Debt debt = await legacyDinner(withPeople: <Person>[ahmed, ali]);

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
    test('takes them off a legacy shared record and keeps the rest', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final Debt debt = await legacyDinner(
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
      final List<Debt> created = await service.createDebts(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'قرض',
          principalMinor: 100000,
          currency: AppCurrency.inr,
          issuedAt: today,
        ),
      );
      final Debt debt = created.single;

      await service.deletePerson(ahmed.id);

      final Debt reloaded = (await service.debts.getById(debt.id))!;
      expect(reloaded.personIds, isEmpty);
      expect(reloaded.principalMinor, 100000, reason: 'the money is still owed');
      expect((await views()).single.displayName, 'قرض');
    });

    test('leaves no links behind for the person who is gone', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await legacyDinner(withPeople: <Person>[ahmed, ali]);
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
    test('moves the links without duplicating a legacy shared record',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person duplicate = await addPerson('أحمد ٢');

      final Debt shared = await legacyDinner(
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
    test('one legacy record produces one reminder, not one per participant',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      final DateTime due = addDays(today, 3);
      final Debt debt = await createLegacySharedDebt(
        service,
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
        reason: 'three participants on one legacy record is still one thing '
            'to be reminded about',
      );
      expect(forTheDebt.single.payload, 'debt:${debt.id}');
    });

    test('fanned-out debts remind once per record', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final DateTime due = addDays(today, 3);
      final List<Debt> created = await service.createDebts(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, ali.id],
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

      final Set<String?> payloads = <String?>{
        for (final NotificationIntent i in intents
            .where((NotificationIntent i) =>
                i.kind == NotificationKind.debtDueSoon ||
                i.kind == NotificationKind.debtDueToday))
          i.payload,
      };
      expect(
        payloads,
        <String?>{'debt:${created[0].id}', 'debt:${created[1].id}'},
        reason: 'two independent records remind independently',
      );
    });
  });

  group('the report', () {
    test('counts every independent debt', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      final Person mohammed = await addPerson('محمد');
      await dinnerFor(withPeople: <Person>[ahmed, ali, mohammed]);

      final MonthlyReport report = await queries
          .watchMonthlyReport(
            year: today.year,
            month: today.month,
            currency: AppCurrency.inr,
            trendMonths: 6,
            asOf: today,
          )
          .first;

      expect(report.activeDebts, 3, reason: 'three records, three people');
      expect(report.openOwedToMeMinor, 450000);
      expect(report.newDebtMinor, 450000);
    });
  });

  group('the statement and the report', () {
    test('prints a person’s own records, each once', () async {
      final Person ahmed = await addPerson('أحمد');
      final Person ali = await addPerson('علي');
      await dinnerFor(withPeople: <Person>[ahmed, ali]);
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

      // Ahmed's statement is Ahmed's page in print: his own dinner record plus
      // his loan — 1,500 + 1,000. Ali's record is not his and is not printed.
      expect(data.totalMinor, 250000);
      expect(data.debts, hasLength(2));

      // The history table follows the same rule as the totals: the running
      // balance it ends on is the remaining figure printed at the top.
      final int lastBalance = data.entries.last.balanceAfterMinor;
      expect(lastBalance, data.remainingMinor);
    });
  });
}
