
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/monthly_report_builder.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

/// Where the monthly report's four seconds actually go.
///
/// A measurement tool, not a test: it prints a breakdown so the report's cost
/// can be attributed to a phase rather than guessed at.
void main() {
  // Seeding a ledger at scale takes longer than the default budget.
  test('break the report down', timeout: const Timeout(Duration(minutes: 3)), () async {
    final AppDatabase db = AppDatabase.memory();
    final DateTime today = dateOnly(DateTime.now());
    const int peopleCount = 500;
    const int debtsPerPerson = 5;
    const int paymentsPerDebt = 4;
    const int obligationsCount = 2000;

    await db.batch((Batch b) => b.insertAll(db.people, <PeopleCompanion>[
          for (int i = 0; i < peopleCount; i++)
            PeopleCompanion.insert(
              id: 'p$i',
              name: 'شخص رقم $i',
              createdAt: today,
              updatedAt: today,
            ),
        ]));

    final List<DebtsCompanion> debts = <DebtsCompanion>[];
    for (int p = 0; p < peopleCount; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        debts.add(DebtsCompanion.insert(
          id: 'd${p}_$d',
          personId: drift.Value<String>('p$p'),
          direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
          title: drift.Value<String>('قرض رقم $d'),
          principalMinor: 100000 + d * 10000,
          currencyCode: AppCurrency.inr.code,
          issuedAt: addDays(today, -100 - d),
          dueAt: drift.Value<DateTime>(addDays(today, d * 3 - 10)),
          recurrence: RecurrenceFrequency.none,
          createdAt: today,
          updatedAt: today,
        ));
      }
    }
    await db.batch((Batch b) => b.insertAll(db.debts, debts));

    final List<PaymentsCompanion> payments = <PaymentsCompanion>[];
    for (int p = 0; p < peopleCount; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        for (int k = 0; k < paymentsPerDebt; k++) {
          payments.add(PaymentsCompanion.insert(
            id: 'pay${p}_${d}_$k',
            debtId: drift.Value<String>('d${p}_$d'),
            personId: drift.Value<String>('p$p'),
            amountMinor: 5000 + k * 1000,
            currencyCode: AppCurrency.inr.code,
            paidAt: addDays(today, -20 + k),
            createdAt: today,
          ));
        }
      }
    }
    await db.batch((Batch b) => b.insertAll(db.payments, payments));

    await db.batch((Batch b) => b.insertAll(db.obligations, <ObligationsCompanion>[
          for (int i = 0; i < obligationsCount; i++)
            ObligationsCompanion.insert(
              id: 'o$i',
              name: 'التزام $i',
              category: ObligationCategory.other,
              amountMinor: 20000,
              currencyCode: AppCurrency.inr.code,
              frequency: RecurrenceFrequency.monthly,
              intervalCount: const drift.Value<int>(1),
              startAt: addDays(today, -30),
              nextDueAt: addDays(today, 1),
              createdAt: today,
              updatedAt: today,
            ),
        ]));

    final PaymentRepositoryImpl paymentsRepo = PaymentRepositoryImpl(db);
    final DebtRepositoryImpl debtsRepo = DebtRepositoryImpl(db);
    final ObligationRepositoryImpl obligationsRepo = ObligationRepositoryImpl(db);
    final PersonRepositoryImpl peopleRepo = PersonRepositoryImpl(db);

    int ms(void Function() body) {
      final Stopwatch w = Stopwatch()..start();
      body();
      w.stop();
      return w.elapsedMilliseconds;
    }

    Future<int> msAsync(Future<void> Function() body) async {
      final Stopwatch w = Stopwatch()..start();
      await body();
      w.stop();
      return w.elapsedMilliseconds;
    }

    // Warm the page cache so the reads are not paying for first touch.
    List<Payment> allPayments = await paymentsRepo.getAll();
    List<Debt> allDebts = await debtsRepo.getAll();
    List<Obligation> allObligations = await obligationsRepo.getAll();
    List<ObligationOccurrence> allOccurrences =
        await obligationsRepo.allOccurrences();
    final int people = (await peopleRepo.getAll()).length;

    // ignore: avoid_print
    print('''
=== MONTHLY REPORT BREAKDOWN — $peopleCount people / ${allDebts.length} debts / ${allPayments.length} payments / ${allOccurrences.length} occurrences ===
   read payments            : ${await msAsync(() async => allPayments = await paymentsRepo.getAll())} ms
   read debts               : ${await msAsync(() async => allDebts = await debtsRepo.getAll())} ms
   read obligations         : ${await msAsync(() async => allObligations = await obligationsRepo.getAll())} ms
   read occurrences         : ${await msAsync(() async => allOccurrences = await obligationsRepo.allOccurrences())} ms
   read people              : ${await msAsync(() async => people) } ms''');

    for (final int months in <int>[0, 1, 6, 12]) {
      final int total = ms(() {
        buildMonthlyReport(
          year: today.year,
          month: today.month,
          currency: AppCurrency.inr,
          debts: allDebts,
          payments: allPayments,
          obligations: allObligations,
          occurrences: allOccurrences,
          peopleCount: people,
          asOf: today,
          trendMonths: months,
        );
      });
      // ignore: avoid_print
      print('   ${'buildMonthlyReport(trend=$months)'.padRight(28)}: $total ms');
    }

    // The trend on its own, to separate it from the month's own sums.
    for (final int months in <int>[1, 6, 12]) {
      final int trend = ms(() {
        buildTrend(
          endYear: today.year,
          endMonth: today.month,
          currency: AppCurrency.inr,
          debts: allDebts,
          payments: allPayments,
          obligations: allObligations,
          occurrences: allOccurrences,
          months: months,
        );
      });
      // ignore: avoid_print
      print('   ${'buildTrend($months)'.padRight(28)}: $trend ms');
    }

    // How many times the inner date test runs: months x rows, which is the
    // shape the cost has.
    // ignore: avoid_print
    print('   inner iterations at trend=6: '
        '${6 * (allPayments.length + allDebts.length + allOccurrences.length)}');

    await db.close();
  });
}
