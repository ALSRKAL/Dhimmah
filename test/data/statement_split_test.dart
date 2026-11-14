import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One payment against a person, as their statement prints it.
///
/// A person-level payment is several payment rows, one per debt it reached. The
/// statement is the document a user shows to someone else — it is the one place
/// where "several rows" has to read as a legible history, with the date, the
/// note and the amount on each line, and a running balance that ends where the
/// ledger says it ends.
void main() {
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late AppLocalizations l10n;

  final DateTime today = dateOnly(DateTime(2026, 9, 15));
  final DateTime now = DateTime(2026, 9, 15, 10);

  setUp(() async {
    db = AppDatabase.memory();
    service = buildService(db, clock: () => now);
    l10n = lookupAppLocalizations(const Locale('ar'));
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      incomes: IncomeRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  Future<Person> person() =>
      service.createPerson(const PersonDraft(name: 'أحمد'));

  Future<Debt> debt(
    Person person, {
    required String title,
    required int minor,
    required DateTime issuedAt,
    DateTime? dueAt,
  }) => service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[person.id],
      title: title,
      principalMinor: minor,
      currency: AppCurrency.inr,
      issuedAt: issuedAt,
      dueAt: dueAt,
    ),
  );

  Future<StatementData> statementFor(Person person) async {
    final PersonLedger ledger = (await queries
        .watchPersonLedger(person.id, dueSoonWindowDays: 7, asOf: today)
        .first)!;
    return StatementService(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    ).buildData(
      ledger: ledger,
      payments: await service.payments.getAll(),
      currency: AppCurrency.inr,
      now: now,
      // Every debt, settled ones included. These tests are about what a split
      // payment writes on a statement, and a split is exactly what settles a
      // debt: under the default scope the debt it cleared would be left off
      // the page, and with it the line being checked. What the default leaves
      // out is `statement_scope_test.dart`'s subject, not this file's.
      options: const StatementOptions(scope: StatementScope.all),
    );
  }

  test(
    'each share of a split is its own line, with its debt and its note',
    () async {
      final Person ahmed = await person();
      await debt(
        ahmed,
        title: 'كهرباء',
        minor: 100000,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, -10),
      );
      await debt(
        ahmed,
        title: 'ماء',
        minor: 200000,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, 10),
      );

      // 1,000 against everything he owes: the first debt in full, the second in
      // part. Two payment rows, one intention.
      final List<Payment> split = await service.recordPersonPayment(
        PersonPaymentDraft(
          personId: ahmed.id,
          direction: DebtDirection.iOwe,
          currency: AppCurrency.inr,
          amountMinor: 150000,
          paidAt: today,
          note: 'حوالة واحدة',
        ),
      );
      expect(split, hasLength(2));

      final StatementData data = await statementFor(ahmed);

      expect(data.totalMinor, 300000);
      expect(data.paidMinor, 150000);
      expect(data.remainingMinor, 150000);
      expect(data.personName, 'أحمد');

      final List<StatementEntry> payments = <StatementEntry>[
        for (final StatementEntry entry in data.entries)
          if (entry.kind == StatementEntryKind.payment) entry,
      ];
      expect(
        payments,
        hasLength(2),
        reason:
            'the split is two payments on two debts, and reads as two lines',
      );
      expect(
        <String, int>{
          for (final StatementEntry e in payments) e.debtTitle!: e.amountMinor,
        },
        <String, int>{'كهرباء': 100000, 'ماء': 50000},
      );
      for (final StatementEntry entry in payments) {
        expect(entry.date, today);
        expect(
          entry.note,
          'حوالة واحدة',
          reason: 'the note travels with every row the payment produced',
        );
        expect(entry.direction, DebtDirection.iOwe);
        expect(entry.currency, AppCurrency.inr);
      }

      // The running balance is the column that makes it legible: it must end on
      // the figure the summary states.
      final StatementEntry last = data.entries.last;
      expect(
        last.balanceAfterMinor,
        data.remainingMinor,
        reason: 'the last line and the total are the same number',
      );
      expect(last.balanceDirection, DebtDirection.iOwe);
    },
  );

  test('a split that clears a debt still reports the clearing', () async {
    final Person ahmed = await person();
    await debt(
      ahmed,
      title: 'كهرباء',
      minor: 100000,
      issuedAt: addDays(today, -20),
      dueAt: addDays(today, -10),
    );
    await service.recordPersonPayment(
      PersonPaymentDraft(
        personId: ahmed.id,
        direction: DebtDirection.iOwe,
        currency: AppCurrency.inr,
        amountMinor: 100000,
        paidAt: today,
      ),
    );

    final StatementData data = await statementFor(ahmed);
    expect(data.remainingMinor, 0);
    expect(data.status, DebtLifecycleStatus.paid);
    expect(data.dueAt, isNull, reason: 'nothing left to fall due');
  });

  group('one receipt for one payment', () {
    StatementService statements() => StatementService(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    );

    Future<List<({DebtView view, Payment payment})>> partsOf(
      Person person,
      Payment opened,
    ) async {
      final List<Payment> all = await service.payments
          .watchForPerson(person.id)
          .first;
      final List<Payment> group = StatementService.paymentGroupOf(opened, all);
      final PersonLedger ledger = (await queries
          .watchPersonLedger(person.id, dueSoonWindowDays: 7, asOf: today)
          .first)!;
      return <({DebtView view, Payment payment})>[
        for (final Payment payment in group)
          (
            view: ledger.debts.firstWhere(
              (DebtView v) => v.debt.id == payment.debtId,
            ),
            payment: payment,
          ),
      ];
    }

    test(
      'every part of a split payment is found from any one of them',
      () async {
        final Person ahmed = await person();
        await debt(
          ahmed,
          title: 'كهرباء',
          minor: 100000,
          issuedAt: addDays(today, -20),
          dueAt: addDays(today, -10),
        );
        await debt(
          ahmed,
          title: 'ماء',
          minor: 200000,
          issuedAt: addDays(today, -20),
          dueAt: addDays(today, 10),
        );
        final List<Payment> split = await service.recordPersonPayment(
          PersonPaymentDraft(
            personId: ahmed.id,
            direction: DebtDirection.iOwe,
            currency: AppCurrency.inr,
            amountMinor: 150000,
            paidAt: today,
            note: 'حوالة واحدة',
          ),
        );
        expect(split, hasLength(2));

        for (final Payment opened in split) {
          final List<({DebtView view, Payment payment})> parts = await partsOf(
            ahmed,
            opened,
          );
          expect(
            parts.map((({DebtView view, Payment payment}) p) => p.payment.id),
            unorderedEquals(split.map((Payment p) => p.id)),
            reason:
                'opened from either debt, the receipt is for the whole 1,500',
          );

          final ReceiptData receipt = statements().buildReceipt(
            parts: parts,
            personName: ahmed.name,
            now: now,
          );
          expect(receipt.amount.minorUnits, 150000);
          expect(receipt.isSplit, isTrue);
          expect(
            <String, int>{
              for (final ReceiptLine line in receipt.lines)
                line.debtTitle: line.amount.minorUnits,
            },
            <String, int>{'كهرباء': 100000, 'ماء': 50000},
          );
          // 1,000 settled, 1,500 left on the water bill.
          expect(receipt.remainingNow.minorUnits, 150000);
          expect(receipt.note, isNull, reason: 'the note is off unless asked');
        }
        // The same number whichever part it was opened from.
        final Set<String> numbers = <String>{
          for (final Payment opened in split)
            statements()
                .buildReceipt(
                  parts: await partsOf(ahmed, opened),
                  personName: ahmed.name,
                  now: now,
                )
                .number,
        };
        expect(numbers, hasLength(1));
      },
    );

    test(
      'the note is printed when asked, and only when the parts agree',
      () async {
        final Person ahmed = await person();
        await debt(
          ahmed,
          title: 'كهرباء',
          minor: 100000,
          issuedAt: addDays(today, -20),
        );
        await debt(
          ahmed,
          title: 'ماء',
          minor: 200000,
          issuedAt: addDays(today, -19),
        );
        final List<Payment> split = await service.recordPersonPayment(
          PersonPaymentDraft(
            personId: ahmed.id,
            direction: DebtDirection.iOwe,
            currency: AppCurrency.inr,
            amountMinor: 150000,
            paidAt: today,
            note: 'حوالة واحدة',
          ),
        );
        final List<({DebtView view, Payment payment})> parts = await partsOf(
          ahmed,
          split.first,
        );
        expect(
          statements()
              .buildReceipt(
                parts: parts,
                personName: ahmed.name,
                now: now,
                includeNote: true,
              )
              .note,
          'حوالة واحدة',
        );

        // One part's note edited afterwards: no note is picked at random.
        await service.updatePayment(
          split.last.id,
          PaymentDraft(
            amountMinor: split.last.amountMinor,
            paidAt: split.last.paidAt,
            note: 'ملاحظة أخرى',
          ),
        );
        final List<({DebtView view, Payment payment})> edited = await partsOf(
          ahmed,
          split.first,
        );
        expect(edited, hasLength(2), reason: 'editing a note keeps the group');
        expect(
          statements()
              .buildReceipt(
                parts: edited,
                personName: ahmed.name,
                now: now,
                includeNote: true,
              )
              .note,
          isNull,
        );
      },
    );

    test('two payments recorded separately are two receipts', () async {
      final Person ahmed = await person();
      final Debt first = await debt(
        ahmed,
        title: 'كهرباء',
        minor: 100000,
        issuedAt: addDays(today, -20),
      );
      final Debt second = await debt(
        ahmed,
        title: 'ماء',
        minor: 200000,
        issuedAt: addDays(today, -19),
      );
      // A clock that moves, as a phone's does: this file's shared one is
      // frozen, and two writes at one frozen instant look like one payment.
      int tick = 0;
      final LedgerService ticking = buildService(
        db,
        clock: () => now.add(Duration(milliseconds: ++tick)),
      );
      final Payment one = await ticking.recordPayment(
        first.id,
        PaymentDraft(amountMinor: 10000, paidAt: today),
      );
      final Payment two = await ticking.recordPayment(
        second.id,
        PaymentDraft(amountMinor: 20000, paidAt: today),
      );
      expect(
        one.createdAt,
        isNot(two.createdAt),
        reason: 'the fixture relies on two distinct moments',
      );
      expect(await partsOf(ahmed, one), hasLength(1));
      expect(await partsOf(ahmed, two), hasLength(1));
    });
  });
}
