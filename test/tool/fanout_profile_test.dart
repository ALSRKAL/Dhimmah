import 'dart:async';

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

/// What one write costs the read layer, and what a person with many debts costs
/// the person page.
void main() {
  // Seeding a ledger at scale takes longer than the default budget.
  test('fan-out and N+1', timeout: const Timeout(Duration(minutes: 3)), () async {
    final AppDatabase db = AppDatabase.memory();
    final DateTime today = dateOnly(DateTime.now());

    // 200 people x 5 debts = 1000 debts, 4000 payments. One person with 300
    // debts of their own, to measure the person page at the top of its range.
    await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
          for (int i = 0; i < 200; i++)
            PeopleCompanion.insert(
              id: 'p$i',
              name: 'شخص $i',
              createdAt: today,
              updatedAt: today,
            ),
        ]));
    final List<DebtsCompanion> debts = <DebtsCompanion>[];
    for (int p = 0; p < 200; p++) {
      final int count = p == 0 ? 300 : 5;
      for (int d = 0; d < count; d++) {
        debts.add(DebtsCompanion.insert(
          id: 'd${p}_$d',
          personId: drift.Value<String>('p$p'),
          direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
          title: drift.Value<String>('قرض $d'),
          principalMinor: 100000,
          currencyCode: AppCurrency.inr.code,
          issuedAt: addDays(today, -100),
          recurrence: RecurrenceFrequency.none,
          createdAt: today,
          updatedAt: today,
        ));
      }
    }
    await db.batch((Batch b) => b.insertAll(db.debts, debts));
    final List<PaymentsCompanion> payments = <PaymentsCompanion>[];
    for (final DebtsCompanion d in debts) {
      for (int k = 0; k < 4; k++) {
        payments.add(PaymentsCompanion.insert(
          id: 'pay${d.id.value}_$k',
          debtId: drift.Value<String>(d.id.value),
          personId: d.personId,
          amountMinor: 5000,
          currencyCode: AppCurrency.inr.code,
          paidAt: addDays(today, -20 + k),
          createdAt: today,
        ));
      }
    }
    await db.batch((Batch b) => b.insertAll(db.payments, payments));

    final LedgerQueries queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );

    // --- one person with 300 debts -------------------------------------
    final Stopwatch person = Stopwatch()..start();
    final dynamic ledger = await queries
        .watchPersonLedger('p0', dueSoonWindowDays: 7, asOf: today)
        .first;
    person.stop();
    // ignore: avoid_print
    print('person page (300 debts, 1200 payments): '
        '${person.elapsedMilliseconds} ms, ${ledger?.debts.length} debts');

    // --- what one write costs every mounted screen ---------------------
    final List<String> emissions = <String>[];
    final List<StreamSubscription<Object?>> subs = <StreamSubscription<Object?>>[];
    void count<T>(String label, Stream<T> stream) {
      subs.add(stream.listen((T _) => emissions.add(label)));
    }

    count('dashboard', queries.watchDashboard(
        dueSoonWindowDays: 7, asOf: today, defaultCurrency: AppCurrency.inr));
    count('ledger', queries.watchDebtViews(dueSoonWindowDays: 7, asOf: today));
    count('people', queries.watchPersonDirectory(
        dueSoonWindowDays: 7, asOf: today));
    count('obligations', queries.watchObligationInstances(asOf: today));
    count('reminders', queries.watchReminders(asOf: today));
    count('report', queries.watchMonthlyReport(
        year: today.year,
        month: today.month,
        currency: AppCurrency.inr,
        trendMonths: 6,
        asOf: today));

    await Future<void>.delayed(const Duration(milliseconds: 600));
    emissions.clear();

    // One payment recorded: the smallest write a user makes.
    final Stopwatch write = Stopwatch()..start();
    await db.into(db.payments).insert(PaymentsCompanion.insert(
          id: 'new-payment',
          debtId: const drift.Value<String>('d0_0'),
          personId: const drift.Value<String>('p0'),
          amountMinor: 100,
          currencyCode: AppCurrency.inr.code,
          paidAt: today,
          createdAt: today,
        ));
    await Future<void>.delayed(const Duration(milliseconds: 2500));
    write.stop();

    // ignore: avoid_print
    print('one payment write: ${write.elapsedMilliseconds} ms wall, '
        'stream re-emissions: ${emissions.length} $emissions');

    // Cancel before closing: a subscription that is mid-read when the database
    // shuts down under it is what hangs this file, and the numbers are already
    // printed by now.
    for (final StreamSubscription<Object?> s in subs) {
      unawaited(s.cancel());
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await db.close().timeout(const Duration(seconds: 10));
    } on Object {
      // The process ends here either way; a slow close must not fail the tool.
    }
  });
}
