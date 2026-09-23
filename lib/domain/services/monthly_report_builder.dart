import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../entities/debt.dart';
import '../entities/monthly_report.dart';
import '../entities/obligation.dart';
import '../entities/payment.dart';
import '../enums/debt_enums.dart';
import '../enums/obligation_enums.dart';

/// Computes a month's report from raw records.
///
/// Everything is derived from debts, payments and obligation periods — never
/// from a running total kept in a column — so a report can always be rebuilt
/// and will always agree with the records it came from. Amounts in a currency
/// other than [currency] are ignored rather than converted.
MonthlyReport buildMonthlyReport({
  required int year,
  required int month,
  required AppCurrency currency,
  required List<Debt> debts,
  required List<Payment> payments,
  required List<Obligation> obligations,
  required List<ObligationOccurrence> occurrences,
  required int peopleCount,
  required DateTime asOf,
  int trendMonths = 6,
}) {
  final DateTime monthStart = DateTime(year, month);
  final DateTime monthEnd = endOfMonth(monthStart);

  // Direction lookup so a payment can be attributed to money in or money out.
  final Map<String, DebtDirection> directionOfDebt = <String, DebtDirection>{
    for (final Debt debt in debts) debt.id: debt.direction,
  };

  int newDebtMinor = 0;
  int closedDebts = 0;
  for (final Debt debt in debts) {
    if (debt.currency != currency) continue;
    if (isWithin(debt.issuedAt, monthStart, monthEnd)) {
      newDebtMinor += debt.principalMinor;
    }
    final DateTime? closedAt = debt.closedAt;
    if (closedAt != null && isWithin(closedAt, monthStart, monthEnd)) {
      closedDebts++;
    }
  }

  int receivedMinor = 0;
  int paidOutMinor = 0;
  for (final Payment payment in payments) {
    if (payment.currency != currency) continue;
    if (!isWithin(payment.paidAt, monthStart, monthEnd)) continue;
    final DebtDirection? direction = directionOfDebt[payment.debtId];
    if (direction == null) continue;
    if (direction.isOwedToMe) {
      receivedMinor += payment.amountMinor;
    } else {
      paidOutMinor += payment.amountMinor;
    }
  }

  final Set<String> obligationIdsInCurrency = <String>{
    for (final Obligation obligation in obligations)
      if (obligation.currency == currency) obligation.id,
  };
  int obligationsMinor = 0;
  for (final ObligationOccurrence occurrence in occurrences) {
    if (!obligationIdsInCurrency.contains(occurrence.obligationId)) continue;
    if (occurrence.status == ObligationStatus.cancelled) continue;
    if (!isWithin(occurrence.dueAt, monthStart, monthEnd)) continue;
    obligationsMinor += occurrence.amountMinor;
  }

  // Position at the end of the month: what was still open then.
  int paidByDebt(Payment payment) => payment.amountMinor;
  final Map<String, int> paidTotals = <String, int>{};
  for (final Payment payment in payments) {
    final String? debtId = payment.debtId;
    if (debtId == null) continue;
    paidTotals[debtId] = (paidTotals[debtId] ?? 0) + paidByDebt(payment);
  }

  // "Overdue" must mean the same thing everywhere in the app. For a month that
  // has already ended, that is "still unpaid at month end"; for the month in
  // progress it is "still unpaid today". Without this clamp, a debt due in three
  // days would be reported as overdue simply because it falls inside the month.
  final DateTime overdueCutoff = monthEnd.isBefore(asOf) ? monthEnd : asOf;

  int openIOweMinor = 0;
  int openOwedToMeMinor = 0;
  int overdueMinor = 0;
  int activeDebts = 0;
  for (final Debt debt in debts) {
    if (debt.currency != currency) continue;
    if (debt.archivedAt != null) {
      final DateTime archivedAt = debt.archivedAt!;
      if (archivedAt.isBefore(monthStart) || isWithin(archivedAt, monthStart, monthEnd)) {
        continue;
      }
    }
    if (debt.issuedAt.isAfter(monthEnd)) continue;

    final int remaining =
        (debt.principalMinor - (paidTotals[debt.id] ?? 0)).clamp(0, 1 << 62);
    if (remaining > 0) activeDebts++;
    if (debt.direction.isIOwe) {
      openIOweMinor += remaining;
    } else {
      openOwedToMeMinor += remaining;
    }
    final DateTime? due = debt.dueAt;
    if (remaining > 0 && due != null && due.isBefore(overdueCutoff)) {
      overdueMinor += remaining;
    }
  }

  return MonthlyReport(
    year: year,
    month: month,
    currency: currency,
    newDebtMinor: newDebtMinor,
    receivedMinor: receivedMinor,
    paidOutMinor: paidOutMinor,
    obligationsMinor: obligationsMinor,
    overdueMinor: overdueMinor,
    openIOweMinor: openIOweMinor,
    openOwedToMeMinor: openOwedToMeMinor,
    peopleCount: peopleCount,
    closedDebts: closedDebts,
    activeDebts: activeDebts,
    trend: buildTrend(
      endYear: year,
      endMonth: month,
      currency: currency,
      debts: debts,
      payments: payments,
      obligations: obligations,
      occurrences: occurrences,
      months: trendMonths,
    ),
    generatedAt: asOf,
  );
}

