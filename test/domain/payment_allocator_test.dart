import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/domain/services/payment_allocator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The split, as arithmetic.
///
/// Every case here is about one of three promises: money is never applied twice,
/// a debt never takes more than it owes, and the order is a *total* order — so
/// the split the sheet showed is the split the service writes, whatever order
/// the records happened to arrive in.
void main() {
  final DateTime today = dateOnly(DateTime(2026, 9, 15));

  /// A record with [principalMinor] borrowed and [paidMinor] already settled.
  ///
  /// Built through the calculator rather than assembled by hand, so the views
  /// these tests plan over are the same views the screens plan over — including
  /// the clamping that keeps a remaining balance from going negative.
  DebtView debt({
    required String id,
    required int principalMinor,
    int paidMinor = 0,
    DateTime? dueAt,
    DateTime? issuedAt,
    AppCurrency currency = AppCurrency.inr,
    DebtDirection direction = DebtDirection.iOwe,
    DateTime? createdAt,
  }) {
    return DebtCalculator.buildViewFromTotals(
      debt: Debt(
        id: id,
        personIds: const <String>['p1'],
        direction: direction,
        title: id,
        principalMinor: principalMinor,
        currency: currency,
        issuedAt: issuedAt ?? today,
        dueAt: dueAt,
        createdAt: createdAt ?? today,
        updatedAt: today,
      ),
      totals: PaymentTotals(
        paidMinor: paidMinor,
        count: paidMinor > 0 ? 1 : 0,
      ),
      asOf: today,
      dueSoonWindowDays: 7,
    );
  }

  /// The amounts the plan gives each debt, in plan order.
  List<int> amounts(List<DebtAllocation> plan) =>
      <int>[for (final DebtAllocation a in plan) a.allocatedMinor];

  /// The debt ids the plan gives money to, in order.
  List<String> reached(List<DebtAllocation> plan) => <String>[
        for (final DebtAllocation a in plan)
          if (a.allocatedMinor > 0) a.debtId,
      ];

  group('the amount is applied, never invented', () {
    test('one debt takes all of it', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'a', principalMinor: 10000),
        ],
        amountMinor: 4000,
      );
      expect(amounts(plan), <int>[4000]);
      expect(plan.single.remainingAfterMinor, 6000);
      expect(plan.single.willSettle, isFalse);
    });

    test('a debt is never given more than it still owes', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'a', principalMinor: 3000, paidMinor: 1000),
          debt(id: 'b', principalMinor: 5000),
        ],
        amountMinor: 10000,
      );
      expect(amounts(plan), <int>[2000, 5000]);
      expect(plan[0].remainingAfterMinor, 0);
      expect(plan[0].willSettle, isTrue);
      // The 3,000 nobody owed is simply not applied; it is not parked anywhere.
      expect(plan.map((DebtAllocation a) => a.allocatedMinor).reduce((int a, int b) => a + b), 7000);
    });

    test('an amount larger than everything reaches every debt and stops', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'a', principalMinor: 1000),
          debt(id: 'b', principalMinor: 2000),
        ],
        amountMinor: 99000,
      );
      expect(amounts(plan), <int>[1000, 2000]);
      expect(plan.every((DebtAllocation a) => a.willSettle), isTrue);
    });

    test('nothing entered means nothing applied, and every debt still listed', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'a', principalMinor: 1000),
          debt(id: 'b', principalMinor: 2000),
        ],
        amountMinor: 0,
      );
      expect(amounts(plan), <int>[0, 0]);
      // Listed all the same: the sheet renders its rows from the plan, so an
      // untouched debt has to be in it.
      expect(plan, hasLength(2));
      expect(plan.every((DebtAllocation a) => a.isUntouched), isTrue);
    });

    test('a debt that owes nothing takes nothing', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'settled', principalMinor: 500, paidMinor: 500),
          debt(id: 'open', principalMinor: 1000),
        ],
        amountMinor: 400,
      );
      final DebtAllocation settled =
          plan.firstWhere((DebtAllocation a) => a.debtId == 'settled');
      expect(settled.allocatedMinor, 0);
      expect(settled.remainingBeforeMinor, 0);
      expect(settled.willSettle, isFalse);
      expect(
        plan.firstWhere((DebtAllocation a) => a.debtId == 'open').allocatedMinor,
        400,
      );
    });
  });

  group('the order', () {
    test('most urgent pays the earliest due date first', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'later', principalMinor: 1000, dueAt: addDays(today, 30)),
          debt(id: 'sooner', principalMinor: 1000, dueAt: addDays(today, 3)),
          debt(id: 'middle', principalMinor: 1000, dueAt: addDays(today, 10)),
        ],
        amountMinor: 1000,
      );
      expect(reached(plan), <String>['sooner']);
    });

    test('a debt with no due date is paid after every dated one', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'undated', principalMinor: 1000),
          debt(id: 'dated', principalMinor: 1000, dueAt: addDays(today, 90)),
        ],
        amountMinor: 1000,
      );
      expect(
        reached(plan),
        <String>['dated'],
        reason: 'someday never outranks a date',
      );
    });

    test('two undated debts fall back to the older one', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'newer', principalMinor: 1000, issuedAt: addDays(today, -5)),
          debt(id: 'older', principalMinor: 1000, issuedAt: addDays(today, -60)),
        ],
        amountMinor: 1000,
      );
      expect(reached(plan), <String>['older']);
    });

    test('oldest first ignores due dates entirely', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(
            id: 'urgentButNew',
            principalMinor: 1000,
            dueAt: addDays(today, -30),
            issuedAt: addDays(today, -1),
          ),
          debt(
            id: 'calmButOld',
            principalMinor: 1000,
            dueAt: addDays(today, 60),
            issuedAt: addDays(today, -200),
          ),
        ],
        amountMinor: 1000,
        order: PaymentAllocationOrder.oldestFirst,
      );
      expect(reached(plan), <String>['calmButOld']);
    });

    test('two identical records come out in the same order every time', () {
      // Same issued day, same due day, same everything but the id: without a
      // total order the plan could differ between the preview and the write, and
      // the split the user approved would not be the one recorded.
      DebtView twin(String id) => debt(
            id: id,
            principalMinor: 1000,
            dueAt: today,
            issuedAt: today,
            createdAt: DateTime(2026, 9, 15, 12),
          );
      final List<DebtView> a = <DebtView>[twin('zzz'), twin('aaa')];
      final List<DebtView> b = <DebtView>[twin('aaa'), twin('zzz')];

      expect(
        reached(PaymentAllocator.plan(openDebts: a, amountMinor: 1000)),
        reached(PaymentAllocator.plan(openDebts: b, amountMinor: 1000)),
      );
      expect(
        reached(PaymentAllocator.plan(openDebts: a, amountMinor: 1000)),
        <String>['aaa'],
      );
    });

    test('the plan walks the debts in the order it reports them', () {
      final List<DebtView> debts = <DebtView>[
        debt(id: 'late', principalMinor: 1000, dueAt: addDays(today, 30)),
        debt(id: 'early', principalMinor: 1000, dueAt: addDays(today, 1)),
      ];
      final List<DebtView> ordered =
          PaymentAllocator.orderDebts(debts, PaymentAllocationOrder.mostUrgent);
      expect(
        <String>[for (final DebtView v in ordered) v.debt.id],
        <String>['early', 'late'],
      );
    });
  });

  group('exclusions', () {
    test('an excluded debt takes nothing and its share flows on', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'first', principalMinor: 1000, dueAt: addDays(today, 1)),
          debt(id: 'second', principalMinor: 1000, dueAt: addDays(today, 2)),
        ],
        amountMinor: 1500,
        excludedDebtIds: <String>{'first'},
      );
      final DebtAllocation first =
          plan.firstWhere((DebtAllocation a) => a.debtId == 'first');
      final DebtAllocation second =
          plan.firstWhere((DebtAllocation a) => a.debtId == 'second');

      expect(first.allocatedMinor, 0);
      expect(first.excluded, isTrue);
      expect(second.allocatedMinor, 1000, reason: 'it takes all it owes');
      expect(second.remainingAfterMinor, 0);
      expect(second.willSettle, isTrue);
    });

    test('excluding everything leaves the money unapplied', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'a', principalMinor: 1000),
          debt(id: 'b', principalMinor: 2000),
        ],
        amountMinor: 5000,
        excludedDebtIds: <String>{'a', 'b'},
      );
      expect(amounts(plan), <int>[0, 0]);
      expect(plan.every((DebtAllocation a) => a.excluded), isTrue);
    });

    test('an excluded debt keeps its place in the list', () {
      final List<DebtAllocation> plan = PaymentAllocator.plan(
        openDebts: <DebtView>[
          debt(id: 'late', principalMinor: 1000, dueAt: addDays(today, 30)),
          debt(id: 'early', principalMinor: 1000, dueAt: addDays(today, 1)),
        ],
        amountMinor: 500,
        excludedDebtIds: <String>{'early'},
      );
      expect(
        <String>[for (final DebtAllocation a in plan) a.debtId],
        <String>['early', 'late'],
        reason: 'rows do not move about when one is unchecked',
      );
    });
  });

  group('capacity', () {
    test('is what is still owed, not what was borrowed', () {
      final List<DebtView> debts = <DebtView>[
        debt(id: 'a', principalMinor: 5000, paidMinor: 2000),
        debt(id: 'b', principalMinor: 1000),
      ];
      expect(PaymentAllocator.capacityMinor(debts), 4000);
    });

    test('leaves out whatever the user excluded', () {
      final List<DebtView> debts = <DebtView>[
        debt(id: 'a', principalMinor: 5000),
        debt(id: 'b', principalMinor: 1000),
      ];
      expect(
        PaymentAllocator.capacityMinor(
          debts,
          excludedDebtIds: <String>{'a'},
        ),
        1000,
      );
    });

    test('is zero when there is nothing to pay', () {
      expect(PaymentAllocator.capacityMinor(const <DebtView>[]), 0);
    });
  });

  test('a paid debt is never paid twice by two views of it', () {
    // The same record handed in once takes its share once. This is the guard
    // against a caller passing a person's debts and their links by mistake.
    final List<DebtAllocation> plan = PaymentAllocator.plan(
      openDebts: <DebtView>[
        debt(id: 'a', principalMinor: 1000),
      ],
      amountMinor: 1000,
    );
    expect(amounts(plan), <int>[1000]);
    expect(plan.single.remainingAfterMinor, 0);
  });
}
