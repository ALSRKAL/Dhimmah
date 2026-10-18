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
  }) =>
      service.createDebt(
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
        .watchPersonLedger(
          person.id,
          dueSoonWindowDays: 7,
          asOf: today,
        )
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
    );
  }

  test('each share of a split is its own line, with its debt and its note',
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
      reason: 'the split is two payments on two debts, and reads as two lines',
    );
    expect(
      <String, int>{for (final StatementEntry e in payments) e.debtTitle!: e.amountMinor},
      <String, int>{'كهرباء': 100000, 'ماء': 50000},
    );
    for (final StatementEntry entry in payments) {
      expect(entry.date, today);
      expect(entry.note, 'حوالة واحدة',
          reason: 'the note travels with every row the payment produced');
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
  });

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
}