/// What the month's numbers add up to, in one sentence.
///
/// The insight is derived from the report's own figures and nothing else: it
/// states the most useful true thing about the month, or says the month is
/// quiet. It never speculates, and it never refers to anything the user did not
/// record — which is the only way a summary line stays worth reading.
enum MonthlyInsight { overdue, upcomingSoon, manyClosed, allClear, quiet }

/// Chooses the insight for a month.
///
/// Priority follows what the user can act on: money that is already late, then
/// money about to fall due, then what the month achieved.
MonthlyInsight monthlyInsightFor(
  MonthlyReport report, {
  required int overdueCount,
  required int dueSoonCount,
  required bool isCurrentMonth,
}) {
  if (!isCurrentMonth) {
    if (report.closedDebts >= 3) return MonthlyInsight.manyClosed;
    if (report.isEmpty) return MonthlyInsight.quiet;
    if (report.overdueMinor > 0) return MonthlyInsight.overdue;
    return MonthlyInsight.allClear;
  }
  if (overdueCount > 0) return MonthlyInsight.overdue;
  if (dueSoonCount > 0) return MonthlyInsight.upcomingSoon;
  if (report.closedDebts >= 3) return MonthlyInsight.manyClosed;
  if (report.isEmpty) return MonthlyInsight.quiet;
  return MonthlyInsight.allClear;
}

/// The last [months] months ending at the given month, oldest first.
List<MonthlyTrendPoint> buildTrend({
  required int endYear,
  required int endMonth,
  required AppCurrency currency,
  required List<Debt> debts,
  required List<Payment> payments,
  required List<Obligation> obligations,
  required List<ObligationOccurrence> occurrences,
  required int months,
}) {
  final Map<String, DebtDirection> directionOfDebt = <String, DebtDirection>{
    for (final Debt debt in debts) debt.id: debt.direction,
  };
  final Set<String> obligationIdsInCurrency = <String>{
    for (final Obligation obligation in obligations)
      if (obligation.currency == currency) obligation.id,
  };

  final List<MonthlyTrendPoint> points = <MonthlyTrendPoint>[];
  final DateTime end = DateTime(endYear, endMonth);
  for (int back = months - 1; back >= 0; back--) {
    final DateTime cursor = addMonths(end, -back);
    final DateTime start = DateTime(cursor.year, cursor.month);
    final DateTime stop = endOfMonth(start);

    int settled = 0;
    for (final Payment payment in payments) {
      if (payment.currency != currency) continue;
      if (!isWithin(payment.paidAt, start, stop)) continue;
      if (!directionOfDebt.containsKey(payment.debtId)) continue;
      settled += payment.amountMinor;
    }

    int newDebt = 0;
    for (final Debt debt in debts) {
      if (debt.currency != currency) continue;
      if (isWithin(debt.issuedAt, start, stop)) newDebt += debt.principalMinor;
    }

    int obligationsTotal = 0;
    for (final ObligationOccurrence occurrence in occurrences) {
      if (!obligationIdsInCurrency.contains(occurrence.obligationId)) continue;
      if (occurrence.status == ObligationStatus.cancelled) continue;
      if (isWithin(occurrence.dueAt, start, stop)) {
        obligationsTotal += occurrence.amountMinor;
      }
    }

    points.add(
      MonthlyTrendPoint(
        year: cursor.year,
        month: cursor.month,
        settledMinor: settled,
        newDebtMinor: newDebt,
        obligationsMinor: obligationsTotal,
      ),
    );
  }
  return points;
}
