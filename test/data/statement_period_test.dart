import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/share/share_service.dart';
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
import 'package:intl/date_symbol_data_local.dart';

/// A statement bounded to a period.
///
/// The document has to answer one question it could not before: what did the
/// account hold at the end of those days? The arithmetic is the whole feature,
/// so these tests pin it — every closing figure must be the opening balance
/// plus what the period added and less what it settled, with nothing counted
/// twice and nothing outside the days counted at all.
void main() {
  setUpAll(() async {
    await initializeDateFormatting('ar');
  });

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
    required int principal,
    required DateTime issuedAt,
    DebtDirection direction = DebtDirection.owedToMe,
    DateTime? dueAt,
  }) => Debt(
    id: id,
    personIds: const <String>['p1'],
    direction: direction,
    title: id,
    principalMinor: principal,
    currency: AppCurrency.inr,
    issuedAt: issuedAt,
    dueAt: dueAt,
    createdAt: issuedAt,
    updatedAt: issuedAt,
  );

  Payment payment(String id, Debt on, int amount, DateTime paidAt) => Payment(
    id: id,
    debtId: on.id,
    amountMinor: amount,
    currency: on.currency,
    paidAt: paidAt,
    createdAt: paidAt,
  );

  // One debt on each side, so a period can be asked of a mixed account, and a
  // third debt opened inside the period whose payments only partly settle it.
  final Debt first = debt(
    'first',
    principal: 100000,
    issuedAt: DateTime(2026, 1, 10),
  );
  final Debt second = debt(
    'second',
    principal: 60000,
    issuedAt: DateTime(2026, 6, 15),
    direction: DebtDirection.iOwe,
  );
  final Debt third = debt(
    'third',
    principal: 40000,
    issuedAt: DateTime(2026, 11),
  );

  final List<Payment> payments = <Payment>[
    payment('p-first', first, 30000, DateTime(2026, 2)),
    payment('p-second', second, 10000, DateTime(2026, 6, 20)),
    payment('p-third', third, 5000, DateTime(2026, 11, 5)),
    payment('p-first-later', first, 20000, today),
  ];

  PersonLedger ledgerOf(List<Debt> debts, List<Payment> all) {
    final List<DebtView> views = <DebtView>[
      for (final Debt d in debts)
        DebtCalculator.buildView(
          debt: d,
          payments: <Payment>[
            for (final Payment p in all)
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

  final PersonLedger mixed = ledgerOf(<Debt>[first, second, third], payments);

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  final AppFormatting formatting = AppFormatting(
    language: AppLanguage.arabic,
    numerals: NumeralsStyle.latin,
    defaultCurrency: AppCurrency.inr,
    localizations: l10n,
  );
  final StatementService service = StatementService(
    localizations: l10n,
    formatting: formatting,
  );

  StatementData build(
    StatementOptions options, {
    PersonLedger? ledger,
    List<Payment>? all,
  }) => service.buildData(
    ledger: ledger ?? mixed,
    payments: all ?? payments,
    currency: AppCurrency.inr,
    now: today,
    options: options,
  );

  /// A movement's effect on the signed balance: a debt on the user's owing side
  /// subtracts, a payment on that side adds back. The two words in the balance
  /// column use the same sign.
  int signedEffect(StatementEntry entry) {
    final bool onIOweSide = entry.direction.isIOwe;
    return switch (entry.kind) {
      StatementEntryKind.debtCreated =>
        onIOweSide ? -entry.amountMinor : entry.amountMinor,
      _ => onIOweSide ? entry.amountMinor : -entry.amountMinor,
    };
  }

  group('without a period nothing changed', () {
    test('the document is the one the app has always printed', () {
      final StatementData data = build(
        const StatementOptions(scope: StatementScope.all),
      );

      expect(data.hasPeriod, isFalse);
      expect(data.periodFrom, isNull);
      expect(data.periodTo, isNull);
      expect(data.openingBalanceMinor, 0);
      expect(
        data.closingBalanceMinor,
        isNull,
        reason: 'without a period the closing row reads the last movement',
      );

      // Every figure the document printed before this feature, unchanged.
      expect(data.totalMinor, 200000);
      expect(data.paidMinor, 65000);
      expect(data.remainingMinor, 135000);
      expect(
        data.entries.length,
        7,
        reason: 'every movement of every debt in the currency',
      );
      final List<StatementEntry> unbounded = buildStatementEntries(
        debts: <Debt>[first, second, third],
        payments: payments,
        currency: AppCurrency.inr,
      );
      expect(data.entries.length, unbounded.length);
      for (int i = 0; i < unbounded.length; i++) {
        expect(data.entries[i].date, unbounded[i].date);
        expect(data.entries[i].kind, unbounded[i].kind);
        expect(data.entries[i].amountMinor, unbounded[i].amountMinor);
        expect(
          data.entries[i].balanceAfterMinor,
          unbounded[i].balanceAfterMinor,
        );
        expect(data.entries[i].balanceDirection, unbounded[i].balanceDirection);
      }
    });
  });

  group('the period arithmetic holds', () {
    /// The invariant, over every case: the opening balance plus what the
    /// printed movements did equals the closing balance, exactly.
    void expectBalanced(StatementData data) {
      final int movements = data.entries.fold<int>(
        0,
        (int sum, StatementEntry entry) => sum + signedEffect(entry),
      );
      expect(
        data.openingBalanceMinor + movements,
        data.closingBalanceMinor,
        reason: 'opening + debts − payments must be the closing balance',
      );
    }

    test('an empty period carries the balance forward untouched', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026, 4),
          periodTo: DateTime(2026, 4, 30),
        ),
      );
      expect(data.entries, isEmpty);
      // The first debt and its February payment are all that had happened.
      expect(data.openingBalanceMinor, 70000);
      expect(data.closingBalanceMinor, 70000);
      expectBalanced(data);
    });

    test('a period that starts before the first debt opens at zero', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2025, 12),
          periodTo: DateTime(2026, 2, 15),
        ),
      );
      expect(data.openingBalanceMinor, 0);
      expect(data.entries.length, 2, reason: 'the debt and its payment');
      expect(data.closingBalanceMinor, 70000);
      expectBalanced(data);
    });

    test('the days on both ends are inside the period', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026, 2),
          periodTo: DateTime(2026, 6, 20),
        ),
      );
      // The payment on the first day and the debt and payment on the last.
      expect(
        data.entries.map((StatementEntry e) => e.kind),
        <StatementEntryKind>[
          StatementEntryKind.payment,
          StatementEntryKind.debtCreated,
          StatementEntryKind.payment,
        ],
      );
      expect(
        data.openingBalanceMinor,
        100000,
        reason: 'the January debt, before the period began',
      );
      expectBalanced(data);
    });

    test('a mixed account keeps each side signed', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: DateTime(2026, 6, 30),
        ),
      );
      // first: +100,000 −30,000; second: −60,000 +10,000.
      expect(data.openingBalanceMinor, 0);
      expect(data.closingBalanceMinor, 20000);
      expect(data.isMixed, isTrue);
      expectBalanced(data);
    });

    test('a period ending today closes on the current balance', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: today,
        ),
      );
      expect(data.closingBalanceMinor, data.net.minorUnits);
      expect(data.hasPeriod, isTrue);
      expectBalanced(data);
    });
  });

  group('a period ending today agrees with the person page', () {
    test('one side: the closing figure is the remaining balance', () {
      final PersonLedger oneSide = ledgerOf(<Debt>[first, third], payments);
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: today,
        ),
        ledger: oneSide,
      );
      expect(
        data.closingBalanceMinor,
        data.remainingMinor,
        reason:
            'everything is owed to the user, so the signed figure is '
            'the same size and the same side',
      );
    });

    test('the owing side: the closing figure is negative and as large', () {
      final PersonLedger owing = ledgerOf(<Debt>[second], payments);
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: today,
        ),
        ledger: owing,
      );
      expect(data.remainingMinor, 50000);
      expect(data.closingBalanceMinor, -50000);
    });
  });

  group('options', () {
    test('a period is part of the options value', () {
      const StatementOptions none = StatementOptions();
      final StatementOptions period = none.copyWith(
        periodFrom: DateTime(2026),
        periodTo: DateTime(2026, 1, 31),
      );
      expect(period.hasPeriod, isTrue);
      expect(period.isDefault, isFalse);
      expect(period == none, isFalse);
      expect(period.hashCode == none.hashCode, isFalse);
      expect(
        period.copyWith(),
        period,
        reason: 'leaving the period alone keeps it',
      );
      final StatementOptions cleared = period.copyWith(
        periodFrom: null,
        periodTo: null,
      );
      expect(cleared.hasPeriod, isFalse);
      expect(cleared, none);
    });

    test('one end alone is not a period', () {
      final StatementOptions half = const StatementOptions().copyWith(
        periodFrom: DateTime(2026),
      );
      expect(half.hasPeriod, isFalse);
    });
  });

  group('a period is read at its own end', () {
    /// The same five periods the arithmetic above covers, so the document's
    /// side cells are checked against every shape the figures can take.
    final List<(DateTime, DateTime)> periods = <(DateTime, DateTime)>[
      (DateTime(2026, 4), DateTime(2026, 4, 30)),
      (DateTime(2025, 12), DateTime(2026, 2, 15)),
      (DateTime(2026, 2), DateTime(2026, 6, 20)),
      (DateTime(2026), DateTime(2026, 6, 30)),
      (DateTime(2026), today),
    ];

    test(
      'the two side cells add up to the closing balance, in every period',
      () {
        for (final (DateTime from, DateTime to) in periods) {
          final StatementData data = build(
            StatementOptions(
              scope: StatementScope.all,
              periodFrom: from,
              periodTo: to,
            ),
          );
          expect(
            data.owedToMe.minorUnits - data.iOwe.minorUnits,
            data.closingBalanceMinor,
            reason:
                '$from..$to: the cells and the closing figure are the '
                'same position, not two different days',
          );
          expect(data.net.minorUnits, data.closingBalanceMinor);
        }
      },
    );

    test('the breakdown remaining column adds up to each side cell', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: DateTime(2026, 6, 30),
        ),
      );
      int sumFor({required bool owedToMe}) => data.debts
          .where((StatementDebtLine line) => line.direction.isIOwe != owedToMe)
          .fold<int>(
            0,
            (int sum, StatementDebtLine line) =>
                sum + line.remaining.minorUnits,
          );
      expect(sumFor(owedToMe: true), data.owedToMe.minorUnits);
      expect(sumFor(owedToMe: false), data.iOwe.minorUnits);
    });

    test(
      'a debt opened after the period is in neither the table nor the cells',
      () {
        final StatementData data = build(
          StatementOptions(
            scope: StatementScope.all,
            periodFrom: DateTime(2026),
            periodTo: DateTime(2026, 6, 30),
          ),
        );
        expect(
          data.debts.map((StatementDebtLine line) => line.title),
          isNot(contains('third')),
        );
        expect(
          data.entries.any(
            (StatementEntry entry) => entry.debtTitle == 'third',
          ),
          isFalse,
        );
        expect(data.debts.length, 2);
        expect(
          data.totalMinor,
          160000,
          reason: 'the November debt is not in the period total',
        );
      },
    );

    test('a payment after the period is not in the paid column', () {
      final StatementData data = build(
        StatementOptions(
          scope: StatementScope.all,
          periodFrom: DateTime(2026),
          periodTo: DateTime(2026, 6, 30),
        ),
      );
      final StatementDebtLine firstLine = data.debts.firstWhere(
        (StatementDebtLine line) => line.title == 'first',
      );
      expect(
        firstLine.paid.minorUnits,
        30000,
        reason: 'only the February payment happened by the end of June',
      );
      expect(firstLine.remaining.minorUnits, 70000);
      expect(data.paidMinor, 40000);
    });

    test('a debt opened after the period does not change the sides', () {
      final Debt owed = debt(
        'owed',
        principal: 150000,
        issuedAt: DateTime(2026, 1, 10),
      );
      final Debt later = debt(
        'later',
        principal: 75000,
        issuedAt: DateTime(2026, 5),
        direction: DebtDirection.iOwe,
      );
      final List<Payment> all = <Payment>[
        payment('owed-paid', owed, 50000, DateTime(2026, 2)),
      ];
      final StatementData data = build(
        const StatementOptions().copyWith(
          periodFrom: DateTime(2026, 3),
          periodTo: DateTime(2026, 3, 31),
        ),
        ledger: ledgerOf(<Debt>[owed, later], all),
        all: all,
      );
      // The manager's case: $1,500 owed to the user, $500 of it paid before
      // the period, and a $750 debt opened after it.
      expect(data.debts.length, 1);
      expect(data.debts.single.title, 'owed');
      expect(data.owedToMe.minorUnits, 100000);
      expect(data.iOwe.minorUnits, 0);
      expect(data.closingBalanceMinor, 100000);
    });

    test(
      'a period that closed at zero is a clearance though a debt opened today',
      () {
        final Debt old = debt(
          'old',
          principal: 150000,
          issuedAt: DateTime(2026),
        );
        final Debt fresh = debt(
          'fresh',
          principal: 50000,
          issuedAt: today,
          direction: DebtDirection.iOwe,
        );
        final List<Payment> all = <Payment>[
          payment('old-paid', old, 150000, DateTime(2026, 2)),
        ];
        final StatementData data = build(
          const StatementOptions().copyWith(
            periodFrom: DateTime(2026),
            periodTo: DateTime(2026, 2, 28),
          ),
          ledger: ledgerOf(<Debt>[old, fresh], all),
          all: all,
        );
        expect(data.closingBalanceMinor, 0);
        expect(data.isClearance, isTrue);
        expect(data.fileName, startsWith('Dhimmah_Clearance_'));
        expect(
          data.debts.length,
          1,
          reason: 'the debt opened today is not part of the period',
        );
      },
    );

    test(
      'a period that ended with a balance is a statement though today is settled',
      () {
        final Debt old = debt(
          'old',
          principal: 150000,
          issuedAt: DateTime(2026),
        );
        final List<Payment> all = <Payment>[
          payment('old-paid', old, 150000, today),
        ];
        final StatementData data = build(
          const StatementOptions().copyWith(
            periodFrom: DateTime(2026),
            periodTo: DateTime(2026, 2, 28),
          ),
          ledger: ledgerOf(<Debt>[old], all),
          all: all,
        );
        expect(
          data.closingBalanceMinor,
          150000,
          reason: 'the payment came after the period ended',
        );
        expect(data.isClearance, isFalse);
        expect(data.fileName, isNot(startsWith('Dhimmah_Clearance')));
      },
    );

    test('the shared caption states the period and its closing balance', () {
      final Debt owed = debt(
        'owed',
        principal: 150000,
        issuedAt: DateTime(2026, 1, 10),
        dueAt: DateTime(2026, 1, 15),
      );
      final List<Payment> all = <Payment>[
        payment('owed-paid', owed, 50000, DateTime(2026, 2)),
      ];
      final StatementData data = build(
        const StatementOptions().copyWith(
          periodFrom: DateTime(2026, 3),
          periodTo: DateTime(2026, 3, 31),
        ),
        ledger: ledgerOf(<Debt>[owed], all),
        all: all,
      );
      final String period = l10n.reportPeriodRange(
        formatting.date(DateTime(2026, 3)),
        formatting.date(DateTime(2026, 3, 31)),
      );
      final String amount = formatting.amount(
        Money(100000, AppCurrency.inr),
        showCode: true,
      );
      final String caption = ShareService(
        localizations: l10n,
        formatting: formatting,
      ).statementCaption(data);
      expect(
        caption,
        '${l10n.shareStatementFor('أحمد')}\n'
        '${l10n.shareLinePeriodBalance(period, amount)}',
      );
      expect(
        caption,
        isNot(contains(formatting.date(DateTime(2026, 1, 15)))),
        reason: 'a due date is a today fact and a period has none',
      );
    });

    test('without a period the shared caption is unchanged', () {
      final StatementData data = build(
        const StatementOptions(scope: StatementScope.all),
      );
      final String caption = ShareService(
        localizations: l10n,
        formatting: formatting,
      ).statementCaption(data);
      expect(
        caption,
        '${l10n.shareStatementFor('أحمد')}\n'
        '${l10n.shareLineRemaining(formatting.amount(data.remaining, showCode: true))}',
      );
    });
  });
  group('payment notes', () {
    test('a payment note is carried in full to the notes section', () {
      final String note = List<String>.filled(70, 'p').join('\n');
      final Payment noted = Payment(
        id: 'noted',
        debtId: first.id,
        amountMinor: 1000,
        currency: first.currency,
        paidAt: DateTime(2026, 7),
        createdAt: DateTime(2026, 7),
        note: note,
      );
      final StatementData data = build(
        const StatementOptions(scope: StatementScope.all, includeNotes: true),
        all: <Payment>[noted],
      );
      expect(data.notes, contains(note));
      expect(
        data.entries
            .singleWhere(
              (StatementEntry entry) =>
                  entry.kind == StatementEntryKind.payment,
            )
            .note,
        note,
      );
    });
  });
}
