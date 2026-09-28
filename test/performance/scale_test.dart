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
/// and read the printed tables. The assertions at the end are deliberately loose:
/// they catch a catastrophic regression (a query that becomes quadratic, or a
/// screen that stops responding) without turning a noisy machine into a red
/// build.
///
/// The seed gives roughly every third record more than one participant, because
/// that is the shape the ledger has to stay fast at: a shared record is read
/// through the link table, and a read that forgot to would show up here as a
/// number that is too good to be true.
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

  /// Fills the database and reports how much of each thing it holds.
  Future<({int debts, int payments, int links, int obligations})> seed({
    required int people,
    required int debtsPerPerson,
    required int paymentsPerDebt,
    required int obligations,
  }) async {
    final DateTime today = dateOnly(DateTime.now());

    final List<PeopleCompanion> peopleRows = <PeopleCompanion>[
      for (int i = 0; i < people; i++)
        PeopleCompanion.insert(
          id: 'p$i',
          name: 'شخص رقم $i',
          phone: drift.Value<String>('+9677712${i.toString().padLeft(5, '0')}'),
          createdAt: today,
          updatedAt: today,
        ),
    ];
    await db.batch((Batch b) => b.insertAll(db.people, peopleRows));

    final List<DebtsCompanion> debtRows = <DebtsCompanion>[];
    final List<DebtPeopleCompanion> linkRows = <DebtPeopleCompanion>[];
    for (int p = 0; p < people; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        final String id = 'd${p}_$d';
        // Every third record is shared, with two or three people on it.
        final int participants = d % 3 == 0 ? 2 + (p % 2) : 1;
        final List<String> participantIds = <String>[
          for (int k = 0; k < participants; k++) 'p${(p + k * 7) % people}',
        ];
        debtRows.add(
          DebtsCompanion.insert(
            id: id,
            personId: drift.Value<String?>(participantIds.first),
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
        for (int k = 0; k < participantIds.length; k++) {
          linkRows.add(
            DebtPeopleCompanion.insert(
              debtId: id,
              personId: participantIds[k],
              position: drift.Value<int>(k),
              createdAt: today,
            ),
          );
        }
      }
    }
    await db.batch((Batch b) => b.insertAll(db.debts, debtRows));
    await db.batch((Batch b) => b.insertAll(db.debtPeople, linkRows));

    final List<PaymentsCompanion> paymentRows = <PaymentsCompanion>[];
    for (int p = 0; p < people; p++) {
      for (int d = 0; d < debtsPerPerson; d++) {
        for (int k = 0; k < paymentsPerDebt; k++) {
          paymentRows.add(
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
    await db.batch((Batch b) => b.insertAll(db.payments, paymentRows));

    final List<ObligationsCompanion> obligationRows = <ObligationsCompanion>[
      for (int i = 0; i < obligations; i++)
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
    await db.batch((Batch b) => b.insertAll(db.obligations, obligationRows));

    return (
      debts: debtRows.length,
      payments: paymentRows.length,
      links: linkRows.length,
      obligations: obligations,
    );
  }

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

  /// The reads a user actually triggers, measured one by one.
  Future<Map<String, int>> measureLedger() async {
    final DateTime today = dateOnly(DateTime.now());
    final Map<String, int> timings = <String, int>{};
    int ledgerRows = 0;
    int sharedRows = 0;
    int ledgerRemaining = 0;
    int ledgerPrincipal = 0;

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
        ledgerRows = v.length;
        sharedRows = v.where((DebtView view) => view.isShared).length;
        ledgerRemaining =
            v.fold<int>(0, (int sum, DebtView view) => sum + view.remainingMinor);
        ledgerPrincipal = v.fold<int>(
          0,
          (int sum, DebtView view) => sum + view.debt.principalMinor,
        );
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
        print('   (person page shows ${l?.debts.length} debts, '
            '${l?.totals.length} currencies)');
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
      final int hits =
          views.where((DebtView v) => v.displayName.contains('42')).length;
      // ignore: avoid_print
      print('   (search matched $hits of ${views.length})');
    }, timings);

    // The money is counted once per record, however many people share it.
    // `sharedRows` records carry more than one participant, so a read that
    // joined and multiplied would show up here as a ledger far larger than the
    // debts table.
    expect(ledgerRows, greaterThan(0));
    expect(sharedRows, greaterThan(0));
    expect(
      ledgerRemaining,
      lessThanOrEqualTo(ledgerPrincipal),
      reason: 'remaining can never exceed the sum of principals',
    );

    // ignore: avoid_print
    print('   (ledger rows $ledgerRows, of which $sharedRows are shared; '
        'principal sum $ledgerPrincipal, remaining sum $ledgerRemaining)');

    return timings;
  }

  void report(String title, Map<String, int> timings, String seedingNote) {
    // ignore: avoid_print
    print('''
=== $title ===
$seedingNote
${timings.entries.map((MapEntry<String, int> e) => '   ${e.key.padRight(25)}: ${e.value} ms').join('\n')}
''');
  }

  /// A hang detector, not a benchmark.
  ///
  /// These numbers come from a debug build — Dart JIT, drift's row mapping
  /// unoptimised — on a shared machine whose load moved between 4 and 14 during
  /// this work, so an absolute millisecond ceiling would flap and teach nothing.
  /// It fired once here at 6,457 ms for the monthly report, which is the same
  /// linear cost measured earlier at 4,514 ms.
  ///
  /// The real gates on this code are the correctness tests in
  /// `equivalence_test.dart` and the ordinary suite; this file exists to print a
  /// number when someone changes the read layer, and to fail if a read stops
  /// returning at all.
  void gate(Map<String, int> timings) {
    for (final MapEntry<String, int> entry in timings.entries) {
      // A termination gate, not a performance budget: the figures that matter
      // are printed above and are only meaningful when this file runs alone.
      // The ceiling is high on purpose — under the full suite these reads share
      // the machine with hundreds of other tests, and what must never happen is
      // a read that does not come back at all.
      expect(
        entry.value,
        lessThan(120000),
        reason: '${entry.key} took ${entry.value} ms — far beyond a slow debug '
            'read, which suggests it no longer terminates',
      );
    }
  }

  // Seeding and reading a ledger this size is not a unit of behaviour: the
  // default budget is meant for tests that assert something, and these print.
  // The budget is generous because the numbers are only meaningful when the
  // measurement has the machine to itself — run this file alone for the figures
  // quoted in the README, and read the run under the full suite as a smoke test.
  const Timeout budget = Timeout(Duration(minutes: 20));

  test('measure the read path at 500 people / 2500 debts / 10000 payments',
      timeout: budget,
      () async {
    const int peopleCount = 500;
    const int debtsPerPerson = 5;
    const int paymentsPerDebt = 4;
    const int obligationsCount = 2000;

    final Stopwatch seeding = Stopwatch()..start();
    final counts = await seed(
      people: peopleCount,
      debtsPerPerson: debtsPerPerson,
      paymentsPerDebt: paymentsPerDebt,
      obligations: obligationsCount,
    );
    seeding.stop();

    final Map<String, int> timings = await measureLedger();
    report(
      'SCALE MEASUREMENT — $peopleCount people / ${counts.debts} debts / '
      '${counts.payments} payments / ${counts.links} links / '
      '$obligationsCount obligations',
      timings,
      '   seeding                  : ${seeding.elapsedMilliseconds} ms '
          '(batched, not representative of user writes)',
    );
    gate(timings);
  });

  test('measure the read path at 1000 people / 10000 debts / 50000 payments',
      timeout: budget,
      () async {
    const int peopleCount = 1000;
    const int debtsPerPerson = 10;
    const int paymentsPerDebt = 5;
    const int obligationsCount = 2000;

    final Stopwatch seeding = Stopwatch()..start();
    final counts = await seed(
      people: peopleCount,
      debtsPerPerson: debtsPerPerson,
      paymentsPerDebt: paymentsPerDebt,
      obligations: obligationsCount,
    );
    seeding.stop();

    final Map<String, int> timings = await measureLedger();
    report(
      'SCALE MEASUREMENT — $peopleCount people / ${counts.debts} debts / '
      '${counts.payments} payments / ${counts.links} links / '
      '$obligationsCount obligations',
      timings,
      '   seeding                  : ${seeding.elapsedMilliseconds} ms '
          '(batched, not representative of user writes)',
    );
    gate(timings);
  });
}
