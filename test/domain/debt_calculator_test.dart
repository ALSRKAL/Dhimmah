import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

/// Business rules for debts, exercised without a database or a widget.
void main() {
  final DateTime today = DateTime(2026, 9, 22);

  Debt debt({
    int principal = 500000,
    DateTime? dueAt,
    List<Payment> payments = const <Payment>[],
    DebtDirection direction = DebtDirection.iOwe,
    RecurrenceFrequency recurrence = RecurrenceFrequency.none,
    DateTime? archivedAt,
  }) {
    return Debt(
      id: 'd1',
      personIds: const <String>['p1'],
      direction: direction,
      title: '',
      principalMinor: principal,
      currency: AppCurrency.inr,
      issuedAt: DateTime(2026, 9),
      dueAt: dueAt,
      recurrence: recurrence,
      archivedAt: archivedAt,
      createdAt: DateTime(2026, 9),
      updatedAt: DateTime(2026, 9),
    );
  }

  Payment payment(int minor, DateTime paidAt, {String debtId = 'd1'}) {
    return Payment(
      id: 'pay-$minor-${paidAt.day}',
      debtId: debtId,
      amountMinor: minor,
      currency: AppCurrency.inr,
      paidAt: paidAt,
      createdAt: paidAt,
    );
  }

  group('remaining balance', () {
    test('is the principal before anything is paid', () {
      expect(DebtCalculator.remainingOf(500000, 0), 500000);
    });

    test('subtracts partial payments', () {
      expect(DebtCalculator.remainingOf(500000, 100000), 400000);
      expect(DebtCalculator.remainingOf(500000, 250000), 250000);
    });

    test('never goes below zero when overpaid', () {
      expect(DebtCalculator.remainingOf(500000, 600000), 0);
    });

    test('reports whether a payment would settle the debt', () {
      expect(
        DebtCalculator.wouldSettle(
          principalMinor: 100000,
          paidMinor: 60000,
          newPaymentMinor: 40000,
        ),
        isTrue,
      );
      expect(
        DebtCalculator.wouldSettle(
          principalMinor: 100000,
          paidMinor: 60000,
          newPaymentMinor: 39999,
        ),
        isFalse,
      );
    });
  });

  group('status resolution', () {
    DebtLifecycleStatus statusOf(Debt value, {int paid = 0}) =>
        DebtCalculator.resolveStatus(
          debt: value,
          remainingMinor: DebtCalculator.remainingOf(value.principalMinor, paid),
          asOf: today,
          dueSoonWindowDays: 7,
        );

    test('is paid once the balance reaches zero, even if past due', () {
      final Debt value = debt(dueAt: DateTime(2026, 9));
      expect(statusOf(value, paid: 500000), DebtLifecycleStatus.paid);
    });

    test('is overdue the day after the due date', () {
      expect(
        statusOf(debt(dueAt: DateTime(2026, 9, 21))),
        DebtLifecycleStatus.overdue,
      );
    });

    test('is due today on the due date itself', () {
      expect(
        statusOf(debt(dueAt: today)),
        DebtLifecycleStatus.dueToday,
      );
    });

    test('is due soon inside the window and upcoming outside it', () {
      expect(
        statusOf(debt(dueAt: addDays(today, 7))),
        DebtLifecycleStatus.dueSoon,
      );
      expect(
        statusOf(debt(dueAt: addDays(today, 8))),
        DebtLifecycleStatus.upcoming,
      );
    });

    test('is ongoing when no due date was set', () {
      expect(statusOf(debt()), DebtLifecycleStatus.active);
    });

    test('reports archived ahead of everything else', () {
      final Debt value = debt(dueAt: DateTime(2026), archivedAt: today);
      expect(statusOf(value), DebtLifecycleStatus.archived);
    });
  });

  group('views', () {
    test('sum the payment history and expose progress', () {
      final Debt value = debt(dueAt: addDays(today, 3));
      final List<Payment> history = <Payment>[
        payment(100000, DateTime(2026, 9, 10)),
        payment(150000, DateTime(2026, 9, 15)),
      ];
      final DebtView view = DebtCalculator.buildView(
        debt: value,
        payments: history,
        asOf: today,
        dueSoonWindowDays: 7,
      );

      expect(view.paidMinor, 250000);
      expect(view.remainingMinor, 250000);
      expect(view.progress, closeTo(0.5, 0.0001));
      expect(view.isPartiallyPaid, isTrue);
      expect(view.isSettled, isFalse);
      expect(view.paymentCount, 2);
      expect(view.lastPaymentAt, DateTime(2026, 9, 15));
    });

    test('sign the outstanding amount by direction', () {
      final DebtView ioOwe = DebtCalculator.buildView(
        debt: debt(),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      final DebtView owedToMe = DebtCalculator.buildView(
        debt: debt(direction: DebtDirection.owedToMe),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );

      expect(ioOwe.signedRemaining.minorUnits, -500000);
      expect(owedToMe.signedRemaining.minorUnits, 500000);
    });
  });

  group('currency totals', () {
    test('keep currencies apart and split the two directions', () {
      final List<DebtView> views = <DebtView>[
        DebtCalculator.buildView(
          debt: debt(principal: 100000, dueAt: DateTime(2026, 9, 10)),
          payments: const <Payment>[],
          asOf: today,
          dueSoonWindowDays: 7,
        ),
        DebtCalculator.buildView(
          debt: debt(
            principal: 250000,
            direction: DebtDirection.owedToMe,
            dueAt: addDays(today, 2),
          ),
          payments: const <Payment>[],
          asOf: today,
          dueSoonWindowDays: 7,
        ),
      ];

      final List<CurrencyTotals> totals = DebtCalculator.totalsByCurrency(
        views,
        asOf: today,
        dueSoonWindowDays: 7,
      );
      expect(totals, hasLength(1));
      expect(totals.first.iOweMinor, 100000);
      expect(totals.first.owedToMeMinor, 250000);
      expect(totals.first.overdueMinor, 100000);
      expect(totals.first.dueSoonMinor, 250000);
      expect(totals.first.net.minorUnits, 150000);
    });
  });

  group('filters', () {
    test('the default facet hides archived records', () {
      final DebtView view = DebtCalculator.buildView(
        debt: debt(archivedAt: today),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      expect(
        DebtCalculator.matchesFilter(
          view,
          DebtFilter.all,
          dueSoonWindowDays: 7,
        ),
        isFalse,
      );
      expect(
        DebtCalculator.matchesFilter(
          view,
          DebtFilter.archived,
          dueSoonWindowDays: 7,
        ),
        isTrue,
      );
    });

    test('partially paid excludes both untouched and settled records', () {
      final DebtView partial = DebtCalculator.buildView(
        debt: debt(principal: 100000),
        payments: <Payment>[payment(40000, DateTime(2026, 9, 5))],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      final DebtView untouched = DebtCalculator.buildView(
        debt: debt(principal: 100000),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      final DebtView settled = DebtCalculator.buildView(
        debt: debt(principal: 100000),
        payments: <Payment>[payment(100000, DateTime(2026, 9, 5))],
        asOf: today,
        dueSoonWindowDays: 7,
      );

      expect(
        DebtCalculator.matchesFilter(
          partial,
          DebtFilter.partiallyPaid,
          dueSoonWindowDays: 7,
        ),
        isTrue,
      );
      expect(
        DebtCalculator.matchesFilter(
          untouched,
          DebtFilter.partiallyPaid,
          dueSoonWindowDays: 7,
        ),
        isFalse,
      );
      expect(
        DebtCalculator.matchesFilter(
          settled,
          DebtFilter.partiallyPaid,
          dueSoonWindowDays: 7,
        ),
        isFalse,
      );
    });
  });

  group('sorting', () {
    test('puts records with no due date last when ordering by date', () {
      final DebtView withDate = DebtCalculator.buildView(
        debt: debt(dueAt: addDays(today, 10)),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      final DebtView withoutDate = DebtCalculator.buildView(
        debt: debt(),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );

      final List<DebtView> sorted = DebtCalculator.sort(
        <DebtView>[withoutDate, withDate],
        DebtSortOrder.dueDateSoonest,
        asOf: today,
      );
      expect(sorted.first, withDate);
      expect(sorted.last, withoutDate);
    });

    test('orders by remaining amount, not by principal', () {
      final DebtView biggerRemaining = DebtCalculator.buildView(
        debt: debt(principal: 1000000),
        payments: <Payment>[payment(900000, DateTime(2026, 9, 5))],
        asOf: today,
        dueSoonWindowDays: 7,
      );
      final DebtView smallerRemaining = DebtCalculator.buildView(
        debt: debt(principal: 200000),
        payments: const <Payment>[],
        asOf: today,
        dueSoonWindowDays: 7,
      );

      final List<DebtView> sorted = DebtCalculator.sort(
        <DebtView>[biggerRemaining, smallerRemaining],
        DebtSortOrder.amountHighest,
        asOf: today,
      );
      expect(sorted.first, smallerRemaining);
    });
  });

  group('recurring debts', () {
    test('find the next period after a given date', () {
      final Debt monthly = debt(
        dueAt: DateTime(2026, 1, 31),
        recurrence: RecurrenceFrequency.monthly,
      );
      // February clamps to the 28th, and March recovers the 31st.
      expect(monthly.nextOccurrenceAfter(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
      expect(monthly.nextOccurrenceAfter(DateTime(2026, 2, 28)), DateTime(2026, 3, 31));
    });

    test('respect a multi-period interval', () {
      final Debt quarterly = debt(
        dueAt: DateTime(2026, 1, 15),
        recurrence: RecurrenceFrequency.quarterly,
      );
      expect(
        quarterly.nextOccurrenceAfter(DateTime(2026, 1, 15)),
        DateTime(2026, 4, 15),
      );
    });
  });
}
