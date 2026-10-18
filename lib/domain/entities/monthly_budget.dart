import 'package:meta/meta.dart';

import '../../core/money/currency.dart';

/// One month's income against that month's commitments, for one currency.
///
/// Derived on every read and never stored, for the reason the monthly report is
/// derived too: a saved "what is left" is a second source of truth, and it goes
/// wrong the first time a user edits a commitment in a month that already has a
/// figure against it. Nothing here is a running balance either — the app does
/// not hold a wallet, and this is not pretending to be one. It is the month's
/// schedule, added up.
@immutable
class MonthlyBudget {
  const MonthlyBudget({
    required this.year,
    required this.month,
    required this.currency,
    required this.incomeMinor,
    required this.obligationsMinor,
    required this.paidObligationsMinor,
    required this.overdueObligationsMinor,
    required this.incomeCount,
    required this.obligationCount,
  });

  /// An empty month, for a currency with nothing recorded in it.
  const MonthlyBudget.empty({
    required this.year,
    required this.month,
    required this.currency,
  })  : incomeMinor = 0,
        obligationsMinor = 0,
        paidObligationsMinor = 0,
        overdueObligationsMinor = 0,
        incomeCount = 0,
        obligationCount = 0;

  final int year;
  final int month;
  final AppCurrency currency;

  /// What the income schedules pay into this month.
  final int incomeMinor;

  /// Every period a commitment puts in this month — paid or not, excluding the
  /// ones the user skipped and the ones an archived commitment no longer owes.
  final int obligationsMinor;

  /// The part of [obligationsMinor] already settled.
  final int paidObligationsMinor;

  /// The part of [obligationsMinor] that is late. Already counted in the unpaid
  /// remainder; carried separately so the card can say which of the two problems
  /// the user has, being behind or merely committed.
  final int overdueObligationsMinor;

  final int incomeCount;
  final int obligationCount;

  /// Still to pay this month.
  int get unpaidObligationsMinor => obligationsMinor - paidObligationsMinor;

  /// What the month leaves of its income once its commitments are met.
  ///
  /// Negative when the commitments exceed the income, and that is the honest
  /// number: clamping it to zero would hide the one case the card exists to warn
  /// about.
  int get remainingMinor => incomeMinor - obligationsMinor;

  bool get hasIncome => incomeMinor > 0;

  bool get hasObligations => obligationsMinor > 0;

  /// Whether nothing at all is recorded for this currency this month.
  bool get isEmpty => incomeMinor == 0 && obligationsMinor == 0;

  /// Commitments exceed income.
  bool get isOverCommitted => obligationsMinor > incomeMinor;

  /// How far the commitments run past the income, as a positive amount.
  ///
  /// The card states the overage under a label that names it («تجاوز الدخل بـ»)
  /// rather than showing the negative remainder: "what is left" with a minus in
  /// front reads as a balance below zero, and a leading minus on an amount is
  /// the one thing the two scripts lay out differently.
  int get overMinor =>
      isOverCommitted ? obligationsMinor - incomeMinor : 0;

  /// The share of the income the month's commitments consume.
  ///
  /// Zero when nothing comes in: "all of nothing" is not a ratio, and a bar
  /// drawn at 100% or at infinity for someone with no income would be claiming a
  /// fact about a month that has no income in it.
  double get consumptionRatio =>
      incomeMinor <= 0 ? 0 : obligationsMinor / incomeMinor;

  /// The same ratio, capped at one, for drawing.
  ///
  /// The uncapped value is what the card reads out; a bar cannot be longer than
  /// the bar, so an over-committed month draws full and says so in words.
  double get consumptionRatioClamped {
    final double ratio = consumptionRatio;
    return ratio > 1 ? 1 : ratio;
  }

  @override
  bool operator ==(Object other) =>
      other is MonthlyBudget &&
      other.year == year &&
      other.month == month &&
      other.currency == currency &&
      other.incomeMinor == incomeMinor &&
      other.obligationsMinor == obligationsMinor &&
      other.paidObligationsMinor == paidObligationsMinor &&
      other.overdueObligationsMinor == overdueObligationsMinor &&
      other.incomeCount == incomeCount &&
      other.obligationCount == obligationCount;

  @override
  int get hashCode => Object.hash(
        year,
        month,
        currency,
        incomeMinor,
        obligationsMinor,
        paidObligationsMinor,
        overdueObligationsMinor,
        incomeCount,
        obligationCount,
      );
}
