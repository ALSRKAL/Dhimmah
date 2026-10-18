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
import 'package:dhimmah/domain/entities/activity_entry.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/entities/monthly_budget.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/enums/activity_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/amount_rules.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// The month's income against the month's commitments.
///
/// Every assertion here is about one of two things: that the figures are
/// *derived* — so an edit anywhere moves them — and that they are not added
/// across currencies, because 5,000 ﷼ and $500 are not five hundred of
/// anything.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;

  /// A fixed clock, so "this month" is a fact rather than a race.
  ///
  /// The 15th, so the month has a clear middle: a period on the 1st is behind
  /// us and one on the 25th is ahead, which is what makes paid/unpaid readable.
  final DateTime now = DateTime(2026, 9, 15, 10);
  final DateTime today = dateOnly(now);

  setUp(() async {
    db = AppDatabase.memory();
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

  Future<MonthlyBudget> budget({
    int? year,
    int? month,
    AppCurrency currency = AppCurrency.inr,
  }) {
    return queries
        .watchMonthlyBudget(
          year: year ?? now.year,
          month: month ?? now.month,
          currency: currency,
        )
        .first;
  }

  /// A commitment that falls inside the test month.
  Future<Obligation> obligation({
    required String name,
    required int amountMinor,
    required int day,
    AppCurrency currency = AppCurrency.inr,
    RecurrenceFrequency frequency = RecurrenceFrequency.monthly,
  }) {
    return service.createObligation(
      ObligationDraft(
        name: name,
        category: ObligationCategory.housing,
        amountMinor: amountMinor,
        currency: currency,
        frequency: frequency,
        startAt: DateTime(now.year, now.month, day),
        dayOfMonth: frequency == RecurrenceFrequency.weekly ? null : day,
      ),
    );
  }

  Future<void> payFirstPeriod(String obligationName) async {
    await service.ensureOccurrences();
    final List<Obligation> all = await service.obligations.getAll();
    final Obligation target =
        all.firstWhere((Obligation o) => o.name == obligationName);
    final List<ObligationOccurrence> periods =
        await service.obligations.occurrencesFor(target.id);
    final ObligationOccurrence first = periods.firstWhere(
      (ObligationOccurrence p) => p.periodKey == monthKey(today),
      orElse: () => periods.first,
    );
    await service.markObligationPaid(
      ObligationInstance(obligation: target, occurrence: first),
    );
  }

  group('income', () {
    test('a monthly salary counts once in its own month', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );

      final MonthlyBudget thisMonth = await budget();
      expect(thisMonth.incomeMinor, 400000);
      expect(thisMonth.incomeCount, 1);

      // The month before the start date has nothing in it — a schedule that has
      // not begun is not income.
      final MonthlyBudget before = await budget(month: now.month - 1);
      expect(before.incomeMinor, 0);
    });

    test('an income that has not started yet counts for nothing', () async {
      // The salary is recorded now but begins next month — a raise starting in
      // November, entered in September so it is not forgotten. It must not pay
      // into a month it has not reached, and it must pay into its own month.
      final DateTime nextMonth = DateTime(now.year, now.month + 1);
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب الجديد',
          amountMinor: 500000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(nextMonth.year, nextMonth.month),
          dayOfMonth: 25,
        ),
      );

      expect((await budget()).incomeMinor, 0,
          reason: 'this month is before the schedule begins');
      expect(
        (await budget(year: nextMonth.year, month: nextMonth.month)).incomeMinor,
        500000,
        reason: 'and its own month carries it',
      );
    });

    test('the day the user chose decides the month, not the day it was typed',
        () async {
      // A salary that lands on the 5th but was only entered on the 20th. The
      // schedule is the start *month* on the chosen day, so September carries
      // its own 5th — the alternative would silently shift the salary to the
      // 20th for as long as nobody looked. Pinned because it is the boundary
      // where "the day it lands on" and "the day it started" disagree, and the
      // figure a month shows depends on which one wins.
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month, 20),
          dayOfMonth: 5,
        ),
      );

      expect((await budget()).incomeMinor, 400000,
          reason: 'the start month counts, on the chosen day');
      expect((await budget(month: now.month - 1)).incomeMinor, 0);
    });

    test('two sources add up, and an archived one stops counting', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );
      final second = await service.createIncome(
        IncomeDraft(
          name: 'عمل حر',
          amountMinor: 60000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month, 10),
          dayOfMonth: 10,
        ),
      );
      expect((await budget()).incomeMinor, 460000);

      await service.setIncomeArchived(second.id, true);
      expect(
        (await budget()).incomeMinor,
        400000,
        reason: 'an income set aside is not income this month',
      );

      await service.setIncomeArchived(second.id, false);
      expect((await budget()).incomeMinor, 460000,
          reason: 'and restoring it brings it back');
    });

    test('the largest incomes add up without wrapping', () async {
      // The card adds its sources itself, so the ceiling is where the sum could
      // stop being a sum: 64-bit arithmetic wraps round into a small, plausible
      // number rather than failing, and a wrong balance that still looks like a
      // balance is the one kind of defect a ledger cannot show its user.
      //
      // Weekly, starting on a Monday in June 2026, so each source is multiplied
      // by the five Mondays that month has on the way in.
      for (final String name in <String>['الأول', 'الثاني']) {
        await service.createIncome(
          IncomeDraft(
            name: name,
            amountMinor: AmountRules.maxMinor,
            currency: AppCurrency.inr,
            frequency: RecurrenceFrequency.weekly,
            startAt: DateTime(2026, 6),
          ),
        );
      }

      final MonthlyBudget june = await queries
          .watchMonthlyBudget(year: 2026, month: 6, currency: AppCurrency.inr)
          .first;
      expect(june.incomeCount, 2);
      expect(june.incomeMinor, 10 * AmountRules.maxMinor);
      expect(june.incomeMinor, greaterThan(0), reason: 'a wrap shows as this');
    });

    test('a monthly income every N months counts only in its own months',
        () async {
      final DateTime january = DateTime(2026, 1, 15);
      await service.createIncome(
        IncomeDraft(
          name: 'كل ثلاثة أشهر',
          amountMinor: 90000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          intervalCount: 3,
          startAt: january,
          dayOfMonth: 15,
        ),
      );

      // Anchored in January, so it lands in January, April, July, October — and
      // never in the months between. This is the property the anchor exists for.
      expect((await budget(year: 2026, month: 1)).incomeMinor, 90000);
      expect((await budget(year: 2026, month: 2)).incomeMinor, 0);
      expect((await budget(year: 2026, month: 3)).incomeMinor, 0);
      expect((await budget(year: 2026, month: 4)).incomeMinor, 90000);
      expect((await budget(year: 2026, month: 7)).incomeMinor, 90000);
    });

    test('a yearly income counts in its own month only', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'علاوة سنوية',
          amountMinor: 500000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.yearly,
          startAt: DateTime(2026, 3, 20),
          dayOfMonth: 20,
        ),
      );
      expect((await budget(year: 2026, month: 3)).incomeMinor, 500000);
      expect((await budget(year: 2026, month: 4)).incomeMinor, 0);
      expect((await budget(year: 2027, month: 3)).incomeMinor, 500000);
    });

    test('a weekly income counts the weeks that land in the month', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'أسبوعي',
          amountMinor: 10000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.weekly,
          // A Thursday, so the weeks are easy to count: September 2026 has
          // Thursdays on the 3rd, 10th, 17th and 24th.
          startAt: DateTime(2026, 9, 3),
        ),
      );
      // September 2026 has Thursdays on the 3rd, 10th, 17th and 24th; October
      // has the 1st, 8th, 15th, 22nd and 29th. A five-week month is worth more,
      // which is true, and is shown rather than smoothed into an average.
      expect((await budget(year: 2026, month: 9)).incomeMinor, 40000,
          reason: 'four Thursdays in September 2026');
      expect((await budget(year: 2026, month: 10)).incomeMinor, 50000,
          reason: 'five Thursdays in October 2026');
    });

    test('a one-off income counts in its own month and never again', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'مكافأة',
          amountMinor: 150000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.none,
          startAt: DateTime(2026, 9, 5),
        ),
      );
      expect((await budget(year: 2026, month: 9)).incomeMinor, 150000);
      expect((await budget(year: 2026, month: 10)).incomeMinor, 0);
      expect((await budget(year: 2027, month: 9)).incomeMinor, 0,
          reason: 'a bonus does not repeat for ever');
    });
  });

  group('commitments', () {
    test('a month with no commitment in it reports none', () async {
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      final MonthlyBudget nextMonth = await budget(month: now.month + 1);
      expect(nextMonth.obligationsMinor, 200000,
          reason: 'a monthly commitment recurs into the next month');
      expect(nextMonth.paidObligationsMinor, 0);
      expect(nextMonth.unpaidObligationsMinor, 200000);
    });

    test('paying part of the month splits paid from unpaid', () async {
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      await obligation(name: 'إنترنت', amountMinor: 50000, day: 5);
      await payFirstPeriod('إيجار');

      final MonthlyBudget month = await budget();
      expect(month.obligationsMinor, 250000);
      expect(month.paidObligationsMinor, 200000);
      expect(month.unpaidObligationsMinor, 50000);
    });

    test('skipping a period takes it out of the month entirely', () async {
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      final MonthlyBudget before = await budget();
      expect(before.obligationsMinor, 200000);

      await service.ensureOccurrences();
      final Obligation target =
          (await service.obligations.getAll()).single;
      final ObligationOccurrence period =
          (await service.obligations.occurrencesFor(target.id)).first;
      await service.skipObligationPeriod(
        ObligationInstance(obligation: target, occurrence: period),
      );

      expect((await budget()).obligationsMinor, 0,
          reason: 'a skipped period is "not applicable this time"');
    });

    test('a commitment in another currency is never added in', () async {
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      await obligation(
        name: 'إيجار بالدولار',
        amountMinor: 50000,
        day: 1,
        currency: AppCurrency.usd,
      );

      expect((await budget()).obligationsMinor, 200000);
      expect(
        (await budget(currency: AppCurrency.usd)).obligationsMinor,
        50000,
      );
    });

    test('an archived commitment stops counting from the day it was archived',
        () async {
      // The archive stamp comes from the same injected clock as everything else
      // the service writes, so the month this scenario names is the month it
      // reads: a period after `now` on the calendar, and after the archive
      // moment by construction.
      final DateTime nextMonth = DateTime(now.year, now.month + 1);

      final Obligation rent = await service.createObligation(
        ObligationDraft(
          name: 'إيجار',
          category: ObligationCategory.housing,
          amountMinor: 200000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(nextMonth.year, nextMonth.month, 25),
          dayOfMonth: 25,
        ),
      );
      Future<MonthlyBudget> nextMonthBudget() =>
          budget(year: nextMonth.year, month: nextMonth.month);

      expect((await nextMonthBudget()).obligationsMinor, 200000);

      await service.setObligationArchived(rent.id, true);
      expect((await nextMonthBudget()).obligationsMinor, 0,
          reason: 'a commitment set aside no longer owes its unpaid periods');

      await service.setObligationArchived(rent.id, false);
      expect((await nextMonthBudget()).obligationsMinor, 200000,
          reason: 'and restoring it owes them again');
    });
  });

  group('the summary', () {
    test('remaining is income minus commitments, and goes negative', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 300000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      expect((await budget()).remainingMinor, 100000);

      await obligation(name: 'أقساط', amountMinor: 250000, day: 10);
      final MonthlyBudget over = await budget();
      expect(over.remainingMinor, -150000,
          reason: 'a shortfall is reported, not clamped to zero');
      expect(over.isOverCommitted, isTrue);
    });

    test('the consumption ratio is the share of income committed', () async {
      await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);

      final MonthlyBudget half = await budget();
      expect(half.consumptionRatio, closeTo(0.5, 0.0001));
      expect(half.consumptionRatioClamped, closeTo(0.5, 0.0001));

      await obligation(name: 'أقساط', amountMinor: 300000, day: 10);
      final MonthlyBudget over = await budget();
      expect(over.consumptionRatio, closeTo(1.25, 0.0001));
      expect(
        over.consumptionRatioClamped,
        1.0,
        reason: 'the bar cannot be longer than the bar',
      );
    });

    test('with no income there is no ratio and nothing is claimed', () async {
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      final MonthlyBudget month = await budget();
      expect(month.hasIncome, isFalse);
      expect(month.consumptionRatio, 0);
      expect(month.consumptionRatioClamped, 0);
      expect(month.remainingMinor, -200000);
    });

    test('an empty month reports nothing and counts nothing', () async {
      final MonthlyBudget month = await budget();
      expect(month.isEmpty, isTrue);
      expect(month.remainingMinor, 0);
      expect(month.incomeCount, 0);
      expect(month.obligationCount, 0);
    });

    test('editing an income moves the figures without touching a record',
        () async {
      final Income salary = await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );
      expect((await budget()).incomeMinor, 400000);

      await service.updateIncome(
        salary.id,
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 500000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );

      final MonthlyBudget after = await budget();
      expect(after.incomeMinor, 500000);
      expect(after.remainingMinor, 500000);
      expect(
        (await service.incomes.getAll()).single.createdAt,
        salary.createdAt,
        reason: 'an edit moves the amount, never the record\'s identity',
      );
    });

    test('deleting an income leaves every other record alone', () async {
      final Income salary = await service.createIncome(
        IncomeDraft(
          name: 'الراتب',
          amountMinor: 400000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.monthly,
          startAt: DateTime(now.year, now.month),
          dayOfMonth: 25,
        ),
      );
      await obligation(name: 'إيجار', amountMinor: 200000, day: 1);
      await service.createPerson(const PersonDraft(name: 'أحمد'));

      await service.deleteIncome(salary.id);

      final MonthlyBudget month = await budget();
      expect(month.incomeMinor, 0);
      expect(month.obligationsMinor, 200000);
      expect(await service.people.getAll(), hasLength(1));
      // The record's own history went with it; what is left is the single notice
      // that it was deleted, so the feed never claims an income was added for a
      // record that is no longer there — and still says it once existed.
      final List<ActivityEntry> entries =
          await service.activity.forEntity(RelatedEntityType.income, salary.id);
      expect(entries, hasLength(1));
      expect(entries.single.type, ActivityType.incomeDeleted);
    });
  });
}
