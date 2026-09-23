import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/attention_list.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/domain/services/monthly_report_builder.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The rules behind the dashboard's attention list, the monthly insight and the
/// statement's history.
void main() {
  final DateTime today = DateTime(2026, 9, 22);

  Debt debt({
    required String id,
    int principal = 1000000,
    DateTime? dueAt,
    DebtDirection direction = DebtDirection.iOwe,
    String? personId,
  }) {
    return Debt(
      id: id,
      personId: personId,
      direction: direction,
      title: '',
      principalMinor: principal,
      currency: AppCurrency.inr,
      issuedAt: addDays(today, -30),
      dueAt: dueAt,
      createdAt: addDays(today, -30),
      updatedAt: addDays(today, -30),
    );
  }

  DebtView view(Debt value, {List<Payment> payments = const <Payment>[]}) {
    return DebtCalculator.buildView(
      debt: value,
      payments: payments,
      asOf: today,
      dueSoonWindowDays: 7,
    );
  }

  ObligationInstance obligationInstance({
    required String id,
    required DateTime dueAt,
    int amountMinor = 200000,
  }) {
    final Obligation obligation = Obligation(
      id: id,
      name: 'إيجار',
      category: ObligationCategory.housing,
      amountMinor: amountMinor,
      currency: AppCurrency.inr,
      frequency: RecurrenceFrequency.monthly,
      startAt: dueAt,
      nextDueAt: dueAt,
      createdAt: dueAt,
      updatedAt: dueAt,
    );
    return ObligationInstance(
      obligation: obligation,
      occurrence: ObligationOccurrence(
        id: '$id-occ',
        obligationId: id,
        periodKey: monthKey(dueAt),
        dueAt: dueAt,
        amountMinor: amountMinor,
        status: ObligationStatus.upcoming,
        createdAt: dueAt,
        updatedAt: dueAt,
      ),
    );
  }

  group('attention list', () {
    test('is empty when nothing is close to its deadline', () {
      final List<AttentionItem> items = AttentionList.build(
        debts: <DebtView>[view(debt(id: 'd1', dueAt: addDays(today, 60)))],
        obligations: const <ObligationInstance>[],
        asOf: today,
      );
      expect(items, isEmpty);
    });

    test('ignores settled and archived records', () {
      final DebtView settled = view(
        debt(id: 'd1', dueAt: addDays(today, -1), principal: 500000),
        payments: <Payment>[
          Payment(
            id: 'p1',
            debtId: 'd1',
            amountMinor: 500000,
            currency: AppCurrency.inr,
            paidAt: today,
            createdAt: today,
          ),
        ],
      );
      final List<AttentionItem> items = AttentionList.build(
        debts: <DebtView>[
          settled,
          view(debt(id: 'd2', dueAt: addDays(today, -1))),
        ],
        obligations: const <ObligationInstance>[],
        asOf: today,
      );
      // d1 is settled, so only d2 still asks for attention.
      expect(items, hasLength(1));
      expect(items.single.debtId, 'd2');
    });

    test('orders late before today before soon', () {
      final List<AttentionItem> items = AttentionList.build(
        debts: <DebtView>[
          view(debt(id: 'soon', dueAt: addDays(today, 5))),
          view(debt(id: 'late', dueAt: addDays(today, -3))),
          view(debt(id: 'now', dueAt: today)),
        ],
        obligations: const <ObligationInstance>[],
        asOf: today,
      );
      expect(
        items.map((AttentionItem i) => i.debtId).toList(),
        <String>['late', 'now', 'soon'],
      );
      expect(items.first.reason, AttentionReason.overdue);
      expect(items.first.daysUntilDue, -3);
    });

    test('includes obligations on the same footing as debts', () {
      final List<AttentionItem> items = AttentionList.build(
        debts: <DebtView>[],
        obligations: <ObligationInstance>[
          obligationInstance(id: 'o1', dueAt: addDays(today, -1)),
        ],
        asOf: today,
      );
      expect(items, hasLength(1));
      expect(items.single.isObligation, isTrue);
      expect(items.single.reason, AttentionReason.overdue);
      // An obligation has no direction: it is money going out.
      expect(items.single.direction, isNull);
    });

    test('lists a weekly commitment once, not once per unpaid period', () {
      final List<AttentionItem> items = AttentionList.build(
        debts: const <DebtView>[],
        obligations: <ObligationInstance>[
          obligationInstance(id: 'o1', dueAt: addDays(today, -2)),
          obligationInstance(id: 'o1', dueAt: addDays(today, 5)),
          obligationInstance(id: 'o1', dueAt: addDays(today, 12)),
        ],
        asOf: today,
      );
      expect(items, hasLength(1));
      // The oldest unpaid period is the one to act on.
      expect(items.single.daysUntilDue, -2);
    });

    test('respects the due-soon window', () {
      final List<DebtView> debts = <DebtView>[
        view(debt(id: 'd1', dueAt: addDays(today, 10))),
      ];
      expect(
        AttentionList.build(debts: debts, obligations: const [], asOf: today),
        isEmpty,
      );
      expect(
        AttentionList.build(
          debts: debts,
          obligations: const [],
          asOf: today,
          windowDays: 14,
        ),
        hasLength(1),
      );
    });

    test('caps the list so the dashboard stays scannable', () {
      final List<DebtView> debts = <DebtView>[
        for (int i = 0; i < 12; i++)
          view(debt(id: 'd$i', dueAt: addDays(today, -i - 1))),
      ];
      final List<AttentionItem> items =
          AttentionList.build(debts: debts, obligations: const [], asOf: today);
      expect(items, hasLength(5));
    });
  });

  group('monthly insight', () {
    MonthlyReport report({
      int closed = 0,
      int overdue = 0,
      int settled = 0,
    }) {
      return MonthlyReport(
        year: today.year,
        month: today.month,
        currency: AppCurrency.inr,
        newDebtMinor: 0,
        receivedMinor: 0,
        paidOutMinor: settled,
        obligationsMinor: 0,
        overdueMinor: overdue,
        openIOweMinor: 0,
        openOwedToMeMinor: 0,
        peopleCount: 0,
        closedDebts: closed,
        activeDebts: 0,
        trend: const <MonthlyTrendPoint>[],
        generatedAt: today,
      );
    }

    test('leads with what is late when anything is', () {
      expect(
        monthlyInsightFor(
          report(overdue: 100000, settled: 50000),
          overdueCount: 2,
          dueSoonCount: 1,
          isCurrentMonth: true,
        ),
        MonthlyInsight.overdue,
      );
    });

    test('then with what is coming up', () {
      expect(
        monthlyInsightFor(
          report(settled: 50000),
          overdueCount: 0,
          dueSoonCount: 3,
          isCurrentMonth: true,
        ),
        MonthlyInsight.upcomingSoon,
      );
    });

    test('celebrates a month that closed several debts', () {
      expect(
        monthlyInsightFor(
          report(closed: 4, settled: 100000),
          overdueCount: 0,
          dueSoonCount: 0,
          isCurrentMonth: true,
        ),
        MonthlyInsight.manyClosed,
      );
    });

    test('says so when the month is quiet', () {
      expect(
        monthlyInsightFor(
          report(),
          overdueCount: 0,
          dueSoonCount: 0,
          isCurrentMonth: true,
        ),
        MonthlyInsight.quiet,
      );
    });

    test('a past month reports what it achieved, not what is due now', () {
      // Nothing can be "due soon" in a month that has already ended.
      expect(
        monthlyInsightFor(
          report(settled: 200000),
          overdueCount: 5,
          dueSoonCount: 5,
          isCurrentMonth: false,
        ),
        MonthlyInsight.allClear,
      );
    });
  });

  group('statement history', () {
    Payment payment(String id, int minor, DateTime at, {String debtId = 'd1'}) =>
        Payment(
          id: id,
          debtId: debtId,
          amountMinor: minor,
          currency: AppCurrency.inr,
          paidAt: at,
          createdAt: at,
        );

    test('runs the balance down from the debt to zero', () {
      final List<Debt> debts = <Debt>[
        debt(id: 'd1', dueAt: addDays(today, 10)),
      ];
      final List<Payment> payments = <Payment>[
        payment('p1', 400000, addDays(today, -10)),
        payment('p2', 600000, addDays(today, -2)),
      ];

      final List<StatementEntry> entries = buildStatementEntries(
        debts: debts,
        payments: payments,
        currency: AppCurrency.inr,
      );

      // One line for the debt, one per payment. The balance column ends at
      // zero, which is what tells the reader it is settled.
      expect(entries, hasLength(3));
      expect(entries[0].kind, StatementEntryKind.debtCreated);
      expect(entries[0].balanceAfterMinor, 1000000);
      expect(entries[1].kind, StatementEntryKind.payment);
      expect(entries[1].balanceAfterMinor, 600000);
      expect(entries[2].kind, StatementEntryKind.payment);
      expect(entries[2].balanceAfterMinor, 0);
    });

    test('the final balance is zero once a debt is paid off', () {
      final List<StatementEntry> entries = buildStatementEntries(
        debts: <Debt>[debt(id: 'd1', principal: 500000)],
        payments: <Payment>[payment('p1', 500000, addDays(today, -1))],
        currency: AppCurrency.inr,
      );
      expect(entries.last.kind, StatementEntryKind.payment);
      expect(entries.last.balanceAfterMinor, 0);
    });

    test('never shows a negative balance when a debt is overpaid', () {
      final List<StatementEntry> entries = buildStatementEntries(
        debts: <Debt>[debt(id: 'd1', principal: 500000)],
        payments: <Payment>[payment('p1', 700000, addDays(today, -1))],
        currency: AppCurrency.inr,
      );
      expect(entries.every((StatementEntry e) => e.balanceAfterMinor >= 0), isTrue);
    });

    test('keeps currencies apart', () {
      final List<StatementEntry> entries = buildStatementEntries(
        debts: <Debt>[
          debt(id: 'd1'),
          Debt(
            id: 'd2',
            direction: DebtDirection.owedToMe,
            title: '',
            principalMinor: 500000,
            currency: AppCurrency.usd,
            issuedAt: today,
            createdAt: today,
            updatedAt: today,
          ),
        ],
        payments: const <Payment>[],
        currency: AppCurrency.inr,
      );
      expect(entries, hasLength(1));
      expect(entries.single.amountMinor, 1000000);
    });

    test('a debt with no payments still produces a statement', () {
      final List<StatementEntry> entries = buildStatementEntries(
        debts: <Debt>[debt(id: 'd1', principal: 250000)],
        payments: const <Payment>[],
        currency: AppCurrency.inr,
      );
      // The debt itself is a row: a statement for an untouched debt is still a
      // statement, and it shows the balance the user started from.
      expect(entries, hasLength(1));
      expect(entries.single.kind, StatementEntryKind.debtCreated);
      expect(entries.single.balanceAfterMinor, 250000);
    });
  });

  group('statement naming', () {
    test('keeps a readable name and drops path separators', () {
      expect(
        StatementData.sanitiseFileName('Ahmed Mohammed'),
        'Ahmed_Mohammed',
      );
      expect(StatementData.sanitiseFileName('a/b:c*d?'), 'a_b_c_d');
      expect(StatementData.sanitiseFileName('  '), 'Statement');
      // Arabic names are kept: the filesystem handles them.
      expect(StatementData.sanitiseFileName('أحمد محمد'), 'أحمد_محمد');
    });

    test('the file name carries the person and the date', () {
      final StatementData data = StatementData(
        documentNumber: 'DHM-2026-1234',
        documentId: 'ABCDEF',
        generatedAt: DateTime(2026, 9, 22),
        language: AppLanguage.arabic,
        personName: 'أحمد محمد',
        phone: null,
        currency: AppCurrency.inr,
        totalMinor: 0,
        paidMinor: 0,
        remainingMinor: 0,
        status: DebtLifecycleStatus.active,
        debts: const <StatementDebtLine>[],
        entries: const <StatementEntry>[],
        options: const StatementOptions(),
      );
      expect(data.fileName, 'Dhimmah_أحمد_محمد_2026-09-22.pdf');
    });

    test('the document code is stable for the same person', () {
      final String first = StatementData.stableCode('person-1');
      expect(first, hasLength(4));
      expect(StatementData.stableCode('person-1'), first);
      expect(StatementData.stableCode('person-2'), isNot(first));
    });
  });

  group('statement amounts', () {
    test('are printed without bidi controls', () {
      // The PDF renderer has no isolate support and no glyphs for those code
      // points, so they must not reach the page.
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
      final AppFormatting formatting = AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      );
      final String forScreen =
          formatting.amount(const Money(1500000, AppCurrency.inr));
      final String forDocument =
          formatting.documentAmount(const Money(1500000, AppCurrency.inr));

      expect(forScreen.contains('\u2066'), isTrue);
      expect(forDocument.contains('\u2066'), isFalse);
      expect(forDocument.contains('\u00A0'), isFalse);
      expect(forDocument, contains('15,000'));
      expect(forDocument, contains('₹'));
    });
  });
}
