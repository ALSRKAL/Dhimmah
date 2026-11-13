import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/services/debt_calculator.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which of a person's debts a statement covers.
///
/// A statement is sent to someone else, so what it leaves out matters as much
/// as what it prints: a settled debt is noise, and an archived one is a record
/// the user put away. These tests pin the scope rules, and — the part that
/// costs money when it is wrong — that every figure on the page is the sum of
/// the rows on the page and nothing else.
void main() {
  final DateTime today = dateOnly(DateTime(2026, 11, 13));
  final Person person = Person(
    id: 'p1',
    name: 'أحمد',
    colorIndex: 0,
    createdAt: today,
    updatedAt: today,
  );

  Debt debt(
    String id, {
    int principal = 100000,
    AppCurrency currency = AppCurrency.inr,
    DebtDirection direction = DebtDirection.owedToMe,
    bool archived = false,
  }) =>
      Debt(
        id: id,
        personIds: const <String>['p1'],
        direction: direction,
        title: id,
        principalMinor: principal,
        currency: currency,
        issuedAt: addDays(today, -60),
        createdAt: addDays(today, -60),
        updatedAt: addDays(today, -60),
        archivedAt: archived ? addDays(today, -1) : null,
      );

  Payment payment(String id, Debt on, int amount) => Payment(
        id: id,
        debtId: on.id,
        amountMinor: amount,
        currency: on.currency,
        paidAt: addDays(today, -10),
        createdAt: addDays(today, -10),
      );

  // One of each state, in rupees: still open, half paid, paid off, archived
  // while open, archived after being paid off. And one open debt in riyals.
  final Debt open = debt('open');
  final Debt partial = debt('partial', principal: 200000);
  final Debt settled = debt('settled', principal: 50000);
  final Debt archivedOpen = debt('archived-open', principal: 70000, archived: true);
  final Debt archivedSettled =
      debt('archived-settled', principal: 30000, archived: true);
  final Debt riyal = debt('riyal', principal: 900000, currency: AppCurrency.yer);

  final List<Payment> payments = <Payment>[
    payment('pay-partial', partial, 80000),
    payment('pay-settled', settled, 50000),
    payment('pay-archived', archivedSettled, 30000),
  ];

  PersonLedger ledgerOf(List<Debt> debts) {
    final List<DebtView> views = <DebtView>[
      for (final Debt d in debts)
        DebtCalculator.buildView(
          debt: d,
          payments: <Payment>[
            for (final Payment p in payments)
              if (p.debtId == d.id) p,
          ],
          asOf: today,
          dueSoonWindowDays: 7,
        ),
    ];
    return PersonLedger(
      person: person,
      debts: views,
      totals: DebtCalculator.totalsByCurrency(
        views,
        asOf: today,
        dueSoonWindowDays: 7,
      ),
    );
  }

  final PersonLedger ledger = ledgerOf(<Debt>[
    open,
    partial,
    settled,
    archivedOpen,
    archivedSettled,
    riyal,
  ]);

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  final StatementService service = StatementService(
    localizations: l10n,
    formatting: AppFormatting(
      language: AppLanguage.arabic,
      numerals: NumeralsStyle.latin,
      defaultCurrency: AppCurrency.inr,
      localizations: l10n,
    ),
  );

  StatementData build(
    StatementOptions options, {
    AppCurrency currency = AppCurrency.inr,
    PersonLedger? from,
  }) =>
      service.buildData(
        ledger: from ?? ledger,
        payments: payments,
        currency: currency,
        now: today,
        options: options,
      );

  List<String> titles(StatementData data) =>
      data.debts.map((StatementDebtLine line) => line.title).toList()..sort();

  /// The figures a statement prints must be the sum of the rows it prints.
  void expectFiguresMatchRows(StatementData data) {
    int sum(Money Function(StatementDebtLine) pick) => data.debts.fold<int>(
          0,
          (int total, StatementDebtLine line) => total + pick(line).minorUnits,
        );
    expect(data.totalMinor, sum((StatementDebtLine l) => l.principal));
    expect(data.paidMinor, sum((StatementDebtLine l) => l.paid));
    expect(data.remainingMinor, sum((StatementDebtLine l) => l.remaining));
  }

  group('what a statement covers', () {
    test('by default: only what is still outstanding', () {
      final StatementData data = build(const StatementOptions());

      expect(titles(data), <String>['open', 'partial']);
      expect(data.hiddenSettledCount, 1);
      expect(
        data.hiddenArchivedCount,
        2,
        reason: 'an archived debt that is also settled is one hidden record',
      );
      expectFiguresMatchRows(data);
    });

    test('"all" adds the settled debts and still leaves the archived out', () {
      final StatementData data = build(
        const StatementOptions(scope: StatementScope.all),
      );

      expect(titles(data), <String>['open', 'partial', 'settled']);
      expect(data.hiddenSettledCount, 0);
      expect(data.hiddenArchivedCount, 2);
      expectFiguresMatchRows(data);
    });

    test('archived debts appear only when asked for', () {
      final StatementData openOnes = build(
        const StatementOptions(includeArchived: true),
      );
      expect(titles(openOnes), <String>['archived-open', 'open', 'partial']);
      expect(
        openOnes.hiddenSettledCount,
        1,
        reason: 'the settled one that is not archived',
      );
      expect(
        openOnes.hiddenArchivedCount,
        1,
        reason: 'archived and settled: still out under "open only"',
      );

      final StatementData everything = build(
        const StatementOptions(
          scope: StatementScope.all,
          includeArchived: true,
        ),
      );
      expect(titles(everything), <String>[
        'archived-open',
        'archived-settled',
        'open',
        'partial',
        'settled',
      ]);
      expect(everything.hiddenSettledCount, 0);
      expect(everything.hiddenArchivedCount, 0);
      expectFiguresMatchRows(everything);
    });

    test('chosen by hand: exactly the ticked debts, whatever their state', () {
      final StatementData data = build(
        const StatementOptions(
          scope: StatementScope.selected,
          selectedDebtIds: <String>{'settled', 'archived-open', 'riyal'},
        ),
      );

      // The riyal debt is ticked too, but this statement is in rupees.
      expect(titles(data), <String>['archived-open', 'settled']);
      expectFiguresMatchRows(data);
    });

    test('everything ticked equals what the statement used to print', () {
      // Before scopes existed a statement printed every debt in the currency.
      // "All, archived included" is that document, figure for figure.
      final StatementData data = build(
        const StatementOptions(
          scope: StatementScope.all,
          includeArchived: true,
        ),
      );
      expect(data.debts, hasLength(5));
      expect(data.totalMinor, 100000 + 200000 + 50000 + 70000 + 30000);
      expect(data.paidMinor, 80000 + 50000 + 30000);
      expect(data.remainingMinor, 100000 + 120000 + 70000);
    });
  });

  group('the figures follow the rows', () {
    test('what is left is the same whether settled debts are shown or not', () {
      final StatementData openOnly = build(const StatementOptions());
      final StatementData all = build(
        const StatementOptions(scope: StatementScope.all),
      );

      // A settled debt has nothing left on it, so hiding it cannot change what
      // the other person still owes. If these ever differ, a filter is
      // changing someone's balance.
      expect(openOnly.remainingMinor, all.remainingMinor);
      expect(openOnly.remainingMinor, 100000 + 120000);
    });

    test('the history holds only the payments of the debts that are printed',
        () {
      final StatementData data = build(const StatementOptions());

      // Open only: the two open debts and the one payment on the half-paid one.
      // The payments that settled the hidden debts are not on the page.
      expect(data.entries, hasLength(3));
      expect(
        data.entries
            .where((StatementEntry e) => e.kind == StatementEntryKind.payment)
            .map((StatementEntry e) => e.amountMinor),
        <int>[80000],
      );
      expect(
        data.entries.last.balanceAfterMinor,
        data.remainingMinor,
        reason: 'the last balance in the history is what the summary says is left',
      );
    });

    test('a statement of settled debts alone reads as paid', () {
      final StatementData data = build(
        const StatementOptions(
          scope: StatementScope.selected,
          selectedDebtIds: <String>{'settled'},
        ),
      );
      expect(data.status, DebtLifecycleStatus.paid);
      expect(data.remainingMinor, 0);
    });

    test('a statement of archived debts alone is not called paid', () {
      final StatementData data = build(
        const StatementOptions(
          scope: StatementScope.selected,
          selectedDebtIds: <String>{'archived-open'},
        ),
      );
      expect(data.status, DebtLifecycleStatus.archived);
    });
  });

  group('the currencies on offer', () {
    test('follow the scope', () {
      expect(
        StatementService.currenciesFor(ledger),
        <AppCurrency>[AppCurrency.inr, AppCurrency.yer],
      );

      // Only a settled debt in rupees: nothing to state there by default, so
      // the currency is not offered — choosing it would print an empty page.
      final PersonLedger rupeesSettled = ledgerOf(<Debt>[settled, riyal]);
      expect(
        StatementService.currenciesFor(rupeesSettled),
        <AppCurrency>[AppCurrency.yer],
      );
      expect(
        StatementService.currenciesFor(
          rupeesSettled,
          options: const StatementOptions(scope: StatementScope.all),
        ),
        <AppCurrency>[AppCurrency.inr, AppCurrency.yer],
      );
    });

    test('a person whose every debt is settled still has currencies', () {
      final PersonLedger allSettled = ledgerOf(<Debt>[settled]);
      expect(StatementService.currenciesFor(allSettled), isEmpty);
      expect(
        StatementService.allCurrenciesFor(allSettled),
        <AppCurrency>[AppCurrency.inr],
        reason: 'this is how the screen tells "nothing open" from "no debts"',
      );
    });
  });

  group('options', () {
    test('are compared by value', () {
      const StatementOptions a = StatementOptions(
        scope: StatementScope.selected,
        selectedDebtIds: <String>{'x', 'y'},
      );
      final StatementOptions b = const StatementOptions().copyWith(
        scope: StatementScope.selected,
        selectedDebtIds: <String>{'y', 'x'},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == b.copyWith(includeArchived: true), isFalse);
      expect(a == b.copyWith(selectedDebtIds: <String>{'x'}), isFalse);
    });

    test('the default is the private one', () {
      const StatementOptions options = StatementOptions();
      expect(options.scope, StatementScope.openOnly);
      expect(options.includeArchived, isFalse);
      expect(options.isDefault, isTrue);
      expect(
        options.copyWith(scope: StatementScope.all).isDefault,
        isFalse,
      );
    });
  });
}
