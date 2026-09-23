import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../enums/debt_enums.dart';
import '../enums/recurrence.dart';

/// One debt: money the user owes, or money owed to the user.
///
/// The entity stores only what the user typed. Everything numeric that can be
/// derived — how much has been paid, what is left, whether it is late — is
/// computed from the linked payments by the domain services, so a balance can
/// never contradict its own payment history.
@immutable
class Debt {
  const Debt({
    required this.id,
    required this.direction,
    required this.title,
    required this.principalMinor,
    required this.currency,
    required this.issuedAt,
    required this.createdAt,
    required this.updatedAt,
    this.personId,
    this.dueAt,
    this.note,
    this.reminderLeads = const <ReminderLead>[],
    this.recurrence = RecurrenceFrequency.none,
    this.recurrenceInterval = 0,
    this.recurrenceEndAt,
    this.closedAt,
    this.archivedAt,
  });

  final String id;

  /// Null when the debt was recorded without linking a person.
  final String? personId;

  final DebtDirection direction;

  /// User-supplied label such as "سلفة" or "قرض سيارة". May be empty, in which
  /// case the UI shows the person's name instead.
  final String title;

  /// The original amount, as agreed. Never reduced by payments.
  final int principalMinor;

  final AppCurrency currency;

  /// The day the debt was taken on.
  final DateTime issuedAt;

  /// The day it should be settled by. Null means "no deadline".
  final DateTime? dueAt;

  final String? note;

  /// Lead times at which to remind the user. Empty means no reminder.
  final List<ReminderLead> reminderLeads;

  /// Whether the debt repeats. Recurring debts generate a follow-up record once
  /// settled.
  final RecurrenceFrequency recurrence;

  /// Interval in [recurrence] units; `0` means "every one period".
  final int recurrenceInterval;

  final DateTime? recurrenceEndAt;

  /// Set when the balance first reached zero.
  final DateTime? closedAt;

  final DateTime? archivedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isArchived => archivedAt != null;

  bool get isRecurring => recurrence.repeats;

  bool get hasDueDate => dueAt != null;

  /// Effective repeat interval, defaulting to every one period.
  int get effectiveInterval =>
      recurrenceInterval <= 0 ? 1 : recurrenceInterval;

  /// The date this debt is next due, if it has a schedule.
  DateTime? get nextDueAt => dueAt;

  /// The `n`-th period's due date, counted from the anchor.
  ///
  /// Every period is derived from the anchor rather than from its predecessor,
  /// which is what keeps "the 31st" the 31st: 31 January → 28 February →
  /// 31 March, instead of collapsing to the 28th for good.
  DateTime nthOccurrence(DateTime anchor, int n) {
    final int step = effectiveInterval * n;
    return switch (recurrence) {
      RecurrenceFrequency.weekly => addDays(anchor, 7 * step),
      RecurrenceFrequency.monthly => addMonths(anchor, step),
      RecurrenceFrequency.quarterly => addMonths(anchor, 3 * step),
      RecurrenceFrequency.yearly => addYears(anchor, step),
      RecurrenceFrequency.custom => addMonths(anchor, step),
      RecurrenceFrequency.none => anchor,
    };
  }

  /// The next period falling strictly after [from], or null once the schedule
  /// has ended.
  DateTime? nextOccurrenceAfter(DateTime from) {
    if (!isRecurring) return null;
    final DateTime anchor = dueAt ?? issuedAt;
    final DateTime want = dateOnly(from);
    final DateTime? end = recurrenceEndAt;
    for (int n = 1; n <= 600; n++) {
      final DateTime candidate = nthOccurrence(anchor, n);
      if (!candidate.isAfter(want)) continue;
      if (end != null && candidate.isAfter(dateOnly(end))) return null;
      return candidate;
    }
    return null;
  }

  Debt copyWith({
    Object? personId = _unset,
    DebtDirection? direction,
    String? title,
    int? principalMinor,
    AppCurrency? currency,
    DateTime? issuedAt,
    Object? dueAt = _unset,
    Object? note = _unset,
    List<ReminderLead>? reminderLeads,
    RecurrenceFrequency? recurrence,
    int? recurrenceInterval,
    Object? recurrenceEndAt = _unset,
    Object? closedAt = _unset,
    Object? archivedAt = _unset,
    DateTime? updatedAt,
  }) {
    return Debt(
      id: id,
      personId:
          identical(personId, _unset) ? this.personId : personId as String?,
      direction: direction ?? this.direction,
      title: title ?? this.title,
      principalMinor: principalMinor ?? this.principalMinor,
      currency: currency ?? this.currency,
      issuedAt: issuedAt ?? this.issuedAt,
      dueAt: identical(dueAt, _unset) ? this.dueAt : dueAt as DateTime?,
      note: identical(note, _unset) ? this.note : note as String?,
      reminderLeads: reminderLeads ?? this.reminderLeads,
      recurrence: recurrence ?? this.recurrence,
      recurrenceInterval: recurrenceInterval ?? this.recurrenceInterval,
      recurrenceEndAt: identical(recurrenceEndAt, _unset)
          ? this.recurrenceEndAt
          : recurrenceEndAt as DateTime?,
      closedAt: identical(closedAt, _unset) ? this.closedAt : closedAt as DateTime?,
      archivedAt:
          identical(archivedAt, _unset) ? this.archivedAt : archivedAt as DateTime?,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Debt &&
      other.id == id &&
      other.personId == personId &&
      other.direction == direction &&
      other.title == title &&
      other.principalMinor == principalMinor &&
      other.currency == currency &&
      other.issuedAt == issuedAt &&
      other.dueAt == dueAt &&
      other.note == note &&
      _sameLeads(other.reminderLeads, reminderLeads) &&
      other.recurrence == recurrence &&
      other.recurrenceInterval == recurrenceInterval &&
      other.recurrenceEndAt == recurrenceEndAt &&
      other.closedAt == closedAt &&
      other.archivedAt == archivedAt &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
        id,
        personId,
        direction,
        title,
        principalMinor,
        currency,
        issuedAt,
        dueAt,
        note,
        Object.hashAll(reminderLeads),
        recurrence,
        recurrenceInterval,
        recurrenceEndAt,
        closedAt,
        archivedAt,
        createdAt,
        updatedAt,
      );

  static bool _sameLeads(List<ReminderLead> a, List<ReminderLead> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const Object _unset = Object();
