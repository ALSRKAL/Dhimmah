import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/money/money.dart';
import '../../core/utils/dates.dart';
import '../enums/obligation_enums.dart';
import '../enums/recurrence.dart';

/// A recurring commitment the user has to pay: rent, a subscription, a salary
/// they pay out, an instalment plan.
///
/// The obligation is the *rule*; [ObligationOccurrence]s are the individual
/// periods it generates. Paying happens on occurrences, which is what lets the
/// app keep a clean month-by-month history of a commitment that never ends.
@immutable
class Obligation {
  const Obligation({
    required this.id,
    required this.name,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.startAt,
    required this.nextDueAt,
    required this.createdAt,
    required this.updatedAt,
    this.intervalCount = 1,
    this.dayOfMonth,
    this.note,
    this.reminderLeads = const <ReminderLead>[],
    this.endAt,
    this.archivedAt,
  });

  final String id;
  final String name;
  final ObligationCategory category;
  final int amountMinor;
  final AppCurrency currency;
  final RecurrenceFrequency frequency;

  /// Every N periods. `1` means every month / week / year.
  final int intervalCount;

  /// For monthly-ish frequencies, the day of the month the payment lands on.
  /// Kept so "the 31st" stays the 31st in months that have one, and clamps
  /// sensibly when they do not.
  final int? dayOfMonth;

  /// The first period this obligation applied to.
  final DateTime startAt;

  /// The next period that still needs paying.
  final DateTime nextDueAt;

  final DateTime? endAt;
  final String? note;
  final List<ReminderLead> reminderLeads;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  bool get isActive => archivedAt == null;

  int get effectiveInterval => intervalCount <= 0 ? 1 : intervalCount;

  bool get isMonthly => frequency == RecurrenceFrequency.monthly;

  /// The period after [from], applying the same clamping rules used to build the
  /// schedule in the first place.
  DateTime nextOccurrenceAfter(DateTime from) {
    return switch (frequency) {
      RecurrenceFrequency.weekly => addDays(from, 7 * effectiveInterval),
      RecurrenceFrequency.monthly => addMonths(from, effectiveInterval),
      RecurrenceFrequency.quarterly => addMonths(from, 3 * effectiveInterval),
      RecurrenceFrequency.yearly => addYears(from, effectiveInterval),
      RecurrenceFrequency.custom => addMonths(from, effectiveInterval),
      RecurrenceFrequency.none => addMonths(from, effectiveInterval),
    };
  }

  Obligation copyWith({
    String? name,
    ObligationCategory? category,
    int? amountMinor,
    AppCurrency? currency,
    RecurrenceFrequency? frequency,
    int? intervalCount,
    Object? dayOfMonth = _unset,
    DateTime? startAt,
    DateTime? nextDueAt,
    Object? endAt = _unset,
    Object? note = _unset,
    List<ReminderLead>? reminderLeads,
    Object? archivedAt = _unset,
    DateTime? updatedAt,
  }) {
    return Obligation(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      frequency: frequency ?? this.frequency,
      intervalCount: intervalCount ?? this.intervalCount,
      dayOfMonth: identical(dayOfMonth, _unset)
          ? this.dayOfMonth
          : dayOfMonth as int?,
      startAt: startAt ?? this.startAt,
      nextDueAt: nextDueAt ?? this.nextDueAt,
      endAt: identical(endAt, _unset) ? this.endAt : endAt as DateTime?,
      note: identical(note, _unset) ? this.note : note as String?,
      reminderLeads: reminderLeads ?? this.reminderLeads,
      archivedAt:
          identical(archivedAt, _unset) ? this.archivedAt : archivedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Obligation &&
      other.id == id &&
      other.name == name &&
      other.category == category &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.frequency == frequency &&
      other.intervalCount == intervalCount &&
      other.dayOfMonth == dayOfMonth &&
      other.startAt == startAt &&
      other.nextDueAt == nextDueAt &&
      other.endAt == endAt &&
      other.note == note &&
      other.archivedAt == archivedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        category,
        amountMinor,
        currency,
        frequency,
        intervalCount,
        dayOfMonth,
        startAt,
        nextDueAt,
        endAt,
        note,
        archivedAt,
        createdAt,
        updatedAt,
      );
}

/// One period of an [Obligation] — "September rent".
@immutable
class ObligationOccurrence {
  const ObligationOccurrence({
    required this.id,
    required this.obligationId,
    required this.periodKey,
    required this.dueAt,
    required this.amountMinor,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    this.paymentId,
  });

  final String id;
  final String obligationId;

  /// Stable identifier for the period, e.g. `2026-09` or `2026-W37`.
  final String periodKey;

  final DateTime dueAt;

  /// The amount for this period. Stored per occurrence so a price change does
  /// not rewrite what previous months cost.
  final int amountMinor;

  final ObligationStatus status;
  final DateTime? paidAt;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isPaid => status == ObligationStatus.paid;

  bool get isPayable =>
      status == ObligationStatus.upcoming ||
      status == ObligationStatus.dueToday ||
      status == ObligationStatus.overdue;

  ObligationOccurrence copyWith({
    DateTime? dueAt,
    int? amountMinor,
    ObligationStatus? status,
    Object? paidAt = _unset,
    Object? paymentId = _unset,
    DateTime? updatedAt,
  }) {
    return ObligationOccurrence(
      id: id,
      obligationId: obligationId,
      periodKey: periodKey,
      dueAt: dueAt ?? this.dueAt,
      amountMinor: amountMinor ?? this.amountMinor,
      status: status ?? this.status,
      paidAt: identical(paidAt, _unset) ? this.paidAt : paidAt as DateTime?,
      paymentId:
          identical(paymentId, _unset) ? this.paymentId : paymentId as String?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ObligationOccurrence &&
      other.id == id &&
      other.obligationId == obligationId &&
      other.periodKey == periodKey &&
      other.dueAt == dueAt &&
      other.amountMinor == amountMinor &&
      other.status == status &&
      other.paidAt == paidAt &&
      other.paymentId == paymentId &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        obligationId,
        periodKey,
        dueAt,
        amountMinor,
        status,
        paidAt,
        paymentId,
        createdAt,
        updatedAt,
      );
}

/// An occurrence together with the obligation it belongs to. This is what the
/// obligations list and the reminders screen actually render.
@immutable
class ObligationInstance {
  const ObligationInstance({required this.obligation, required this.occurrence});

  final Obligation obligation;
  final ObligationOccurrence occurrence;

  String get id => occurrence.id;

  DateTime get dueAt => occurrence.dueAt;

  Money get money => Money(occurrence.amountMinor, obligation.currency);

  /// Days until the due date; negative when late.
  int daysUntilDue(DateTime asOf) => daysBetween(asOf, occurrence.dueAt);
}

const Object _unset = Object();
