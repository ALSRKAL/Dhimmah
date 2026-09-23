import 'package:meta/meta.dart';

import '../../core/money/currency.dart';

/// The numbers behind one month's report, computed for one currency.
///
/// A month can involve several currencies; Dhimmah keeps one summary per
/// currency rather than pretending to add ﷼ to ₹.
@immutable
class MonthlySummary {
  const MonthlySummary({
    required this.year,
    required this.month,
    required this.currency,
    required this.newDebtMinor,
    required this.settledMinor,
    required this.receivedMinor,
    required this.paidOutMinor,
    required this.obligationsMinor,
    required this.overdueMinor,
    required this.peopleCount,
    required this.closedDebts,
    required this.activeDebts,
    required this.generatedAt,
  });

  final int year;
  final int month;
  final AppCurrency currency;

  /// Debt principal added during the month, both directions combined.
  final int newDebtMinor;

  /// Debt the user paid down during the month.
  final int settledMinor;

  /// Money received from people who owed the user.
  final int receivedMinor;

  /// Money the user paid to people they owed.
  final int paidOutMinor;

  /// Obligation periods that fell due during the month, at their period amount.
  final int obligationsMinor;

  /// Whatever was still unpaid at month end, in both directions.
  final int overdueMinor;

  final int peopleCount;
  final int closedDebts;
  final int activeDebts;
  final DateTime generatedAt;

  bool get isEmpty =>
      newDebtMinor == 0 &&
      settledMinor == 0 &&
      obligationsMinor == 0 &&
      overdueMinor == 0 &&
      closedDebts == 0 &&
      activeDebts == 0;

  @override
  bool operator ==(Object other) =>
      other is MonthlySummary &&
      other.year == year &&
      other.month == month &&
      other.currency == currency &&
      other.newDebtMinor == newDebtMinor &&
      other.settledMinor == settledMinor &&
      other.receivedMinor == receivedMinor &&
      other.paidOutMinor == paidOutMinor &&
      other.obligationsMinor == obligationsMinor &&
      other.overdueMinor == overdueMinor &&
      other.peopleCount == peopleCount &&
      other.closedDebts == closedDebts &&
      other.activeDebts == activeDebts;

  @override
  int get hashCode => Object.hash(
        year,
        month,
        currency,
        newDebtMinor,
        settledMinor,
        receivedMinor,
        paidOutMinor,
        obligationsMinor,
        overdueMinor,
        peopleCount,
        closedDebts,
        activeDebts,
      );
}
