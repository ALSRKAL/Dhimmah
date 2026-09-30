import 'dart:io';

import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/mappers/db_mappers.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
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
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/domain/services/participant_rules.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// End-to-end behaviour through the real service and a real database.
///
/// These are the tests that match the acceptance criteria: create a person,
/// record both directions of a debt, take partial payments, settle, schedule a
/// recurring commitment, and check the numbers the user actually sees.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late DateTime clock;

  /// A fixed clock so "today" never moves mid-test.
  DateTime now() => clock;

  setUp(() async {
    db = AppDatabase.memory();
    clock = DateTime(2026, 9, 22, 10);

    final PersonRepositoryImpl people = PersonRepositoryImpl(db);
    final DebtRepositoryImpl debts = DebtRepositoryImpl(db);
    final PaymentRepositoryImpl payments = PaymentRepositoryImpl(db);
    final ObligationRepositoryImpl obligations = ObligationRepositoryImpl(db);
    final ReminderRepositoryImpl reminders = ReminderRepositoryImpl(db);
    final ActivityRepositoryImpl activity = ActivityRepositoryImpl(db);
    final SettingsRepositoryImpl settings = SettingsRepositoryImpl(db);

    queries = LedgerQueries(
      database: db,
      people: people,
      debts: debts,
      payments: payments,
      obligations: obligations,
      reminders: reminders,
      activity: activity,
    );

    service = LedgerService(
      database: db,
      people: people,
      debts: debts,
      payments: payments,
      obligations: obligations,
      reminders: reminders,
      activity: activity,
      settings: settings,
      notifications: NotificationService(),
      localizations: () => lookupAppLocalizations(const Locale('ar')),
      composer: () => NotificationComposer(
        localizations: lookupAppLocalizations(const Locale('ar')),
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: lookupAppLocalizations(const Locale('ar')),
        ),
      ),
      clock: now,
    );
  });

  tearDown(() async => db.close());

  Future<Person> addPerson(String name) =>
      service.createPerson(PersonDraft(name: name));

  Future<List<DebtView>> views({int window = 7}) async {
    final List<DebtView> out = <DebtView>[];
    await for (final List<DebtView> batch in queries.watchDebtViews(
      dueSoonWindowDays: window,
      asOf: dateOnly(clock),
    )) {
      out
        ..clear()
        ..addAll(batch);
      break;
    }
    return out;
  }

  group('creating records', () {
    test('a person is stored with its name', () async {
      final Person person = await addPerson('أحمد محمد');
      expect(person.name, 'أحمد محمد');
      expect(await db.peopleDao.getById(person.id), isNotNull);
    });

    test('a debt I owe is stored as negative towards the balance', () async {
      final Person person = await addPerson('خالد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 2000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 5),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );

      final List<DebtView> all = await views();
      expect(all, hasLength(1));
      expect(all.single.remainingMinor, 2000000);
      expect(all.single.signedRemaining.minorUnits, -2000000);
      expect(all.single.status, DebtLifecycleStatus.dueSoon);
      expect(all.single.person?.name, 'خالد');
    });

    test('a debt owed to me counts the other way', () async {
      final Person person = await addPerson('علي');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[person.id],
          principalMinor: 1500000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      final List<DebtView> all = await views();
      expect(all.single.signedRemaining.minorUnits, 1500000);
      expect(all.single.status, DebtLifecycleStatus.active);
    });
  });

  group('partial payments', () {
    test('reduce the balance and mark the record partially paid', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 5000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 10),
        ),
      );

      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: clock),
      );
      var all = await views();
      expect(all.single.paidMinor, 1000000);
      expect(all.single.remainingMinor, 4000000);
      expect(all.single.isPartiallyPaid, isTrue);
      expect(all.single.isSettled, isFalse);

      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1500000, paidAt: clock),
      );
      all = await views();
      expect(all.single.paidMinor, 2500000);
      expect(all.single.remainingMinor, 2500000);
      expect(all.single.paymentCount, 2);
    });

    test('settle the debt and stamp the closing moment', () async {
      final Person person = await addPerson('سالم');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 3000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 3),
        ),
      );

      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 3000000, paidAt: clock),
      );

      final List<DebtView> all = await views();
      expect(all.single.remainingMinor, 0);
      expect(all.single.status, DebtLifecycleStatus.paid);
      expect(all.single.debt.closedAt, isNotNull);
    });

    test('reopening a settled debt by deleting the payment', () async {
      final Person person = await addPerson('سالم');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 3000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 3000000, paidAt: clock),
      );
      expect((await views()).single.status, DebtLifecycleStatus.paid);

      await service.deletePayment(payment.id);

      final DebtView reopened = (await views()).single;
      expect(reopened.status, DebtLifecycleStatus.active);
      expect(reopened.remainingMinor, 3000000);
      expect(reopened.debt.closedAt, isNull);
    });

    test('an overpayment settles the debt without a negative balance', () async {
      final Person person = await addPerson('سالم');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1200000, paidAt: clock),
      );
      final DebtView view = (await views()).single;
      expect(view.remainingMinor, 0);
      expect(view.status, DebtLifecycleStatus.paid);
      expect(view.paidMinor, 1200000);
    });
  });

  group('recurring debts', () {
    test('create the next period once one is settled', () async {
      final Person person = await addPerson('المالك');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'إيجار',
          principalMinor: 2000000,
          currency: AppCurrency.inr,
          issuedAt: DateTime(2026, 9),
          dueAt: DateTime(2026, 9),
          recurrence: RecurrenceFrequency.monthly,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 2000000, paidAt: DateTime(2026, 9)),
      );

      final List<DebtView> all = await views();
      expect(all, hasLength(2));
      final DebtView follow = all.firstWhere((DebtView v) => v.isOpen);
      expect(follow.debt.dueAt, DateTime(2026, 10));
      expect(follow.remainingMinor, 2000000);
    });
  });

  // A debt can be paid off by a new payment, by a corrected payment, or by
  // lowering its amount to what was already paid. Only the first used to
  // announce the closing and create a recurring debt's next period, and it did
  // both again when a debt that was already closed received another payment.
  group('closing a debt, whichever write does it', () {
    Future<Debt> monthlyRent(Person person) => service.createDebt(
          DebtDraft(
            direction: DebtDirection.iOwe,
            personIds: <String>[person.id],
            title: 'إيجار',
            principalMinor: 2000000,
            currency: AppCurrency.inr,
            issuedAt: DateTime(2026, 9),
            dueAt: DateTime(2026, 9),
            recurrence: RecurrenceFrequency.monthly,
          ),
        );

    Future<int> closings() async => (await db.activityDao.getRecent(limit: 100))
        .where((ActivityEntryRow row) => row.type.name == 'debtClosed')
        .length;

    test('a corrected payment that pays it off creates the next period',
        () async {
      final Debt debt = await monthlyRent(await addPerson('المالك'));
      final Payment payment = await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1500000, paidAt: DateTime(2026, 9)),
      );
      expect(await views(), hasLength(1));

      await service.updatePayment(
        payment.id,
        PaymentDraft(amountMinor: 2000000, paidAt: DateTime(2026, 9)),
      );

      final List<DebtView> all = await views();
      expect(all, hasLength(2));
      expect(
        all.firstWhere((DebtView v) => v.isOpen).debt.dueAt,
        DateTime(2026, 10),
      );
      expect(await closings(), 1);
    });

    test('lowering the amount to what was paid closes it the same way',
        () async {
      final Person person = await addPerson('المالك');
      final Debt debt = await monthlyRent(person);
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1500000, paidAt: DateTime(2026, 9)),
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'إيجار',
          principalMinor: 1500000,
          currency: AppCurrency.inr,
          issuedAt: DateTime(2026, 9),
          dueAt: DateTime(2026, 9),
          recurrence: RecurrenceFrequency.monthly,
        ),
      );

      final List<DebtView> all = await views();
      expect(all, hasLength(2));
      expect(all.firstWhere((DebtView v) => v.debt.id == debt.id).isSettled,
          isTrue);
      expect(await closings(), 1);
    });

    test('paying a debt that is already closed does not announce it again',
        () async {
      final Person person = await addPerson('سالم');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: clock),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 100000, paidAt: clock),
      );

      expect(await closings(), 1);
      expect((await views()).single.isSettled, isTrue);
    });

    test('a refused payment leaves nothing behind', () async {
      final Person person = await addPerson('سالم');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.deleteDebt(debt.id);

      await expectLater(
        () => service.recordPayment(
          debt.id,
          PaymentDraft(amountMinor: 1000, paidAt: clock),
        ),
        throwsStateError,
      );
      expect(await db.debtsDao.getAllPayments(), isEmpty);
    });
  });

  group('obligations', () {
    test('materialise their periods and pay one forward', () async {
      final Obligation obligation = await service.createObligation(
        ObligationDraft(
          name: 'إيجار المنزل',
          category: ObligationCategory.housing,
          amountMinor: 2000000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(2026, 9),
          dayOfMonth: 1,
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );

      var instances = await _instances(queries, dateOnly(clock));
      expect(instances, isNotEmpty);
      final ObligationInstance due = instances.first;
      expect(due.occurrence.dueAt, DateTime(2026, 9));
      expect(due.occurrence.status, ObligationStatus.overdue);

      await service.markObligationPaid(due);

      instances = await _instances(queries, dateOnly(clock));
      final ObligationOccurrence paid = instances
          .firstWhere((ObligationInstance i) => i.occurrence.dueAt == DateTime(2026, 9))
          .occurrence;
      expect(paid.status, ObligationStatus.paid);
      expect(paid.paymentId, isNotNull);

      // The obligation itself has rolled on to the next period.
      final Obligation? reloaded = await db.obligationsDao
          .getById(obligation.id)
          .then((ObligationRow? row) => row?.toEntity());
      expect(reloaded!.nextDueAt, DateTime(2026, 10));
    });

    test('a skipped period stops being payable', () async {
      await service.createObligation(
        ObligationDraft(
          name: 'اشتراك',
          category: ObligationCategory.subscription,
          amountMinor: 50000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(2026, 9),
        ),
      );
      final ObligationInstance due =
          (await _instances(queries, dateOnly(clock))).first;
      await service.skipObligationPeriod(due);
      final ObligationInstance after =
          (await _instances(queries, dateOnly(clock)))
              .firstWhere((ObligationInstance i) => i.id == due.id);
      expect(after.occurrence.status, ObligationStatus.skipped);
      expect(after.occurrence.isPayable, isFalse);
    });
  });

  group('dashboard', () {
    test('separates the two directions and keeps currencies apart', () async {
      final Person person = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 3),
        ),
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[person.id],
          principalMinor: 2500000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 2),
        ),
      );
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 100000,
          currency: AppCurrency.usd,
          issuedAt: clock,
        ),
      );

      final DashboardSnapshot snapshot = await queries
          .watchDashboard(
            dueSoonWindowDays: 7,
            defaultCurrency: AppCurrency.inr,
            asOf: dateOnly(clock),
          )
          .first;

      expect(snapshot.totalsByCurrency, hasLength(2));
      final CurrencyTotals inr = snapshot.totalsByCurrency
          .firstWhere((CurrencyTotals t) => t.currency == AppCurrency.inr);
      expect(inr.iOweMinor, 1000000);
      expect(inr.owedToMeMinor, 2500000);
      expect(inr.net.minorUnits, 1500000);
      expect(inr.dueSoonMinor, 3500000);

      final CurrencyTotals usd = snapshot.totalsByCurrency
          .firstWhere((CurrencyTotals t) => t.currency == AppCurrency.usd);
      expect(usd.iOweMinor, 100000);
      expect(usd.owedToMeMinor, 0);

      expect(snapshot.hasAnyRecord, isTrue);
      expect(snapshot.peopleCount, 1);
    });

    test('reports an empty state on a fresh install', () async {
      final DashboardSnapshot snapshot = await queries
          .watchDashboard(
            dueSoonWindowDays: 7,
            defaultCurrency: AppCurrency.inr,
            asOf: dateOnly(clock),
          )
          .first;
      expect(snapshot.hasAnyRecord, isFalse);
      expect(snapshot.totalsByCurrency, isEmpty);
      expect(snapshot.upcoming, isEmpty);
    });
  });

  group('activity feed', () {
    test('records each meaningful change', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: clock),
      );

      final entries = await db.activityDao.getRecent(limit: 20);
      final List<String> types =
          entries.map((ActivityEntryRow row) => row.type.name).toList();
      expect(types, contains('personCreated'));
      expect(types, contains('debtCreated'));
      expect(types, contains('paymentRecorded'));
      expect(types, contains('debtClosed'));
    });
  });

  group('undo', () {
    test('restores a deleted debt with its payment history intact', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 5000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: clock),
      );

      final LedgerServiceSnapshot snapshot =
          await service.deleteDebtWithSnapshot(debt.id);
      expect(await views(), isEmpty);

      await service.restoreDeleted(snapshot);

      final DebtView restored = (await views()).single;
      expect(restored.debt.id, debt.id);
      expect(restored.paidMinor, 1000000);
      expect(restored.remainingMinor, 4000000);
    });
  });

  group('the monthly report', () {
    test('counts only genuinely late money as overdue', () async {
      final Person person = await addPerson('أحمد');
      // Late: due four days ago.
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 3500000,
          currency: AppCurrency.inr,
          issuedAt: addDays(clock, -30),
          dueAt: addDays(clock, -4),
        ),
      );
      // Not late: due in three days, still inside the same month.
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1500000,
          currency: AppCurrency.inr,
          issuedAt: addDays(clock, -10),
          dueAt: addDays(clock, 3),
        ),
      );

      final MonthlyReport report = await queries
          .watchMonthlyReport(
            year: clock.year,
            month: clock.month,
            currency: AppCurrency.inr,
            trendMonths: 6,
            asOf: dateOnly(clock),
          )
          .first;

      // The dashboard calls 35,000 late; the report has to agree.
      expect(report.overdueMinor, 3500000);
      expect(report.openIOweMinor, 5000000);
      expect(report.activeDebts, 2);
    });
  });

  group('across a restart', () {
    test('an edited record and its participants are on disk', () async {
      // A real file, closed and reopened: everything the app keeps in memory
      // between a write and a read is gone, so this reads what was written.
      final Directory temp =
          await Directory.systemTemp.createTemp('dhimmah-restart');
      addTearDown(() => temp.delete(recursive: true));
      final File file = File('${temp.path}/dhimmah.sqlite');

      final AppDatabase first = AppDatabase(NativeDatabase(file));
      final LedgerService firstService = buildService(first);
      final Person ahmed = await firstService.createPerson(
        const PersonDraft(name: 'أحمد'),
      );
      final Person ali = await firstService.createPerson(
        const PersonDraft(name: 'علي'),
      );
      final Debt debt = await firstService.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[ahmed.id],
          title: 'قرض',
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await firstService.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 250000, paidAt: clock),
      );
      await firstService.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[ahmed.id, ali.id],
          title: 'قرض معدل',
          principalMinor: 1200000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await first.close();

      final AppDatabase second = AppDatabase(NativeDatabase(file));
      addTearDown(second.close);
      final PersonRepositoryImpl people = PersonRepositoryImpl(second);
      final DebtRepositoryImpl debts = DebtRepositoryImpl(second);
      final PaymentRepositoryImpl payments = PaymentRepositoryImpl(second);

      final Debt reloaded = (await debts.getById(debt.id))!;
      expect(reloaded.id, debt.id);
      expect(reloaded.title, 'قرض معدل');
      expect(reloaded.principalMinor, 1200000);
      expect(reloaded.direction, DebtDirection.owedToMe);
      expect(reloaded.personIds, <String>[ahmed.id, ali.id]);
      expect(await payments.forDebt(debt.id), hasLength(1));
      expect(await debts.getAll(), hasLength(1));
      expect((await people.getAll()), hasLength(2));
    });
  });

  group('clearing a field', () {
    // A regression guard. Drift's upsert and `update().write(row)` both skip
    // columns whose new value is null, so clearing a field used to appear to work
    // and then quietly revert on the next read.
    test('removes a due date when the user clears it', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 10),
        ),
      );
      expect(debt.dueAt, isNotNull);

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );

      final DebtView reloaded = (await views()).single;
      expect(reloaded.debt.dueAt, isNull);
      expect(reloaded.status, DebtLifecycleStatus.active);
    });

    test('clears a note, and refuses a save that names nobody', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          note: 'ملاحظة',
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );

      await service.updateDebt(
        debt.id,
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );

      final DebtView reloaded = (await views()).single;
      expect(reloaded.debt.note, isNull);
      expect(reloaded.debt.personIds, <String>[person.id]);

      // A record that names nobody is refused at the service, and the refusal
      // leaves the stored record exactly as it was: the rule is enforced on the
      // way in, not repaired afterwards.
      await expectLater(
        () => service.updateDebt(
          debt.id,
          DebtDraft(
            direction: DebtDirection.iOwe,
            principalMinor: 2000000,
            currency: AppCurrency.inr,
            issuedAt: clock,
          ),
        ),
        throwsA(isA<MissingParticipantsException>()),
      );
      expect((await views()).single.debt.personIds, <String>[person.id]);
      expect((await views()).single.debt.principalMinor, 1000000);
    });

    test('restores a debt when it is unarchived', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.setDebtArchived(debt.id, true);
      expect((await db.debtsDao.getById(debt.id))!.archivedAt, isNotNull);

      await service.setDebtArchived(debt.id, false);
      expect((await db.debtsDao.getById(debt.id))!.archivedAt, isNull);
      expect(
        (await views()).single.status,
        DebtLifecycleStatus.active,
      );
    });

    test('removes a phone number and note from a person', () async {
      final Person person = await addPerson('أحمد');
      await service.updatePerson(
        person.id,
        PersonDraft(name: 'أحمد', phone: '0770000000', note: 'صديق'),
      );
      expect((await db.peopleDao.getById(person.id))!.phone, isNotNull);

      await service.updatePerson(person.id, const PersonDraft(name: 'أحمد'));
      final PersonRow? reloaded = await db.peopleDao.getById(person.id);
      expect(reloaded!.phone, isNull);
      expect(reloaded.note, isNull);
    });
  });

  group('deleting a person', () {
    test('keeps their debts but unlinks them', () async {
      final Person person = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );
      await service.deletePerson(person.id);

      final List<DebtView> all = await views();
      expect(all, hasLength(1), reason: 'the money is still owed');
      expect(all.single.debt.personId, isNull);
    });
  });

  group('clearing all data', () {
    test('empties every table but keeps settings', () async {
      final Person person = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
        ),
      );

      await service.clearAllData();

      expect(await views(), isEmpty);
      final Setting? row = await db.settingsDao.get();
      expect(row, isNotNull);
      expect(row!.onboardingCompleted, isFalse);
    });
  });

  group('notification planning', () {
    test('schedules a reminder for each lead time on an open debt', () async {
      final Person person = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 10),
          reminderLeads: const <ReminderLead>[
            ReminderLead.oneDayBefore,
            ReminderLead.threeDaysBefore,
          ],
        ),
      );

      final List<NotificationIntent> intents = NotificationPlanner.plan(
        debts: await views(),
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: _settings(),
        now: clock,
      );

      // Two lead times, plus the single nudge that fires after the deadline.
      final List<NotificationIntent> leadReminders = intents
          .where((NotificationIntent i) =>
              i.kind == NotificationKind.debtDueSoon ||
              i.kind == NotificationKind.debtDueToday)
          .toList();
      expect(leadReminders, hasLength(2));
      // Furthest out first, each at the configured notification time.
      expect(leadReminders.first.when, DateTime(2026, 9, 29, 20));
      expect(leadReminders.last.when, DateTime(2026, 10, 1, 20));

      final List<NotificationIntent> nudges = intents
          .where((NotificationIntent i) => i.kind == NotificationKind.debtOverdue)
          .toList();
      expect(nudges, hasLength(1));
      expect(nudges.single.when, DateTime(2026, 10, 4, 20));
    });

    test('schedules nothing when reminders are switched off', () async {
      final Person person = await addPerson('أحمد');
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 1),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );
      final List<NotificationIntent> intents = NotificationPlanner.plan(
        debts: await views(),
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: _settings(notifications: false),
        now: clock,
      );
      expect(intents, isEmpty);
    });

    test('a settled debt produces no reminders', () async {
      final Person person = await addPerson('أحمد');
      final Debt debt = await service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          principalMinor: 1000000,
          currency: AppCurrency.inr,
          issuedAt: clock,
          dueAt: addDays(clock, 5),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );
      await service.recordPayment(
        debt.id,
        PaymentDraft(amountMinor: 1000000, paidAt: clock),
      );

      final List<NotificationIntent> intents = NotificationPlanner.plan(
        debts: await views(),
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: _settings(),
        now: clock,
      );
      expect(
        intents.where((NotificationIntent i) => i.kind != NotificationKind.monthEndSummary),
        isEmpty,
      );
    });

    test('the month-end summary lands on the last day of the month', () async {
      final List<NotificationIntent> intents = NotificationPlanner.plan(
        debts: const <DebtView>[],
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: _settings(),
        now: clock,
      );
      final NotificationIntent summary = intents.singleWhere(
        (NotificationIntent i) => i.kind == NotificationKind.monthEndSummary,
      );
      // September has 30 days.
      expect(summary.when, DateTime(2026, 9, 30, 20));
    });

    test('a fixed month-end day clamps to a short month', () {
      expect(
        NotificationPlanner.monthEndMoment(
          2026,
          2,
          _settings(monthEndDay: MonthEndDay.day31),
        ),
        DateTime(2026, 2, 28, 20),
      );
    });
  });
}

Future<List<ObligationInstance>> _instances(
  LedgerQueries queries,
  DateTime asOf,
) async {
  await for (final List<ObligationInstance> batch
      in queries.watchObligationInstances(asOf: asOf)) {
    return batch;
  }
  return const <ObligationInstance>[];
}

/// Settings for a test, with sensible defaults and one place to override.
AppSettings _settings({
  bool notifications = true,
  MonthEndDay monthEndDay = MonthEndDay.lastDay,
}) {
  return AppSettings.initial.copyWith(
    notificationsEnabled: notifications,
    monthEndDay: monthEndDay,
    defaultCurrency: AppCurrency.inr,
  );
}
