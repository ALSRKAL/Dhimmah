import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';

/// Where the time actually goes as the ledger grows.
///
/// Not a pass/fail test: a measurement. A personal ledger that is fine at twenty
/// records and unusable at ten thousand is not production-ready, and the only way
/// to know which one Dhimmah is, is to build the large one and read it.
///
/// Run with `flutter test test/performance/scale_test.dart --reporter expanded`
/// and read the printed table. The assertions at the end are deliberately loose:
/// they catch a catastrophic regression (a query that becomes quadratic, or a
/// screen that stops responding) without turning a noisy machine into a red build.
void main() {
  late AppDatabase db;
  late LedgerQueries queries;

  setUp(() {
    db = AppDatabase.memory();
    queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
  });
  tearDown(() async => db.close());

  Future<void> time<T>(
    String label,
    Future<T> Function() body,
    Map<String, int> into,
  ) async {
    final Stopwatch watch = Stopwatch()..start();
    await body();
    watch.stop();
    into[label] = watch.elapsedMilliseconds;
  }

  test('measure the read path at 500 people / 2500 debts / 10000 payments',
      () async {
    final DateTime today = dateOnly(DateTime.now());
    final Map<String, int> timings = <String, int>{};
    const int peopleCount = 500;
    const int debtsPerPerson = 5; // 2500 debts
    const int paymentsPerDebt = 4; // 10000 payments
    const int obligationsCount = 2000;

    final Stopwatch seeding = Stopwatch()..start();

    final List<PeopleCompanion> people = <PeopleCompanion>[
      for (int i = 0; i < peopleCount; i++)
        PeopleCompanion.insert(
          id: 'p$i',
          name: 'شخص رقم $i',
          phone: drift.Value<String>('+9677712${i.toString().padLeft(5, '0')}'),
          createdAt: today,
          updatedAt: today,
        ),
    ];
    await db.batch((Batch b) => b.insertAll(db.people, people));

    final List<DebtsCompanion> debts = <DebtsCompanion>[];
    for (int p = 0; p < peopleCount; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        debts.add(
          DebtsCompanion.insert(
            id: 'd${p}_$d',
            personId: drift.Value<String>('p$p'),
            direction: d.isEven ? DebtDirection.iOwe : DebtDirection.owedToMe,
            title: drift.Value<String>('قرض رقم $d للشخص $p'),
            principalMinor: 100000 + d * 10000,
            currencyCode: AppCurrency.inr.code,
            issuedAt: addDays(today, -100 - d),
            dueAt: drift.Value<DateTime>(addDays(today, d * 3 - 10)),
            recurrence: RecurrenceFrequency.none,
            createdAt: today,
            updatedAt: today,
          ),
        );
      }
    }
    await db.batch((Batch b) => b.insertAll(db.debts, debts));

    final List<PaymentsCompanion> payments = <PaymentsCompanion>[];
    for (int p = 0; p < peopleCount; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        for (int k = 0; k < paymentsPerDebt; k++) {
          payments.add(
            PaymentsCompanion.insert(
              id: 'pay${p}_${d}_$k',
              debtId: drift.Value<String>('d${p}_$d'),
              personId: drift.Value<String>('p$p'),
              amountMinor: 5000 + k * 1000,
              currencyCode: AppCurrency.inr.code,
              paidAt: addDays(today, -20 + k),
              createdAt: today,
            ),
          );
        }
      }
    }
    await db.batch((Batch b) => b.insertAll(db.payments, payments));

    final List<ObligationsCompanion> obligations = <ObligationsCompanion>[
      for (int i = 0; i < obligationsCount; i++)
        ObligationsCompanion.insert(
          id: 'o$i',
          name: 'التزام رقم $i',
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
    ];
    await db.batch((Batch b) => b.insertAll(db.obligations, obligations));
    seeding.stop();

    // --- the read paths a user actually triggers --------------------------
    await time('dashboard snapshot', () async {
      await for (final DashboardSnapshot s in queries.watchDashboard(
        dueSoonWindowDays: 7,
        asOf: today,
        defaultCurrency: AppCurrency.inr,
      )) {
        // ignore: avoid_print
        print('   (dashboard: ${s.openDebtCount} open debts, '
            '${s.upcoming.length} upcoming, ${s.peopleCount} people)');
        break;
      }
    }, timings);

    await time('ledger list', () async {
      await for (final List<DebtView> v in queries.watchDebtViews(
        dueSoonWindowDays: 7,
        asOf: today,
      )) {
        // ignore: avoid_print
        print('   (ledger lists ${v.length} records)');
        break;
      }
    }, timings);

    await time('person directory', () async {
      await for (final List<PersonDirectoryEntry> e
          in queries.watchPersonDirectory(asOf: today, dueSoonWindowDays: 7)) {
        // ignore: avoid_print
        print('   (directory lists ${e.length} people)');
        break;
      }
    }, timings);

    await time('one person page', () async {
      await for (final PersonLedger? l
          in queries.watchPersonLedger('p42', dueSoonWindowDays: 7, asOf: today)) {
        // ignore: avoid_print
        print('   (person page shows ${l?.debts.length} debts)');
        break;
      }
    }, timings);

    await time('obligations list', () async {
      await for (final List<ObligationInstance> o
          in queries.watchObligationInstances(asOf: today)) {
        // ignore: avoid_print
        print('   (obligations list has ${o.length} instances)');
        break;
      }
    }, timings);

    await time('reminders list', () async {
      await for (final List<Reminder> _ in queries.watchReminders(asOf: today)) {
        break;
      }
    }, timings);

    await time('monthly report', () async {
      await for (final MonthlyReport _ in queries.watchMonthlyReport(
        year: today.year,
        month: today.month,
        currency: AppCurrency.inr,
        trendMonths: 6,
        asOf: today,
      )) {
        break;
      }
    }, timings);

    // Search reads the same three providers the screen watches, then filters in
    // memory — so its cost is the cost of loading everything plus the scan.
    await time('search (load everything + scan)', () async {
      final List<DebtView> views = <DebtView>[];
      await for (final List<DebtView> v in queries.watchDebtViews(
        dueSoonWindowDays: 7,
        asOf: today,
      )) {
        views.addAll(v);
        break;
      }
      final int hits = views
          .where((DebtView v) => v.displayName.contains('42'))
          .length;
      // ignore: avoid_print
      print('   (search matched $hits of ${views.length})');
    }, timings);

    // ignore: avoid_print
    print('''
=== SCALE MEASUREMENT — $peopleCount people / ${debts.length} debts / ${payments.length} payments / $obligationsCount obligations ===
   seeding                  : ${seeding.elapsedMilliseconds} ms (batched, not representative of user writes)
${timings.entries.map((MapEntry<String, int> e) => '   ${e.key.padRight(25)}: ${e.value} ms').join('\n')}
''');

    // A hang detector, not a benchmark.
    //
    // These numbers come from a debug build — Dart JIT, drift's row mapping
    // unoptimised — on a shared machine whose load moved between 4 and 14 during
    // this work, so an absolute millisecond ceiling would flap and teach nothing.
    // It fired once here at 6,457 ms for the monthly report, which is the same
    // linear cost measured earlier at 4,514 ms.
    //
    // The real gates on this code are the correctness tests in
    // `equivalence_test.dart` and the ordinary suite; this file exists to print a
    // number when someone changes the read layer, and to fail if a read stops
    // returning at all.
    for (final MapEntry<String, int> entry in timings.entries) {
      expect(
        entry.value,
        lessThan(30000),
        reason: '${entry.key} took ${entry.value} ms — far beyond a slow debug '
            'read, which suggests it no longer terminates',
      );
    }
  });
}
