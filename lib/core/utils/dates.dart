/// Date helpers shared by the domain layer.
///
/// Dhimmah distinguishes two kinds of time:
///
/// * **Dates** — the day a debt was taken on, a due date, the day a payment was
///   made. A date is a calendar fact, not an instant, so it is normalised to
///   local midnight and stored as `yyyy-MM-dd`. This is what makes a due date
///   survive a timezone change.
/// * **Timestamps** — when a row was created or edited. Stored as UTC
///   milliseconds.
///
/// Anything that decides whether something is late compares *dates*.
library;

/// Number of milliseconds in a day. Only used for calendar arithmetic on
/// normalised dates, never for elapsed-time maths across DST boundaries.
const int _millisPerDay = 86400000;

/// Truncates [value] to local midnight.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Today, as a plain date.
DateTime today() => dateOnly(DateTime.now());

/// Whether two values fall on the same calendar day.
bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Whole days from [from] to [to], counted by calendar day.
///
/// Positive when [to] is in the future. Because both sides are truncated to
/// midnight, this is unaffected by the time of day.
int daysBetween(DateTime from, DateTime to) {
  final DateTime a = DateTime(from.year, from.month, from.day);
  final DateTime b = DateTime(to.year, to.month, to.day);
  // Round to absorb any sub-second drift introduced by the division.
  return ((b.difference(a)).inMilliseconds / _millisPerDay).round();
}

/// Adds [months] calendar months to [value], clamping the day to the last valid
/// day of the target month.
///
/// This is what makes "31 January + 1 month" the 28th (or 29th) of February
/// rather than overflowing into March, which is exactly the behaviour a monthly
/// obligation needs.
DateTime addMonths(DateTime value, int months) {
  final int totalMonths = value.month - 1 + months;
  final int year = value.year + (totalMonths ~/ 12);
  final int month = (totalMonths % 12) + 1;
  final int lastDay = daysInMonth(year, month);
  return DateTime(year, month, value.day < lastDay ? value.day : lastDay);
}

/// Adds [years] calendar years, clamping 29 February to the 28th in non-leap
/// years.
DateTime addYears(DateTime value, int years) {
  final int year = value.year + years;
  final int lastDay = daysInMonth(year, value.month);
  return DateTime(year, value.month, value.day < lastDay ? value.day : lastDay);
}

/// Adds whole days.
DateTime addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

/// The number of days in [month] of [year].
int daysInMonth(int year, int month) {
  if (month == 2) return isLeapYear(year) ? 29 : 28;
  const List<int> lengths = <int>[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  return lengths[month - 1];
}

bool isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

/// The last day of [month] as a date.
DateTime lastDayOfMonth(int year, int month) =>
    DateTime(year, month, daysInMonth(year, month));

/// The first day of the month containing [value].
DateTime startOfMonth(DateTime value) => DateTime(value.year, value.month);

/// The last day of the month containing [value].
DateTime endOfMonth(DateTime value) =>
    lastDayOfMonth(value.year, value.month);

/// Shifts to the first day of the next month.
DateTime startOfNextMonth(DateTime value) => addMonths(startOfMonth(value), 1);

/// Shifts to the first day of the previous month.
DateTime startOfPreviousMonth(DateTime value) =>
    addMonths(startOfMonth(value), -1);

/// The inclusive end of the month containing [value].
DateTime endOfPreviousMonth(DateTime value) => endOfMonth(startOfPreviousMonth(value));

/// Monday-based start of the week containing [value].
DateTime startOfWeek(DateTime value) =>
    addDays(dateOnly(value), -(value.weekday - DateTime.monday));

DateTime endOfWeek(DateTime value) => addDays(startOfWeek(value), 6);

/// Whether [value] falls within [start] and [end], both inclusive, by date.
bool isWithin(DateTime value, DateTime start, DateTime end) {
  final DateTime v = dateOnly(value);
  return !v.isBefore(dateOnly(start)) && !v.isAfter(dateOnly(end));
}

/// Formats a date the way the database stores it: `yyyy-MM-dd`.
String toIsoDate(DateTime value) {
  final String month = value.month.toString().padLeft(2, '0');
  final String day = value.day.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-$month-$day';
}

/// Parses a `yyyy-MM-dd` string. Returns null when the text is not a date.
DateTime? tryParseIsoDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// A stable `yyyy-MM` key identifying the month containing [value].
String monthKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}';
