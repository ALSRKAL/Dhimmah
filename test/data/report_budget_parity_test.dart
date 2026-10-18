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
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/monthly_budget.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One month, two screens, one number.
///
/// The obligations screen's budget card and the reports screen both state what
/// the month's commitments come to, and they compute it in different places: the
/// card reads the periods inside the month's window straight out of the database,
/// the report walks every period the ledger holds and filters them in memory.
/// Two implementations of "which periods belong to this month" is exactly how
/// two screens end up disagreeing about one month — so this file drives the same
/// ledger through every state those periods can be in and asserts the two
/// figures stay equal, with the arithmetic stated outright so an agreement on
/// the wrong number cannot pass.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late DateTime now;

  setUp(() {
    db = AppDatabase.memory();
    now = DateTime(2026, 9, 15, 10); // a Tuesday
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

  final DateTime today = dateOnly(DateTime(2026, 9, 15));

  Future<MonthlyBudget> budget({
    int? year,
    int? month,
    AppCurrency currency = AppCurrency.inr,
  }) =>
      queries
          .watchMonthlyBudget(
            year: year ?? 2026,
            month: month ?? 9,
            currency: currency,
          )
          .first;

  Future<MonthlyReport> report({
    int? year,
    int? month,
    AppCurrency currency = AppCurrency.inr,
  }) =>
      queries
          .watchMonthlyReport(
            year: year ?? 2026,
            month: month ?? 9,
            currency: currency,
            trendMonths: 3,
            asOf: today,
          )
          .first;

  /// The check that matters: the same month, the same currency, one figure.
  Future<void> expectParity(
    String step, {
    int? year,
    int? month,
    AppCurrency currency = AppCurrency.inr,
    int? expectedMinor,
  }) async {
    final MonthlyBudget card =
        await budget(year: year, month: month, currency: currency);
    final MonthlyReport page =
        await report(year: year, month: month, currency: currency);
    expect(
      card.obligationsMinor,
      page.obligationsMinor,
      reason: '$step: the budget card and the report disagree',
    );
    if (expectedMinor != null) {
      expect(
        card.obligationsMinor,
        expectedMinor,
        reason: '$step: and both are wrong',
      );
    }
  }

  Future<Obligation> monthly({
    required String name,
    required int amountMinor,
    AppCurrency currency = AppCurrency.inr,
  }) =>
      service.createObligation(
        ObligationDraft(
          name: name,
          category: ObligationCategory.other,
          amountMinor: amountMinor,
          currency: currency,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(2026, 7, 15),
          dayOfMonth: 15,
        ),
      );

  /// Every period of the month, as the obligations screen lists them.
  Future<List<ObligationInstance>> periodsIn(
    int year,
    int month,
  ) async {
    final List<ObligationInstance> all =
        await queries.watchObligationInstances(asOf: today).first;
    return all
        .where((ObligationInstance i) =>
            i.occurrence.dueAt.year == year &&
            i.occurrence.dueAt.month == month)
        .toList();
  }

  /// One named period, so a test says which day it acts on rather than "the
  /// first one that happens to be in a state".
  Future<ObligationInstance> periodOn(DateTime due) async {
    final List<ObligationInstance> all =
        await queries.watchObligationInstances(asOf: today).first;
    return all.firstWhere(
      (ObligationInstance i) => isSameDate(i.occurrence.dueAt, due),
    );
  }

  test('the two figures agree in every state a period can be in', () async {
    await monthly(name: 'إيجار', amountMinor: 120000);
    // A weekly one, anchored on the Monday of this week: 14 September 2026.
    await service.createObligation(
      ObligationDraft(
        name: 'بقالة',
        category: ObligationCategory.other,
        amountMinor: 20000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.weekly,
        startAt: startOfWeek(today),
      ),
    );
    await service.ensureOccurrences();

    // The arithmetic, stated rather than re-derived: the monthly's 15th
    // (120,000) plus the Mondays the weekly commitment actually has — the 14th,
    // its first, then the 21st and the 28th, and none in August because a
    // commitment has no periods before it starts.
    final DateTime firstMonday = startOfWeek(today);
    final DateTime secondMonday = addDays(firstMonday, 7);
    await expectParity('two commitments, nothing done yet',
        expectedMinor: 120000 + 3 * 20000);

    final List<ObligationInstance> september = await periodsIn(2026, 9);
    expect(september, hasLength(4), reason: 'one monthly and three Mondays');

    // Paying does not remove a commitment from the month: the card says what
    // the month costs, and how much of it is paid is a second figure.
    await service.markObligationPaid(await periodOn(firstMonday));
    await expectParity('one period paid', expectedMinor: 120000 + 3 * 20000);
    expect((await budget()).paidObligationsMinor, 20000);

    // A skipped period is not money the month costs.
    await service.ensureOccurrences();
    await service.skipObligationPeriod(await periodOn(secondMonday));
    await expectParity('one period skipped', expectedMinor: 120000 + 2 * 20000);

    // An archived commitment stops asking for money from the day it was put
    // aside — the periods still ahead of it go, the ones behind it stay, and a
    // period that was already paid stays whatever the archive says.
    final Obligation weekly = (await service.obligations.getAll())
        .firstWhere((Obligation obligation) =>
            obligation.frequency == RecurrenceFrequency.weekly);
    await service.setObligationArchived(weekly.id, true);
    await expectParity('the weekly commitment archived',
        expectedMinor: 120000 + 20000);

    // An edited amount is the same fact on both screens — and this month's
    // figure does *not* move, because the rent's period for the 15th has already
    // arrived. A period that has arrived keeps the amount it arrived with,
    // whether or not it was paid: it is the bill, and rewriting it behind the
    // user would change what a month that has already happened cost.
    final Obligation rent = (await service.obligations.getAll())
        .firstWhere((Obligation obligation) => obligation.name == 'إيجار');
    await service.updateObligation(
      rent.id,
      ObligationDraft(
        name: rent.name,
        category: rent.category,
        amountMinor: 150000,
        currency: rent.currency,
        frequency: rent.frequency,
        startAt: rent.startAt,
        dayOfMonth: rent.dayOfMonth,
      ),
    );
    await service.ensureOccurrences();
    await expectParity('the amount edited', expectedMinor: 120000 + 20000);

    // Next month's period had not arrived, so it took the new amount — the other
    // half of the same rule, and the reason this is a decision rather than an
    // omission. The weekly commitment was archived, so its October Mondays are
    // not asked for.
    await expectParity('next month takes the new amount', month: 10,
        expectedMinor: 150000);

    // A month that has already ended, where the archive rule reads backwards.
    await expectParity('a past month', month: 8);
    await expectParity('a month before the commitments began', month: 6,
        expectedMinor: 0);

    // Another currency is another set of commitments, and no card may fold one
    // into the other.
    await monthly(
      name: 'دولارات',
      amountMinor: 50000,
      currency: AppCurrency.usd,
    );
    await service.ensureOccurrences();
    await expectParity('a commitment in another currency',
        expectedMinor: 120000 + 20000);
    await expectParity(
      'and that currency on its own',
      currency: AppCurrency.usd,
      expectedMinor: 50000,
    );
  });

  test('the two figures agree across the whole horizon, month by month',
      () async {
    await monthly(name: 'إيجار', amountMinor: 120000);
    await service.createObligation(
      ObligationDraft(
        name: 'بقالة',
        category: ObligationCategory.other,
        amountMinor: 20000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.weekly,
        startAt: startOfWeek(today),
      ),
    );
    await service.createObligation(
      ObligationDraft(
        name: 'تأمين',
        category: ObligationCategory.other,
        amountMinor: 300000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.yearly,
        startAt: DateTime(2025, 11, 30),
      ),
    );
    await service.ensureOccurrences();

    // Three months back and three forward, so the year boundary and February
    // are inside the walk.
    for (int offset = -3; offset <= 3; offset++) {
      final DateTime cursor = addMonths(DateTime(2026, 9), offset);
      await expectParity(
        '${cursor.year}-${cursor.month}',
        year: cursor.year,
        month: cursor.month,
      );
    }
  });
}
