import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/income.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/amount_rules.dart';
import 'package:dhimmah/domain/services/income_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// The month's income figure at its edges.
///
/// An income is stored as a rule and the month's amount is walked off it on
/// every read, so every awkward date is computed again and again for every
/// month the user opens. There is no occurrence table to hold a mistake: a
/// schedule that mishandles the 31st of February is simply wrong, every month,
/// for as long as the user has the income.
void main() {
  /// When the synthetic records say they were written. Nothing the schedule
  /// maths reads it — an income is read through its rhythm — so any date does.
  final DateTime written = DateTime(2026, 3);

  Income income({
    required RecurrenceFrequency frequency,
    required DateTime startAt,
    int? dayOfMonth,
    int intervalCount = 1,
    int amountMinor = 400000,
  }) =>
      Income(
        id: 'i1',
        name: 'دخل',
        amountMinor: amountMinor,
        currency: AppCurrency.inr,
        frequency: frequency,
        intervalCount: intervalCount,
        dayOfMonth: dayOfMonth,
        startAt: startAt,
        createdAt: written,
        updatedAt: written,
      );

  int inMonth(Income source, int year, int month) =>
      IncomeSchedule.amountInMonth(source, DateTime(year, month));

  group('a schedule that has no periods', () {
    test('a one-off counts in its own month and in no other', () {
      // A bonus is not a salary: walking a one-off like a schedule would pay it
      // again every month for ever.
      final Income bonus = income(
        frequency: RecurrenceFrequency.none,
        startAt: DateTime(2026, 9, 25),
      );

      expect(inMonth(bonus, 2026, 9), 400000);
      expect(inMonth(bonus, 2026, 10), 0);
      expect(inMonth(bonus, 2026, 8), 0);
      expect(inMonth(bonus, 2027, 9), 0);
    });

    test('a one-off dated at the month\'s last day still counts once', () {
      final Income bonus = income(
        frequency: RecurrenceFrequency.none,
        startAt: DateTime(2026, 2, 28),
      );
      expect(inMonth(bonus, 2026, 2), 400000);
      expect(inMonth(bonus, 2026, 3), 0);
    });
  });

  group('a monthly income on a day every month does not have', () {
    test('the 31st lands in February, on its last day', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 31),
        dayOfMonth: 31,
      );

      expect(inMonth(salary, 2026, 1), 400000);
      expect(inMonth(salary, 2026, 2), 400000, reason: 'the 28th, and once');
      expect(inMonth(salary, 2026, 4), 400000, reason: 'the 30th, and once');
    });

    test('and February of a leap year takes it on the 29th', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2028, 1, 31),
        dayOfMonth: 31,
      );
      expect(inMonth(salary, 2028, 2), 400000);
      expect(
        IncomeSchedule.occurrencesInMonth(salary, DateTime(2028, 2)).single,
        DateTime(2028, 2, 29),
      );
    });

    test('every month of a year pays exactly once', () {
      // The failure this exists for is a clamp that sticks: the 31st read as
      // the 28th in February and stayed the 28th for the rest of the year.
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 31),
        dayOfMonth: 31,
      );

      for (int month = 1; month <= 12; month++) {
        expect(
          IncomeSchedule.occurrencesInMonth(salary, DateTime(2026, month)),
          hasLength(1),
          reason: 'month $month',
        );
      }
      expect(
        IncomeSchedule.occurrencesInMonth(salary, DateTime(2026, 3)).single,
        DateTime(2026, 3, 31),
        reason: 'March is a 31-day month and gets the 31st back',
      );
    });
  });

  group('a yearly income on 29 February', () {
    final Income leapDay = Income(
      id: 'i2',
      name: 'إيجار',
      amountMinor: 100000,
      currency: AppCurrency.inr,
      frequency: RecurrenceFrequency.yearly,
      startAt: DateTime(2028, 2, 29),
      createdAt: written,
      updatedAt: written,
    );

    test('counts in its own leap year and in the next one, on the 28th', () {
      expect(inMonth(leapDay, 2028, 2), 100000);
      expect(inMonth(leapDay, 2029, 2), 100000);
      expect(
        IncomeSchedule.occurrencesInMonth(leapDay, DateTime(2029, 2)).single,
        DateTime(2029, 2, 28),
      );
    });

    test('and comes back to the 29th in the next leap year', () {
      // Derived from the anchor, never from the previous period: a 28th that
      // stuck would mean this income never landed on its own day again.
      expect(
        IncomeSchedule.occurrencesInMonth(leapDay, DateTime(2032, 2)).single,
        DateTime(2032, 2, 29),
      );
    });

    test('is worth nothing in the other months', () {
      for (int month = 1; month <= 12; month++) {
        if (month == 2) continue;
        expect(inMonth(leapDay, 2028, month), 0, reason: 'month $month');
      }
    });
  });

  group('a weekly income', () {
    test('a five-week month is worth more than a four-week one', () {
      // June 2026 has five Mondays (1, 8, 15, 22, 29); July has four.
      final Income wage = income(
        frequency: RecurrenceFrequency.weekly,
        startAt: DateTime(2026, 6),
      );

      expect(inMonth(wage, 2026, 6), 5 * 400000);
      expect(inMonth(wage, 2026, 7), 4 * 400000);
      expect(
        IncomeSchedule.occurrencesInMonth(wage, DateTime(2026, 6)).first,
        DateTime(2026, 6),
      );
    });
  });

  group('a longer interval', () {
    test('every second month counts in the anchor\'s months, and no others', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 2,
        startAt: DateTime(2026, 8, 5),
        dayOfMonth: 5,
      );

      expect(inMonth(salary, 2026, 8), 400000);
      expect(inMonth(salary, 2026, 9), 0, reason: 'the phase comes from the anchor');
      expect(inMonth(salary, 2026, 10), 400000);
      expect(inMonth(salary, 2026, 11), 0);
      expect(inMonth(salary, 2026, 12), 400000);
      expect(inMonth(salary, 2027, 1), 0);
      expect(inMonth(salary, 2027, 2), 400000, reason: 'February follows the '
          'phase, not the length of the month');
    });

    test('nothing is paid before the income starts', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 9, 5),
        dayOfMonth: 5,
      );
      expect(inMonth(salary, 2026, 8), 0);
      expect(inMonth(salary, 2026, 9), 400000);
    });
  });

  group('at the ceiling', () {
    test('a month of the largest amounts stays exact', () {
      // The largest income Dhimmah accepts, weekly, in a five-week month. The
      // multiply and the additions that follow it are the two places 64-bit
      // arithmetic could wrap round into a small, plausible-looking number.
      final Income largest = income(
        frequency: RecurrenceFrequency.weekly,
        startAt: DateTime(2026, 6),
        amountMinor: AmountRules.maxMinor,
      );

      final int june = inMonth(largest, 2026, 6);
      expect(june, 5 * AmountRules.maxMinor);
      expect(june, greaterThan(0), reason: 'a wrap would show as a small number');

      // Two of them, added the way the budget card adds its sources.
      int total = 0;
      for (final Income source in <Income>[largest, largest]) {
        final int amount = inMonth(source, 2026, 6);
        total += amount;
      }
      expect(total, 10 * AmountRules.maxMinor);
      expect(total ~/ 10, AmountRules.maxMinor);
    });
  });

  group('the day of the month is honoured when one was chosen', () {
    test('the anchor is the chosen day, not the day the row was created', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 9, 20),
        dayOfMonth: 5,
      );
      expect(
        IncomeSchedule.occurrencesInMonth(salary, DateTime(2026, 9)).single,
        DateTime(2026, 9, 5),
        reason: 'the 5th was chosen, and the row happened to be created on the 20th',
      );
    });

    test('a chosen day past the end of the start month is clamped there', () {
      final Income salary = income(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 2, 10),
        dayOfMonth: 31,
      );
      expect(
        IncomeSchedule.occurrencesInMonth(salary, DateTime(2026, 2)).single,
        DateTime(2026, 2, 28),
      );
      expect(
        IncomeSchedule.occurrencesInMonth(salary, DateTime(2026, 3)).single,
        DateTime(2026, 3, 31),
      );
    });
  });

  test('a month is never counted twice', () {
    // Every branch above asks for one month, and the count each returns is the
    // number of dates in it: the same walk, read the other way, must agree.
    final List<Income> all = <Income>[
      income(frequency: RecurrenceFrequency.monthly, startAt: DateTime(2026, 1, 31), dayOfMonth: 31),
      income(frequency: RecurrenceFrequency.weekly, startAt: DateTime(2026, 6)),
      income(frequency: RecurrenceFrequency.monthly, intervalCount: 2, startAt: DateTime(2026, 8, 5), dayOfMonth: 5),
      income(frequency: RecurrenceFrequency.yearly, startAt: DateTime(2024, 2, 29)),
      income(frequency: RecurrenceFrequency.none, startAt: DateTime(2026, 9, 25)),
    ];

    for (final Income source in all) {
      for (int month = 1; month <= 12; month++) {
        final List<DateTime> dates =
            IncomeSchedule.occurrencesInMonth(source, DateTime(2026, month));
        expect(
          IncomeSchedule.amountInMonth(source, DateTime(2026, month)),
          dates.length * source.amountMinor,
          reason: 'month $month of ${source.frequency}',
        );
        expect(
          dates.toSet(),
          hasLength(dates.length),
          reason: 'the same day twice would be the same money twice',
        );
        for (final DateTime date in dates) {
          expect(date.year, 2026);
          expect(date.month, month);
          expect(isSameDate(date, dateOnly(date)), isTrue);
        }
      }
    }
  });
}
