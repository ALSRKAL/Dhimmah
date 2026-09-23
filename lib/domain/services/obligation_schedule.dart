import '../../core/utils/dates.dart';
import '../entities/obligation.dart';
import '../enums/obligation_enums.dart';
import '../enums/recurrence.dart';

/// Schedule maths for recurring commitments.
///
/// The important property here is that every period is derived from the
/// obligation's *anchor* date, never from the previous period. "The 31st" stays
/// the 31st: January 31 → February 28 → March 31, rather than collapsing to the
/// 28th forever. That is the bug this class exists to prevent.
abstract final class ObligationSchedule {
  const ObligationSchedule._();

  /// Safety bound for forward walks. A schedule spanning more than this many
  /// periods is not something a personal ledger needs.
  static const int maxPeriods = 1200;

  /// The date the schedule is measured from, honouring an explicitly chosen day
  /// of the month when there is one.
  static DateTime anchorFor(Obligation obligation) {
    final int? day = obligation.dayOfMonth;
    if (day == null) return dateOnly(obligation.startAt);
    final DateTime start = dateOnly(obligation.startAt);
    final int clamped = day > daysInMonth(start.year, start.month)
        ? daysInMonth(start.year, start.month)
        : day;
    return DateTime(start.year, start.month, clamped);
  }

  /// The `n`-th period's due date, counted from the anchor.
  static DateTime nthDueDate(Obligation obligation, int n) {
    final DateTime anchor = anchorFor(obligation);
    final int step = obligation.effectiveInterval;
    if (n <= 0) return anchor;
    return switch (obligation.frequency) {
      RecurrenceFrequency.weekly => addDays(anchor, 7 * step * n),
      RecurrenceFrequency.monthly => addMonths(anchor, step * n),
      RecurrenceFrequency.quarterly => addMonths(anchor, 3 * step * n),
      RecurrenceFrequency.yearly => addYears(anchor, step * n),
      RecurrenceFrequency.custom => addMonths(anchor, step * n),
      RecurrenceFrequency.none => anchor,
    };
  }

  /// Smallest period index whose due date is on or after [target].
  static int indexOnOrAfter(Obligation obligation, DateTime target) {
    final DateTime want = dateOnly(target);
    final DateTime anchor = anchorFor(obligation);
    final int step = obligation.effectiveInterval;

    // Start from an arithmetic estimate, then correct by at most a step or two.
    int guess = switch (obligation.frequency) {
      RecurrenceFrequency.weekly =>
        (daysBetween(anchor, want) / (7 * step)).floor(),
      RecurrenceFrequency.monthly || RecurrenceFrequency.custom =>
        (((want.year - anchor.year) * 12 + (want.month - anchor.month)) / step)
            .floor(),
      RecurrenceFrequency.quarterly =>
        (((want.year - anchor.year) * 12 + (want.month - anchor.month)) /
                (3 * step))
            .floor(),
      RecurrenceFrequency.yearly =>
        ((want.year - anchor.year) / step).floor(),
      RecurrenceFrequency.none => 0,
    };
    if (guess < 0) guess = 0;

    int n = guess;
    // Walk back while the previous period already satisfies the target.
    while (n > 0 && !nthDueDate(obligation, n - 1).isBefore(want)) {
      n--;
    }
    // Walk forward until the period satisfies the target.
    while (n < maxPeriods && nthDueDate(obligation, n).isBefore(want)) {
      n++;
    }
    return n;
  }

  /// The next due date strictly after [current].
  static DateTime nextDueAfter(Obligation obligation, DateTime current) {
    final int index = indexOnOrAfter(obligation, dateOnly(current));
    final DateTime candidate = nthDueDate(obligation, index);
    if (candidate.isAfter(dateOnly(current))) return candidate;
    return nthDueDate(obligation, index + 1);
  }

  /// All due dates inside `[from, to]` inclusive.
  static List<DateTime> dueDatesBetween(
    Obligation obligation,
    DateTime from,
    DateTime to,
  ) {
    final DateTime start = dateOnly(from);
    final DateTime end = dateOnly(to);
    final List<DateTime> out = <DateTime>[];
    int n = indexOnOrAfter(obligation, start);
    while (n < maxPeriods) {
      final DateTime due = nthDueDate(obligation, n);
      if (due.isAfter(end)) break;
      if (obligation.endAt != null && due.isAfter(dateOnly(obligation.endAt!))) {
        break;
      }
      out.add(due);
      n++;
    }
    return out;
  }

  /// A stable key for the period a due date belongs to.
  static String periodKeyFor(RecurrenceFrequency frequency, DateTime dueAt) {
    return switch (frequency) {
      RecurrenceFrequency.weekly =>
        '${dueAt.year}-W${_isoWeekNumber(dueAt).toString().padLeft(2, '0')}',
      RecurrenceFrequency.quarterly =>
        '${dueAt.year}-Q${((dueAt.month - 1) ~/ 3) + 1}',
      RecurrenceFrequency.yearly => '${dueAt.year}',
      RecurrenceFrequency.monthly ||
      RecurrenceFrequency.custom ||
      RecurrenceFrequency.none =>
        monthKey(dueAt),
    };
  }

  /// Where an occurrence stands today.
  ///
  /// A stored terminal status (paid, skipped, cancelled) always wins: once the
  /// user has acted, the passage of time must not re-open it.
  static ObligationStatus resolveStatus({
    required ObligationStatus stored,
    required DateTime dueAt,
    required DateTime asOf,
  }) {
    if (stored == ObligationStatus.paid ||
        stored == ObligationStatus.skipped ||
        stored == ObligationStatus.cancelled) {
      return stored;
    }
    final int days = daysBetween(asOf, dueAt);
    if (days < 0) return ObligationStatus.overdue;
    if (days == 0) return ObligationStatus.dueToday;
    return ObligationStatus.upcoming;
  }

  /// The due date the obligation should point at after its current period is
  /// settled, or null once the schedule has ended.
  static DateTime? rollForward(Obligation obligation) {
    final DateTime next = nextDueAfter(obligation, obligation.nextDueAt);
    final DateTime? end = obligation.endAt;
    if (end != null && next.isAfter(dateOnly(end))) return null;
    return next;
  }

  /// ISO-8601 week number, used for the weekly period key.
  ///
  /// Week 1 is the week containing the first Thursday of the year, which is the
  /// same as the week containing 4 January.
  static int _isoWeekNumber(DateTime date) {
    final DateTime thursday = addDays(date, DateTime.thursday - date.weekday);
    final DateTime januaryFourth = DateTime(thursday.year, 1, 4);
    final DateTime firstThursday =
        addDays(januaryFourth, DateTime.thursday - januaryFourth.weekday);
    return (daysBetween(firstThursday, thursday) ~/ 7) + 1;
  }
}
