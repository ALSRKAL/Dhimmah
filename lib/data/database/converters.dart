import 'package:drift/drift.dart';

import '../../core/utils/dates.dart';
import '../../domain/enums/recurrence.dart';

/// Stores a calendar date as `yyyy-MM-dd`.
///
/// Dates are deliberately kept as text rather than an epoch offset: a due date
/// is a calendar fact, and storing it as an instant is how a due date silently
/// shifts by a day when the device changes timezone.
class DateOnlyConverter extends TypeConverter<DateTime, String> {
  const DateOnlyConverter();

  @override
  DateTime fromSql(String fromDb) =>
      tryParseIsoDate(fromDb) ?? DateTime(1970);

  @override
  String toSql(DateTime value) => toIsoDate(value);
}

class NullableDateOnlyConverter extends TypeConverter<DateTime?, String?> {
  const NullableDateOnlyConverter();

  @override
  DateTime? fromSql(String? fromDb) => tryParseIsoDate(fromDb);

  @override
  String? toSql(DateTime? value) => value == null ? null : toIsoDate(value);
}

/// Stores an instant as UTC milliseconds since the epoch.
class TimestampConverter extends TypeConverter<DateTime, int> {
  const TimestampConverter();

  @override
  DateTime fromSql(int fromDb) =>
      DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true).toLocal();

  @override
  int toSql(DateTime value) => value.toUtc().millisecondsSinceEpoch;
}

class NullableTimestampConverter extends TypeConverter<DateTime?, int?> {
  const NullableTimestampConverter();

  @override
  DateTime? fromSql(int? fromDb) => fromDb == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(fromDb, isUtc: true).toLocal();

  @override
  int? toSql(DateTime? value) => value?.toUtc().millisecondsSinceEpoch;
}

/// Stores reminder lead times as a compact list of day offsets, e.g. `7,1,0`.
///
/// Order is normalised on write (furthest out first) so two records configured
/// with the same reminders always compare equal.
class ReminderLeadsConverter extends TypeConverter<List<ReminderLead>, String> {
  const ReminderLeadsConverter();

  @override
  List<ReminderLead> fromSql(String fromDb) {
    if (fromDb.trim().isEmpty) return const <ReminderLead>[];
    return ReminderLead.sorted(
      fromDb
          .split(',')
          .map((String part) => int.tryParse(part.trim()))
          .whereType<int>()
          .map(ReminderLead.fromDays)
          .where((ReminderLead lead) => !lead.isNone),
    );
  }

  @override
  String toSql(List<ReminderLead> value) => ReminderLead.sorted(value)
      .map((ReminderLead lead) => lead.daysBefore)
      .join(',');
}
