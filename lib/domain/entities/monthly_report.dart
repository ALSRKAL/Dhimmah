import 'package:meta/meta.dart';

import '../../core/money/currency.dart';

/// One month's numbers for one currency, ready for the report screen.
@immutable
class MonthlyReport {
  const MonthlyReport({
    required this.year,
    required this.month,
    required this.currency,
    required this.newDebtMinor,
    required this.receivedMinor,
    required this.paidOutMinor,
    required this.obligationsMinor,
    required this.overdueMinor,
    required this.openIOweMinor,
    required this.openOwedToMeMinor,
    required this.peopleCount,
    required this.closedDebts,
    required this.activeDebts,
    required this.trend,
    required this.generatedAt,
  });

  final int year;
  final int month;
  final AppCurrency currency;

  /// Debt principal added during the month, both directions.
  final int newDebtMinor;

  /// Money received from people who owed the user.
  final int receivedMinor;

  /// Money the user paid to people they owed.
  final int paidOutMinor;

  /// Obligation periods that fell due during the month.
  final int obligationsMinor;

  /// Still unpaid at the end of the month, both directions.
  final int overdueMinor;

  /// Position at the end of the month.
  final int openIOweMinor;
  final int openOwedToMeMinor;

  final int peopleCount;
  final int closedDebts;
  final int activeDebts;
  final List<MonthlyTrendPoint> trend;
  final DateTime generatedAt;

  /// Total money that moved during the month.
  int get settledMinor => receivedMinor + paidOutMinor;

  /// Whether the month has anything worth showing.
  bool get isEmpty =>
      newDebtMinor == 0 &&
      settledMinor == 0 &&
      obligationsMinor == 0 &&
      overdueMinor == 0 &&
      closedDebts == 0 &&
      activeDebts == 0;

  /// The month is in the future, so its numbers are projections rather than
  /// history.
  bool isFuture(DateTime asOf) =>
      DateTime(year, month).isAfter(DateTime(asOf.year, asOf.month));
}

/// One point on the report's trend chart.
@immutable
class MonthlyTrendPoint {
  const MonthlyTrendPoint({
    required this.year,
    required this.month,
    required this.settledMinor,
    required this.newDebtMinor,
    required this.obligationsMinor,
  });

  final int year;
  final int month;
  final int settledMinor;
  final int newDebtMinor;
  final int obligationsMinor;

  bool get isEmpty =>
      settledMinor == 0 && newDebtMinor == 0 && obligationsMinor == 0;
}
