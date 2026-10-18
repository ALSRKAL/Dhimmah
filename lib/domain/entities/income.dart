import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../enums/recurrence.dart';

/// Money that comes in on a recurring schedule: a salary, a monthly allowance,
/// a pension, rent received.
///
/// This is the counterpart of `Obligation` and deliberately a different type.
/// An obligation is money going out and carries a category, a due date, periods
/// and a paid state; an income is money coming in and carries none of those.
/// Folding one into the other would make the direction a value instead of a
/// fact, and every total in the app would have to remember which kind of row it
/// was adding.
///
/// The record is the *rule*, not one payment. Nothing is stored when a salary
/// arrives, because there is nothing to settle: the month's income is derived
/// from the schedule, the way the month's obligations are derived from theirs.
@immutable
class Income {
  const Income({
    required this.id,
    required this.name,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.startAt,
    required this.createdAt,
    required this.updatedAt,
    this.intervalCount = 1,
    this.dayOfMonth,
    this.note,
    this.archivedAt,
  });

  final String id;
  final String name;
  final int amountMinor;
  final AppCurrency currency;
  final RecurrenceFrequency frequency;

  /// Every N periods. `1` means every month / week / year.
  final int intervalCount;

  /// For monthly-ish frequencies, the day of the month the money arrives.
  final int? dayOfMonth;

  /// The anchor the schedule is measured from — the first period this income
  /// applied to. Every later period is derived from it and never from the
  /// previous one, so "the 30th" stays the 30th in a 31-day month.
  final DateTime startAt;

  final String? note;

  /// Archived rather than deleted when the user stops receiving it, so the
  /// months it did cover keep reading correctly.
  final DateTime? archivedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  bool get isActive => archivedAt == null;

  /// Never below one, whatever a hand-edited file said.
  int get effectiveInterval => intervalCount <= 0 ? 1 : intervalCount;

  bool get isMonthly => frequency == RecurrenceFrequency.monthly;

  Income copyWith({
    String? name,
    int? amountMinor,
    AppCurrency? currency,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    Object? dayOfMonth = _unset,
    DateTime? startAt,
    Object? note = _unset,
    Object? archivedAt = _unset,
    DateTime? updatedAt,
  }) {
    return Income(
      id: id,
      name: name ?? this.name,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      dayOfMonth: identical(dayOfMonth, _unset)
          ? this.dayOfMonth
          : dayOfMonth as int?,
      startAt: startAt ?? this.startAt,
      note: identical(note, _unset) ? this.note : note as String?,
      archivedAt:
          identical(archivedAt, _unset) ? this.archivedAt : archivedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Every field, and that is not a formality here.
  ///
  /// The budget card watches this table through a stream. A field left out of
  /// `==` makes a real edit compare equal to the old value, so the stream emits
  /// and nothing downstream reacts — the same failure `AppSettings` documents,
  /// where turning a setting off wrote the database and the screen kept showing
  /// "on" until a restart.
  @override
  bool operator ==(Object other) =>
      other is Income &&
      other.id == id &&
      other.name == name &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.frequency == frequency &&
      other.intervalCount == intervalCount &&
      other.dayOfMonth == dayOfMonth &&
      other.startAt == startAt &&
      other.note == note &&
      other.archivedAt == archivedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        amountMinor,
        currency,
        frequency,
        intervalCount,
        dayOfMonth,
        startAt,
        note,
        archivedAt,
        createdAt,
        updatedAt,
      );
}

const Object _unset = Object();
