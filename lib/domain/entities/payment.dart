import 'package:meta/meta.dart';

import '../../core/money/currency.dart';

/// A payment recorded against a debt or a single obligation occurrence.
///
/// Payments are append-only records. Editing a debt's amount never rewrites
/// history, and deleting a payment restores the balance it had before.
@immutable
class Payment {
  const Payment({
    required this.id,
    required this.amountMinor,
    required this.currency,
    required this.paidAt,
    required this.createdAt,
    this.debtId,
    this.obligationId,
    this.occurrenceId,
    this.personId,
    this.note,
  });

  final String id;

  /// Set when the payment settles a debt. Mutually exclusive with
  /// [occurrenceId].
  final String? debtId;

  /// Set when the payment settles a recurring obligation. Kept alongside
  /// [occurrenceId] so "everything ever paid for this obligation" is one query.
  final String? obligationId;

  /// The specific period that was settled.
  final String? occurrenceId;

  /// Denormalised link to the person, so a person's timeline does not need a
  /// join through debts.
  final String? personId;

  final int amountMinor;
  final AppCurrency currency;

  /// The day the money changed hands.
  final DateTime paidAt;

  final String? note;
  final DateTime createdAt;

  bool get isDebtPayment => debtId != null;

  bool get isObligationPayment => occurrenceId != null || obligationId != null;

  Payment copyWith({
    int? amountMinor,
    AppCurrency? currency,
    DateTime? paidAt,
    Object? note = _unset,
    Object? debtId = _unset,
    Object? obligationId = _unset,
    Object? occurrenceId = _unset,
    Object? personId = _unset,
  }) {
    return Payment(
      id: id,
      debtId: identical(debtId, _unset) ? this.debtId : debtId as String?,
      obligationId: identical(obligationId, _unset)
          ? this.obligationId
          : obligationId as String?,
      occurrenceId: identical(occurrenceId, _unset)
          ? this.occurrenceId
          : occurrenceId as String?,
      personId: identical(personId, _unset) ? this.personId : personId as String?,
      amountMinor: amountMinor ?? this.amountMinor,
      currency: currency ?? this.currency,
      paidAt: paidAt ?? this.paidAt,
      note: identical(note, _unset) ? this.note : note as String?,
      createdAt: createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Payment &&
      other.id == id &&
      other.debtId == debtId &&
      other.obligationId == obligationId &&
      other.occurrenceId == occurrenceId &&
      other.personId == personId &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.paidAt == paidAt &&
      other.note == note &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        id,
        debtId,
        obligationId,
        occurrenceId,
        personId,
        amountMinor,
        currency,
        paidAt,
        note,
        createdAt,
      );
}

const Object _unset = Object();
