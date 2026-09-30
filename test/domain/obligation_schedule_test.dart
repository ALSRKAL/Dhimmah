import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/obligation_schedule.dart';
import 'package:flutter_test/flutter_test.dart';

/// Schedule maths for recurring commitments.
void main() {
  Obligation obligation({
    required RecurrenceFrequency frequency,
    DateTime? startAt,
    int? dayOfMonth,
    int intervalCount = 1,
    DateTime? endAt,
    DateTime? nextDueAt,
  }) {
    final DateTime start = startAt ?? DateTime(2026, 1, 31);
    return Obligation(
      id: 'o1',
      name: 'Rent',
      category: ObligationCategory.housing,
      amountMinor: 2000000,
      currency: AppCurrency.inr,
      frequency: frequency,
      intervalCount: intervalCount,
      dayOfMonth: dayOfMonth,
      startAt: start,
      nextDueAt: nextDueAt ?? start,
      endAt: endAt,
      createdAt: start,
      updatedAt: start,
    );
  }

  group('monthly periods', () {
    test('clamp to the month length but recover the anchor day', () {
      final Obligation rent = obligation(frequency: RecurrenceFrequency.monthly);

      // The whole point of anchoring: February is short, March is not.
      expect(ObligationSchedule.nthDueDate(rent, 0), DateTime(2026, 1, 31));
      expect(ObligationSchedule.nthDueDate(rent, 1), DateTime(2026, 2, 28));
      expect(ObligationSchedule.nthDueDate(rent, 2), DateTime(2026, 3, 31));
      expect(ObligationSchedule.nthDueDate(rent, 3), DateTime(2026, 4, 30));
      expect(ObligationSchedule.nthDueDate(rent, 4), DateTime(2026, 5, 31));
    });

    test('keep the anchor day in a leap year', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2028, 1, 29),
      );
      expect(ObligationSchedule.nthDueDate(rent, 1), DateTime(2028, 2, 29));
      expect(ObligationSchedule.nthDueDate(rent, 2), DateTime(2028, 3, 29));
    });

    test('honour an explicitly chosen day of month', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 15),
        dayOfMonth: 1,
      );
      // The schedule follows the chosen day, within the starting month.
      expect(ObligationSchedule.anchorFor(rent), DateTime(2026));
      expect(ObligationSchedule.nthDueDate(rent, 1), DateTime(2026, 2));
    });

    test('clamp a chosen day that the month does not have', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 31),
        dayOfMonth: 31,
      );
      expect(ObligationSchedule.nthDueDate(rent, 1), DateTime(2026, 2, 28));
      expect(ObligationSchedule.nthDueDate(rent, 2), DateTime(2026, 3, 31));
    });

    test('keep a chosen day when the first month is the short one', () {
      // Started in February, due on the 31st. The first period is clamped to
      // the 28th, and every later one used to stay on the 28th with it.
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 2, 10),
        dayOfMonth: 31,
      );
      expect(ObligationSchedule.nthDueDate(rent, 0), DateTime(2026, 2, 28));
      expect(ObligationSchedule.nthDueDate(rent, 1), DateTime(2026, 3, 31));
      expect(ObligationSchedule.nthDueDate(rent, 2), DateTime(2026, 4, 30));
      expect(ObligationSchedule.nthDueDate(rent, 3), DateTime(2026, 5, 31));
      expect(
        ObligationSchedule.dueDatesBetween(
          rent,
          DateTime(2026, 6),
          DateTime(2026, 7, 31),
        ),
        <DateTime>[DateTime(2026, 6, 30), DateTime(2026, 7, 31)],
      );
    });

    test('keep a chosen day across quarters and years', () {
      final Obligation quarterly = obligation(
        frequency: RecurrenceFrequency.quarterly,
        startAt: DateTime(2026, 2, 3),
        dayOfMonth: 30,
      );
      expect(ObligationSchedule.nthDueDate(quarterly, 0), DateTime(2026, 2, 28));
      expect(ObligationSchedule.nthDueDate(quarterly, 1), DateTime(2026, 5, 30));

      final Obligation yearly = obligation(
        frequency: RecurrenceFrequency.yearly,
        startAt: DateTime(2027, 2),
        dayOfMonth: 29,
      );
      expect(ObligationSchedule.nthDueDate(yearly, 0), DateTime(2027, 2, 28));
      expect(ObligationSchedule.nthDueDate(yearly, 1), DateTime(2028, 2, 29));
    });
  });

  group('other frequencies', () {
    test('weekly steps by seven days', () {
      final Obligation weekly = obligation(
        frequency: RecurrenceFrequency.weekly,
        startAt: DateTime(2026, 3, 2),
      );
      expect(ObligationSchedule.nthDueDate(weekly, 1), DateTime(2026, 3, 9));
      expect(ObligationSchedule.nthDueDate(weekly, 8), DateTime(2026, 4, 27));
    });

    test('quarterly steps by three months', () {
      final Obligation quarterly = obligation(
        frequency: RecurrenceFrequency.quarterly,
        startAt: DateTime(2026, 1, 15),
      );
      expect(ObligationSchedule.nthDueDate(quarterly, 1), DateTime(2026, 4, 15));
      expect(ObligationSchedule.nthDueDate(quarterly, 4), DateTime(2027, 1, 15));
    });

    test('yearly steps by years', () {
      final Obligation yearly = obligation(
        frequency: RecurrenceFrequency.yearly,
        startAt: DateTime(2026, 6, 10),
      );
      expect(ObligationSchedule.nthDueDate(yearly, 1), DateTime(2027, 6, 10));
    });

    test('a custom interval multiplies the period', () {
      final Obligation everyTwoMonths = obligation(
        frequency: RecurrenceFrequency.monthly,
        intervalCount: 2,
        startAt: DateTime(2026, 1, 10),
      );
      expect(
        ObligationSchedule.nthDueDate(everyTwoMonths, 1),
        DateTime(2026, 3, 10),
      );
      expect(
        ObligationSchedule.nthDueDate(everyTwoMonths, 3),
        DateTime(2026, 7, 10),
      );
    });
  });

  group('index lookup', () {
    test('finds the period on or after a date', () {
      final Obligation rent = obligation(frequency: RecurrenceFrequency.monthly);
      expect(ObligationSchedule.indexOnOrAfter(rent, DateTime(2026, 1, 31)), 0);
      expect(ObligationSchedule.indexOnOrAfter(rent, DateTime(2026, 2)), 1);
      expect(ObligationSchedule.indexOnOrAfter(rent, DateTime(2026, 2, 28)), 1);
      expect(ObligationSchedule.indexOnOrAfter(rent, DateTime(2026, 3)), 2);
    });

    test('is stable when the schedule started years ago', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2020, 1, 15),
      );
      final int index =
          ObligationSchedule.indexOnOrAfter(rent, DateTime(2026, 9, 22));
      expect(ObligationSchedule.nthDueDate(rent, index), DateTime(2026, 10, 15));
    });
  });

  group('date ranges', () {
    test('list every period inside a window', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 15),
      );
      final List<DateTime> dates = ObligationSchedule.dueDatesBetween(
        rent,
        DateTime(2026, 3),
        DateTime(2026, 6, 30),
      );
      expect(dates, <DateTime>[
        DateTime(2026, 3, 15),
        DateTime(2026, 4, 15),
        DateTime(2026, 5, 15),
        DateTime(2026, 6, 15),
      ]);
    });

    test('stop at the end date', () {
      final Obligation limited = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 15),
        endAt: DateTime(2026, 3, 31),
      );
      final List<DateTime> dates = ObligationSchedule.dueDatesBetween(
        limited,
        DateTime(2026),
        DateTime(2026, 12, 31),
      );
      expect(dates, hasLength(3));
      expect(dates.last, DateTime(2026, 3, 15));
    });
  });

  group('period keys', () {
    test('are unique per period and stable across runs', () {
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.monthly,
          DateTime(2026, 9),
        ),
        '2026-09',
      );
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.yearly,
          DateTime(2026, 9),
        ),
        '2026',
      );
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.quarterly,
          DateTime(2026, 9),
        ),
        '2026-Q3',
      );
    });

    test('follow the ISO week for weekly schedules', () {
      // 1 January 2026 is a Thursday, which is in week 1.
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.weekly,
          DateTime(2026),
        ),
        '2026-W01',
      );
      // 31 December 2026 falls in ISO week 53.
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.weekly,
          DateTime(2026, 12, 31),
        ),
        '2026-W53',
      );
    });

    test('name the year an ISO week belongs to, not the calendar year', () {
      // 31 December 2025 is in week 1 of 2026. Keyed with the calendar year it
      // was `2025-W01` — 1 January 2025's key — and was never created.
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.weekly,
          DateTime(2025, 12, 31),
        ),
        '2026-W01',
      );
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.weekly,
          DateTime(2025),
        ),
        '2025-W01',
      );
      // And the other edge: 1 January 2027 is still in week 53 of 2026.
      expect(
        ObligationSchedule.periodKeyFor(
          RecurrenceFrequency.weekly,
          DateTime(2027),
        ),
        '2026-W53',
      );
    });

    test('give every week of a weekly schedule its own key', () {
      final Obligation weekly = obligation(
        frequency: RecurrenceFrequency.weekly,
        startAt: DateTime(2024, 1, 3),
      );
      final List<DateTime> dates = ObligationSchedule.dueDatesBetween(
        weekly,
        DateTime(2024),
        DateTime(2029, 12, 31),
      );
      final Set<String> keys = <String>{
        for (final DateTime date in dates)
          ObligationSchedule.periodKeyFor(RecurrenceFrequency.weekly, date),
      };
      expect(keys, hasLength(dates.length));
    });
  });

  group('status resolution', () {
    test('a stored terminal status survives the passage of time', () {
      expect(
        ObligationSchedule.resolveStatus(
          stored: ObligationStatus.paid,
          dueAt: DateTime(2020),
          asOf: DateTime(2026, 9, 22),
        ),
        ObligationStatus.paid,
      );
      expect(
        ObligationSchedule.resolveStatus(
          stored: ObligationStatus.skipped,
          dueAt: DateTime(2020),
          asOf: DateTime(2026, 9, 22),
        ),
        ObligationStatus.skipped,
      );
    });

    test('an open period resolves from its date', () {
      final DateTime asOf = DateTime(2026, 9, 22);
      expect(
        ObligationSchedule.resolveStatus(
          stored: ObligationStatus.upcoming,
          dueAt: DateTime(2026, 9, 21),
          asOf: asOf,
        ),
        ObligationStatus.overdue,
      );
      expect(
        ObligationSchedule.resolveStatus(
          stored: ObligationStatus.upcoming,
          dueAt: asOf,
          asOf: asOf,
        ),
        ObligationStatus.dueToday,
      );
      expect(
        ObligationSchedule.resolveStatus(
          stored: ObligationStatus.upcoming,
          dueAt: DateTime(2026, 10),
          asOf: asOf,
        ),
        ObligationStatus.upcoming,
      );
    });
  });

  group('rolling forward', () {
    test('advances to the next period', () {
      final Obligation rent = obligation(
        frequency: RecurrenceFrequency.monthly,
        nextDueAt: DateTime(2026, 1, 31),
      );
      final DateTime? next = ObligationSchedule.rollForward(
        rent.copyWith(nextDueAt: DateTime(2026, 1, 31)),
      );
      expect(next, DateTime(2026, 2, 28));
    });

    test('returns null once the schedule has ended', () {
      final Obligation limited = obligation(
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 1, 15),
        endAt: DateTime(2026, 2, 28),
      );
      final DateTime? next = ObligationSchedule.rollForward(
        limited.copyWith(nextDueAt: DateTime(2026, 2, 15)),
      );
      expect(next, isNull);
    });
  });

  group('date helpers', () {
    test('addMonths clamps instead of overflowing', () {
      expect(addMonths(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
      expect(addMonths(DateTime(2026, 3, 31), 1), DateTime(2026, 4, 30));
      expect(addMonths(DateTime(2026, 12, 15), 1), DateTime(2027, 1, 15));
    });

    test('addYears clamps 29 February', () {
      expect(addYears(DateTime(2028, 2, 29), 1), DateTime(2029, 2, 28));
      expect(addYears(DateTime(2028, 2, 29), 4), DateTime(2032, 2, 29));
    });

    test('daysBetween counts calendar days, not hours', () {
      // 23:00 to 01:00 the next day is one calendar day, not zero.
      expect(
        daysBetween(DateTime(2026, 9, 22, 23), DateTime(2026, 9, 23, 1)),
        1,
      );
      expect(
        daysBetween(DateTime(2026, 9, 22, 1), DateTime(2026, 9, 22, 23)),
        0,
      );
    });

    test('isWithin is inclusive at both ends', () {
      expect(
        isWithin(
          DateTime(2026, 9),
          DateTime(2026, 9),
          DateTime(2026, 9, 30),
        ),
        isTrue,
      );
      expect(
        isWithin(
          DateTime(2026, 9, 30),
          DateTime(2026, 9),
          DateTime(2026, 9, 30),
        ),
        isTrue,
      );
    });
  });
}
