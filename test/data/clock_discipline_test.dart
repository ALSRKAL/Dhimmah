import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
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
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/entities/monthly_budget.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One clock, everywhere the ledger writes a moment.
///
/// The service is handed a clock rather than reading the wall itself, which is
/// what lets a test say what "now" is and then check what was written. That only
/// holds if *every* write goes through it: an archive stamp taken from
/// `DateTime.now()` inside a repository instead of from the injected clock made
/// one operation write two different moments, and left the day a record was
/// archived disagreeing with the day it was last updated.
///
/// The stamp is not decoration. `ObligationPeriodRule` reads it to decide which
/// unpaid periods still count towards a month, so a stamp taken from another
/// clock is a month's total decided by a clock the caller never chose.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late DateTime now;

  setUp(() async {
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

  void expectSameMoment(DateTime? written, String what) {
    expect(written, isNotNull, reason: '$what was archived without a stamp');
    expect(
      written!.millisecondsSinceEpoch,
      now.millisecondsSinceEpoch,
      reason: '$what carries the injected clock, not the wall clock',
    );
  }

  Future<Obligation> commitAt(DateTime firstDue) => service.createObligation(
        ObligationDraft(
          name: 'إيجار',
          category: ObligationCategory.housing,
          amountMinor: 200000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: firstDue,
          dayOfMonth: firstDue.day,
        ),
      );

  test('every archive stamp is the injected clock, not the wall clock',
      () async {
    // The wall clock is a different moment here by construction: `now` is fixed
    // in the past, so a stamp that came from `DateTime.now()` cannot match it.
    expect(
      DateTime.now().millisecondsSinceEpoch,
      isNot(now.millisecondsSinceEpoch),
      reason: 'the test proves nothing if the two clocks agree',
    );

    final Person person = await service.createPerson(
      const PersonDraft(name: 'أحمد'),
    );
    await service.setPersonArchived(person.id, archived: true);
    expectSameMoment(
      (await service.people.getById(person.id))!.archivedAt,
      'a person',
    );

    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[person.id],
        title: 'قرض',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: dateOnly(now),
      ),
    );
    await service.setDebtArchived(debt.id, true);
    expectSameMoment(
      (await service.debts.getById(debt.id))!.archivedAt,
      'a debt',
    );

    final Obligation obligation = await commitAt(DateTime(now.year, now.month));
    await service.setObligationArchived(obligation.id, true);
    expectSameMoment(
      (await service.obligations.getById(obligation.id))!.archivedAt,
      'a commitment',
    );

    await service.createIncome(
      IncomeDraft(
        name: 'الراتب',
        amountMinor: 300000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(now.year, now.month),
        dayOfMonth: 1,
      ),
    );
    final Income income = (await service.incomes.getAll()).single;
    await service.setIncomeArchived(income.id, true);
    expectSameMoment(
      (await service.incomes.getAll()).single.archivedAt,
      'an income',
    );
  });

  test('restoring clears the stamp rather than re-stamping it', () async {
    final Obligation obligation = await commitAt(DateTime(now.year, now.month));
    await service.setObligationArchived(obligation.id, true);
    await service.setObligationArchived(obligation.id, false);
    expect(
      (await service.obligations.getById(obligation.id))!.archivedAt,
      isNull,
    );
  });

  test('the month a commitment was archived in is decided by that same clock',
      () async {
    // An unpaid period *after* the moment it was set aside: the day the record
    // was archived is what decides it, and the verdict must not depend on the
    // day the test happens to run.
    final DateTime nextMonth = DateTime(now.year, now.month + 1);
    final Obligation rent = await commitAt(
      DateTime(nextMonth.year, nextMonth.month, 25),
    );
    Future<MonthlyBudget> month() => queries
        .watchMonthlyBudget(
          year: nextMonth.year,
          month: nextMonth.month,
          currency: AppCurrency.inr,
          asOf: dateOnly(now),
        )
        .first;

    expect((await month()).obligationsMinor, 200000);

    await service.setObligationArchived(rent.id, true);
    expect(
      (await month()).obligationsMinor,
      0,
      reason: 'archived on 2026-09-15, so the 2026-10-25 period is not owed',
    );

    await service.setObligationArchived(rent.id, false);
    expect((await month()).obligationsMinor, 200000);
  });
}
