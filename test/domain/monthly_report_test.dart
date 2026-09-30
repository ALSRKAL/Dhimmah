import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/monthly_report_builder.dart';
import 'package:flutter_test/flutter_test.dart';

/// What a month's report says about that month — and only that month.
void main() {
  final DateTime created = DateTime(2026, 7);

  Debt debt({
    required String id,
    required DateTime issuedAt,
    DateTime? dueAt,
    int principalMinor = 100000,
  }) =>
      Debt(
        id: id,
        direction: DebtDirection.owedToMe,
        title: '',
        principalMinor: principalMinor,
        currency: AppCurrency.inr,
        issuedAt: issuedAt,
        dueAt: dueAt,
        createdAt: created,
        updatedAt: created,
      );

  Payment payment(String debtId, int amountMinor, DateTime paidAt) => Payment(
        id: 'p-$debtId-${paidAt.toIso8601String()}',
        debtId: debtId,
        amountMinor: amountMinor,
        currency: AppCurrency.inr,
        paidAt: paidAt,
        createdAt: paidAt,
      );

  Obligation rent({DateTime? archivedAt}) => Obligation(
        id: 'rent',
        name: 'إيجار',
        category: ObligationCategory.housing,
        amountMinor: 200000,
        currency: AppCurrency.inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(2026, 7),
        nextDueAt: DateTime(2026, 7),
        dayOfMonth: 1,
        archivedAt: archivedAt,
        createdAt: created,
        updatedAt: created,
      );

  ObligationOccurrence period(int month, ObligationStatus status) =>
      ObligationOccurrence(
        id: 'rent-$month',
        obligationId: 'rent',
        periodKey: '2026-${month.toString().padLeft(2, '0')}',
        dueAt: DateTime(2026, month),
        amountMinor: 200000,
        status: status,
        createdAt: created,
        updatedAt: created,
      );

  MonthlyReport report(
    int month, {
    List<Debt> debts = const <Debt>[],
    List<Payment> payments = const <Payment>[],
    List<Obligation> obligations = const <Obligation>[],
    List<ObligationOccurrence> occurrences = const <ObligationOccurrence>[],
    DateTime? asOf,
  }) =>
      buildMonthlyReport(
        year: 2026,
        month: month,
        currency: AppCurrency.inr,
        debts: debts,
        payments: payments,
        obligations: obligations,
        occurrences: occurrences,
        peopleCount: 1,
        asOf: asOf ?? DateTime(2026, 9, 20),
      );

  group('a month that has ended', () {
    // Due in August, unpaid all August, paid on 5 September. August's report
    // used to subtract the September payment and say nothing was ever open.
    final Debt late = debt(
      id: 'd1',
      issuedAt: DateTime(2026, 8),
      dueAt: DateTime(2026, 8, 10),
    );
    final Payment paidLater = payment('d1', 100000, DateTime(2026, 9, 5));

    test('still shows what was open and late at its end', () {
      final MonthlyReport august =
          report(8, debts: <Debt>[late], payments: <Payment>[paidLater]);

      expect(august.openOwedToMeMinor, 100000);
      expect(august.overdueMinor, 100000);
      expect(august.activeDebts, 1);
    });

    test('and the month the payment was made in shows it settled', () {
      final MonthlyReport september =
          report(9, debts: <Debt>[late], payments: <Payment>[paidLater]);

      expect(september.openOwedToMeMinor, 0);
      expect(september.overdueMinor, 0);
      expect(september.receivedMinor, 100000);
    });

    test('a payment on the last day of the month counts in that month', () {
      final MonthlyReport august = report(
        8,
        debts: <Debt>[late],
        payments: <Payment>[payment('d1', 100000, DateTime(2026, 8, 31))],
      );
      expect(august.openOwedToMeMinor, 0);
      expect(august.overdueMinor, 0);
    });
  });

  group('commitment periods', () {
    test('a skipped period is not money due, in the month or its trend', () {
      final MonthlyReport august = report(
        8,
        obligations: <Obligation>[rent()],
        occurrences: <ObligationOccurrence>[
          period(7, ObligationStatus.paid),
          period(8, ObligationStatus.skipped),
        ],
      );

      expect(august.obligationsMinor, 0);
      final MonthlyTrendPoint augustPoint = august.trend
          .firstWhere((MonthlyTrendPoint p) => p.month == 8);
      final MonthlyTrendPoint julyPoint = august.trend
          .firstWhere((MonthlyTrendPoint p) => p.month == 7);
      expect(augustPoint.obligationsMinor, 0);
      expect(julyPoint.obligationsMinor, 200000);
    });

    test('an archived commitment keeps its history and stops being due', () {
      // Paid in July, archived on 15 August: July happened, September did not.
      final Obligation archived = rent(archivedAt: DateTime(2026, 8, 15, 9));
      final List<ObligationOccurrence> periods = <ObligationOccurrence>[
        period(7, ObligationStatus.paid),
        period(8, ObligationStatus.upcoming),
        period(9, ObligationStatus.upcoming),
      ];

      expect(
        report(7, obligations: <Obligation>[archived], occurrences: periods)
            .obligationsMinor,
        200000,
      );
      expect(
        report(8, obligations: <Obligation>[archived], occurrences: periods)
            .obligationsMinor,
        200000,
        reason: 'due on 1 August, before it was set aside',
      );
      expect(
        report(9, obligations: <Obligation>[archived], occurrences: periods)
            .obligationsMinor,
        0,
      );
    });
  });
}
