import '../../core/utils/dates.dart';
import '../entities/income.dart';
import '../entities/obligation.dart';
import '../enums/obligation_enums.dart';
import '../enums/recurrence.dart';
import 'obligation_schedule.dart';

/// How much income a month receives, derived from the schedule.
///
/// An income has no occurrence table: nothing is "paid" when a salary arrives
/// and there is no per-period state to keep. So the month's figure is walked off
/// the schedule every time it is read, which is the same choice the report makes
/// for obligations — derive it, never store it.
///
/// The stepping itself is [ObligationSchedule]'s, not a second copy of it. The
/// anchor rule it implements — every period derived from the anchor and never
/// from the previous one, so "the 30th" stays the 30th through February — is
/// load-bearing for obligations and would be just as wrong to duplicate here as
/// it would be to get wrong there. A new implementation would be free to drift
/// from the original the first time either was touched.
abstract final class IncomeSchedule {
  const IncomeSchedule._();

  /// How much [income] pays into the month beginning on [month].
  ///
  /// Weekly income counts the weeks that actually land in the month, so a
  /// five-week month is worth more than a four-week one — which is true, and
  /// worth showing rather than smoothing away.
  static int amountInMonth(Income income, DateTime month) {
    return income.amountMinor * occurrencesInMonth(income, month).length;
  }

  /// The dates [income] pays on inside the month beginning on [month].
  static List<DateTime> occurrencesInMonth(Income income, DateTime month) {
    final DateTime first = DateTime(month.year, month.month);
    final DateTime last = DateTime(month.year, month.month + 1, 0);

    // A one-off income is not a schedule, and walking one would never terminate
    // usefully: the day it names is the only day it has. It counts in its own
    // month and in no other, so a bonus does not silently repeat for ever.
    if (income.frequency == RecurrenceFrequency.none) {
      final DateTime anchor = _anchorFor(income);
      if (anchor.isBefore(first) || anchor.isAfter(last)) {
        return const <DateTime>[];
      }
      return <DateTime>[anchor];
    }

    return ObligationSchedule.dueDatesBetween(
      _asRecurrence(income),
      first,
      last,
    );
  }

  /// The day of the month the schedule is measured from.
  static DateTime _anchorFor(Income income) {
    final int? day = income.dayOfMonth;
    final DateTime start = dateOnly(income.startAt);
    if (day == null) return start;
    final int clamped =
        day > daysInMonth(start.year, start.month) ? daysInMonth(start.year, start.month) : day;
    return DateTime(start.year, start.month, clamped);
  }

  /// The income's rhythm, expressed as the recurring shape [ObligationSchedule]
  /// already knows how to walk.
  ///
  /// The placeholder fields an [Obligation] requires are never read by the
  /// schedule maths — it looks at the frequency, the interval, the anchor and
  /// the day of the month, and nothing else — and this value is never stored,
  /// never shown and never compared. It exists so the anchor rule has exactly
  /// one implementation instead of two.
  static Obligation _asRecurrence(Income income) {
    final DateTime start = dateOnly(income.startAt);
    return Obligation(
      id: income.id,
      name: income.name,
      category: ObligationCategory.other,
      amountMinor: income.amountMinor,
      currency: income.currency,
      frequency: income.frequency,
      intervalCount: income.effectiveInterval,
      dayOfMonth: income.dayOfMonth,
      startAt: start,
      nextDueAt: start,
      createdAt: income.createdAt,
      updatedAt: income.updatedAt,
    );
  }
}
