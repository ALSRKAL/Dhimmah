import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../enums/debt_enums.dart';
import '../enums/obligation_enums.dart';
import '../enums/recurrence.dart';

/// What the debt form collects.
///
/// A draft is the boundary between the form and the service: the form owns text
/// fields and validation messages, the service turns a valid draft into a
/// record. Nothing downstream has to guess whether a field meant "unchanged" or
/// "cleared".
@immutable
class DebtDraft {
  const DebtDraft({
    required this.direction,
    required this.principalMinor,
    required this.currency,
    required this.issuedAt,
    this.personIds = const <String>[],
    this.title = '',
    this.dueAt,
    this.note,
    this.reminderLeads = const <ReminderLead>[],
    this.recurrence = RecurrenceFrequency.none,
    this.recurrenceInterval = 1,
    this.recurrenceEndAt,
  });

  final DebtDirection direction;

  /// Everyone the record is with, in the order the user chose them.
  final List<String> personIds;

  final String title;
  final int principalMinor;
  final AppCurrency currency;
  final DateTime issuedAt;
  final DateTime? dueAt;
  final String? note;
  final List<ReminderLead> reminderLeads;
  final RecurrenceFrequency recurrence;
  final int recurrenceInterval;
  final DateTime? recurrenceEndAt;
}

/// What the person form collects.
@immutable
class PersonDraft {
  const PersonDraft({
    required this.name,
    this.phone,
    this.note,
    this.colorIndex = 0,
  });

  final String name;
  final String? phone;
  final String? note;
  final int colorIndex;
}

/// What the obligation form collects.
@immutable
class ObligationDraft {
  const ObligationDraft({
    required this.name,
    required this.category,
    required this.amountMinor,
    required this.currency,
    required this.frequency,
    required this.startAt,
    this.intervalCount = 1,
    this.dayOfMonth,
    this.endAt,
    this.note,
    this.reminderLeads = const <ReminderLead>[],
  });

  final String name;
  final ObligationCategory category;
  final int amountMinor;
  final AppCurrency currency;
  final RecurrenceFrequency frequency;
  final int intervalCount;
  final DateTime startAt;
  final int? dayOfMonth;
  final DateTime? endAt;
  final String? note;
  final List<ReminderLead> reminderLeads;
}

/// What the reminder form collects.
@immutable
class ReminderDraft {
  const ReminderDraft({
    required this.title,
    required this.dueAt,
    this.note,
    this.relatedType = RelatedEntityType.none,
    this.relatedId,
  });

  final String title;
  final DateTime dueAt;
  final String? note;
  final RelatedEntityType relatedType;
  final String? relatedId;
}

/// What the payment sheet collects.
@immutable
class PaymentDraft {
  const PaymentDraft({
    required this.amountMinor,
    required this.paidAt,
    this.note,
  });

  final int amountMinor;
  final DateTime paidAt;
  final String? note;
}
