import 'dart:io';
import 'dart:ui' show Locale;

import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/backup/backup_codec.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/services/backup_restore_service.dart';
import 'package:dhimmah/data/services/backup_service.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/monthly_budget.dart';
import 'package:dhimmah/domain/entities/monthly_report.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/backup_format.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';

/// One user's whole journey, in one run, from an empty ledger.
///
/// Every other test in the suite takes one feature and drives it hard. None of
/// them would notice if the features stopped agreeing with *each other* — if the
/// budget stopped seeing an obligation the reports still saw, if a split payment
/// stopped reaching the person's page, if a restore came back numerically
/// different from what it replaced. Those are the failures that reach a user,
/// and they only appear when the whole flow runs in sequence on one database.
///
/// The steps are the journey as a person walks it:
///
///   people -> debts in both directions -> one payment -> a split payment
///   -> a salary and a commitment, and paying it -> the monthly figures
///   -> a backup -> a wipe -> a restore
///
/// The read models asserted along the way are the ones the screens read, so a
/// figure checked here is the figure the dashboard, the budget card, the person
/// page and the report actually print — not a private recomputation.
void main() {
  late Directory dir;
  late AppDatabase db;
  late LedgerService service;
  late LedgerQueries queries;
  late BackupService backups;
  late BackupRestoreService restores;

  /// A Wednesday in the middle of a month, so "late" and "upcoming" both exist
  /// and the month has a clear inside.
  final DateTime now = DateTime(2026, 10, 14, 9, 30);
  final DateTime today = dateOnly(now);
  const AppCurrency inr = AppCurrency.inr;
  const int dueSoonWindow = 7;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('dhimmah-journey');
    db = AppDatabase.memory();
    service = buildService(db, clock: () => now);
    await service.notifications.initialize(
      localizations: lookupAppLocalizations(const Locale('ar')),
    );
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
    backups = BackupService(
      database: db,
      appVersion: '1.3.0+6',
      clock: () => now,
      directory: dir,
    );
    restores = BackupRestoreService(
      database: db,
      backups: backups,
      rebuildDerivedState: () async {
        await service.ensureOccurrences();
        await service.refreshNotifications();
      },
    );
  });
  tearDown(() async {
    await db.close();
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  Future<DashboardSnapshot> dashboard() => queries
      .watchDashboard(
        dueSoonWindowDays: dueSoonWindow,
        defaultCurrency: inr,
        asOf: today,
      )
      .first;

  Future<MonthlyBudget> budget({int? month}) => queries
      .watchMonthlyBudget(
        year: now.year,
        month: month ?? now.month,
        currency: inr,
        asOf: today,
      )
      .first;

  Future<MonthlyReport> report({int? month}) => queries
      .watchMonthlyReport(
        year: now.year,
        month: month ?? now.month,
        currency: inr,
        trendMonths: 6,
        asOf: today,
      )
      .first;

  Future<List<DebtView>> views() => queries
      .watchDebtViews(dueSoonWindowDays: dueSoonWindow, asOf: today)
      .first;

  Future<PersonLedger> personLedger(String id) async =>
      (await queries
              .watchPersonLedger(id,
                  dueSoonWindowDays: dueSoonWindow, asOf: today)
              .first)!;

  /// The one figure the whole ledger is about, per direction.
  int openMinor(CurrencyTotals? totals, DebtDirection side) => side.isIOwe
      ? (totals?.iOweMinor ?? 0)
      : (totals?.owedToMeMinor ?? 0);

  /// One currency's bucket out of a per-currency list, or null when the currency
  /// has no records. `CurrencyTotals` deliberately carries no lookup of its own:
  /// the lists are short and the callers all want one specific currency.
  CurrencyTotals? bucketOf(List<CurrencyTotals> totals, AppCurrency currency) {
    for (final CurrencyTotals t in totals) {
      if (t.currency == currency) return t;
    }
    return null;
  }

  CurrencyTotals? bucket(DashboardSnapshot snap, AppCurrency currency) =>
      bucketOf(snap.totalsByCurrency, currency);

  test('a new user walks the whole app and every screen agrees at the end',
      () async {
    // ---- 1. Two people --------------------------------------------------
    final Person mariam = await service.createPerson(
      const PersonDraft(name: 'مريم حسن'),
    );
    final Person yousif = await service.createPerson(
      const PersonDraft(name: 'يوسف الكامل'),
    );
    expect(
      await queries
          .watchPersonDirectory(dueSoonWindowDays: dueSoonWindow, asOf: today)
          .first,
      hasLength(2),
    );

    DashboardSnapshot snap = await dashboard();
    expect((bucket(snap, inr)?.isEmpty ?? true), isTrue, reason: 'an empty ledger');

    // ---- 2. Debts in both directions ------------------------------------
    // Owed to me, late.
    final Debt toMe = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[mariam.id],
        title: 'سلفة',
        principalMinor: 500000,
        currency: inr,
        issuedAt: addDays(today, -60),
        dueAt: addDays(today, -10),
      ),
    );
    // I owe, due soon.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[yousif.id],
        title: 'قرض',
        principalMinor: 300000,
        currency: inr,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, 3),
      ),
    );

    snap = await dashboard();
    CurrencyTotals? totals = bucket(snap, inr);
    expect(openMinor(totals, DebtDirection.owedToMe), 500000);
    expect(openMinor(totals, DebtDirection.iOwe), 300000);
    expect(
      totals!.net.minorUnits,
      200000,
      reason: 'net is owed-to-me minus I-owe, and it is never netted into '
          'either side',
    );

    // ---- 3. One payment, recorded by hand -------------------------------
    await service.recordPayment(
      toMe.id,
      PaymentDraft(amountMinor: 200000, paidAt: addDays(today, -5)),
    );
    totals = bucket(await dashboard(), inr);
    expect(
      openMinor(totals, DebtDirection.owedToMe),
      300000,
      reason: 'the remainder, not the principal',
    );

    // ---- 4. A split payment, spread by the allocator --------------------
    // A second debt, so one payment has two places to go. The allocator fills a
    // waterfall — the most urgent record first, to its full remainder, then the
    // next — so 330,000 settles the late 300,000 outright and spills 30,000 into
    // the newer one.
    final Debt toMeSecond = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[mariam.id],
        title: 'قيمة جهاز',
        principalMinor: 100000,
        currency: inr,
        issuedAt: addDays(today, -5),
        dueAt: addDays(today, 30),
      ),
    );
    final List<Payment> split = await service.recordPersonPayment(
      PersonPaymentDraft(
        personId: mariam.id,
        direction: DebtDirection.owedToMe,
        currency: inr,
        amountMinor: 330000,
        paidAt: today,
      ),
    );

    // Where the money actually went, per debt, rather than only the total: a
    // split that put it all on one record and nothing on the other would sum
    // correctly and still be wrong.
    final Map<String, int> shareOf = <String, int>{
      for (final Payment p in split) p.debtId!: p.amountMinor,
    };
    expect(shareOf[toMe.id], 300000, reason: 'the late record was filled first');
    expect(shareOf[toMeSecond.id], 30000, reason: 'the remainder spilled over');
    expect(
      split.map((Payment p) => p.amountMinor).reduce((int a, int b) => a + b),
      330000,
      reason: 'a split never invents or loses a minor unit',
    );
    expect(
      split.every((Payment p) => p.personId == mariam.id),
      isTrue,
      reason: 'every share is filed against the person the payment is with',
    );

    final PersonLedger mariamLedger = await personLedger(mariam.id);
    // 500,000 + 100,000 principal; 200,000 + 300,000 + 30,000 paid.
    expect(
      openMinor(bucketOf(mariamLedger.totals, inr), DebtDirection.owedToMe),
      70000,
    );
    expect(
      openMinor(bucketOf(mariamLedger.totals, inr), DebtDirection.iOwe),
      0,
      reason: 'her page speaks for both directions and shows both',
    );
    // And the person's page agrees with the two debts read individually.
    final List<DebtView> all = await views();
    final int byHand = all
        .where((DebtView v) =>
            v.currency == inr && v.debt.direction == DebtDirection.owedToMe)
        .fold(0, (int sum, DebtView v) => sum + v.remainingMinor);
    expect(
      byHand,
      openMinor(bucketOf(mariamLedger.totals, inr), DebtDirection.owedToMe),
      reason: 'the person page is the sum of the rows the ledger shows',
    );

    // The first debt is settled by the split, so it is closed — and a closed
    // record keeps its own money right.
    final DebtView first = all.firstWhere((DebtView v) => v.debt.id == toMe.id);
    expect(first.remainingMinor, 0);
    expect(first.isSettled, isTrue);
    expect(
      all.firstWhere((DebtView v) => v.debt.id == toMeSecond.id).isSettled,
      isFalse,
      reason: 'the split did not settle the newer record',
    );
    expect(
      (await db.debtsDao.getById(toMe.id))!.closedAt,
      isNotNull,
      reason: 'the closing stamp is written by the same path a hand payment uses',
    );

    // ---- 5. A salary and a commitment, and paying the commitment --------
    await service.createIncome(
      IncomeDraft(
        name: 'الراتب',
        amountMinor: 900000,
        currency: inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(now.year, now.month),
      ),
    );
    final Obligation rent = await service.createObligation(
      ObligationDraft(
        name: 'الإيجار',
        category: ObligationCategory.housing,
        amountMinor: 400000,
        currency: inr,
        frequency: RecurrenceFrequency.monthly,
        startAt: DateTime(now.year, now.month),
      ),
    );
    await service.ensureOccurrences();

    MonthlyBudget month = await budget();
    expect(month.incomeMinor, 900000);
    expect(month.obligationsMinor, 400000);
    expect(month.remainingMinor, 500000);
    expect(
      month.overdueObligationsMinor,
      400000,
      reason: 'the rent fell on the 1st and it is the 14th',
    );

    final ObligationOccurrence rentPeriod =
        (await service.obligations.occurrencesFor(rent.id)).first;
    await service.markObligationPaid(
      ObligationInstance(obligation: rent, occurrence: rentPeriod),
    );

    month = await budget();
    expect(month.paidObligationsMinor, 400000);
    expect(month.overdueObligationsMinor, 0, reason: 'paid is not late');
    expect(
      month.obligationsMinor,
      400000,
      reason: 'paying a period does not remove it from the month it belongs to',
    );

    // ---- 6. The monthly figures, and the screens agreeing ---------------
    final MonthlyReport monthly = await report();
    expect(
      monthly.obligationsMinor,
      month.obligationsMinor,
      reason: 'the budget card and the report print one figure for the month',
    );
    // "Settled" on the report is money that moved against *records* — the hand
    // payment and the split — and the month's commitments are their own line
    // beside it, not folded in. Two different questions, two different figures;
    // reading one as the other is exactly the mistake this pins.
    expect(
      monthly.settledMinor,
      200000 + 330000,
      reason: 'the two payments moved this month',
    );
    expect(
      monthly.paidOutMinor,
      0,
      reason: 'nothing was paid against a record the user owes',
    );
    expect(
      month.paidObligationsMinor,
      400000,
      reason: 'the rent is settled too, and the report keeps it in its own '
          'column rather than in the payments figure',
    );

    // The dashboard's headline is the two sides of the open ledger: the 70,000
    // left on the newer record the split part-paid, against the 300,000 owed to
    // يوسف. The two settled debts are gone from both totals — settlement is what
    // removes them, not the passage of a due date.
    snap = await dashboard();
    expect(openMinor(bucket(snap, inr), DebtDirection.owedToMe), 70000);
    expect(openMinor(bucket(snap, inr), DebtDirection.iOwe), 300000);
    expect(bucket(snap, inr)!.net.minorUnits, -230000);

    // ---- 7. A backup, a wipe, and a restore -----------------------------
    final ({File file, ParsedBackup backup}) written =
        await backups.create(kind: BackupKind.manual);
    final File file = written.file;
    expect(file.existsSync(), isTrue);

    // Every row of every table, which is the comparison basis: a column the
    // codec forgot would show up here as a difference rather than as silence.
    // Keyed on the backup file's own table names, so the restore's tally and the
    // tables read back here can be compared key for key rather than summed.
    Future<Map<String, int>> fingerprint() async {
      final Map<String, List<Map<String, Object?>>> tables =
          <String, List<Map<String, Object?>>>{
        'people': (await db.peopleDao.getAll()).map(BackupCodec.person).toList(),
        'debts': (await db.debtsDao.getAll()).map(BackupCodec.debt).toList(),
        'debtPeople':
            (await db.debtsDao.allParticipantRows()).map(BackupCodec.link).toList(),
        'payments':
            (await db.debtsDao.getAllPayments()).map(BackupCodec.payment).toList(),
        'obligations':
            (await db.obligationsDao.getAll()).map(BackupCodec.obligation).toList(),
        'obligationOccurrences': (await db.obligationsDao.getOccurrences())
            .map(BackupCodec.occurrence)
            .toList(),
        'incomes':
            (await db.incomesDao.getAll()).map(BackupCodec.income).toList(),
        'reminders':
            (await db.remindersDao.getAll()).map(BackupCodec.reminder).toList(),
        'monthlySummaries': (await db.activityDao.getAllSummaries())
            .map(BackupCodec.summary)
            .toList(),
        'activity':
            (await db.activityDao.getAll()).map(BackupCodec.activity).toList(),
      };
      return <String, int>{
        for (final MapEntry<String, List<Map<String, Object?>>> e
            in tables.entries)
          e.key: e.value.length,
      };
    }

    final Map<String, int> before = await fingerprint();
    final MonthlyReport reportBefore = await report();
    final MonthlyBudget budgetBefore = await budget();
    final DashboardSnapshot dashboardBefore = await dashboard();

    await db.clearAllData();
    expect((await db.debtsDao.getAll()), isEmpty);
    expect((await db.peopleDao.getAll()), isEmpty);

    // Replace, because the ledger is empty: the file becomes the ledger.
    final ParsedBackup parsed =
        await backups.read(file.path);
    final RestoreReport restored = await restores.apply(
      backup: parsed,
      mode: RestoreMode.replace,
    );
    expect(await fingerprint(), before, reason: 'the tables came back whole');
    // The service's own tally, cross-checked against the tables read directly:
    // two independent answers to "what came back".
    for (final MapEntry<String, int> entry in before.entries) {
      expect(
        restored.counts[entry.key],
        entry.value,
        reason: 'the restore reported a different ${entry.key} count than the '
            'tables hold',
      );
    }

    // ---- 8. And the restored ledger reads the same ----------------------
    final MonthlyReport reportAfter = await report();
    final MonthlyBudget budgetAfter = await budget();
    final DashboardSnapshot dashboardAfter = await dashboard();

    expect(reportAfter.obligationsMinor, reportBefore.obligationsMinor);
    expect(reportAfter.settledMinor, reportBefore.settledMinor);
    expect(reportAfter.overdueMinor, reportBefore.overdueMinor);
    expect(reportAfter.closedDebts, reportBefore.closedDebts);
    expect(reportAfter.activeDebts, reportBefore.activeDebts);

    expect(budgetAfter.incomeMinor, budgetBefore.incomeMinor);
    expect(budgetAfter.obligationsMinor, budgetBefore.obligationsMinor);
    expect(budgetAfter.paidObligationsMinor, budgetBefore.paidObligationsMinor);
    expect(budgetAfter.overdueObligationsMinor, budgetBefore.overdueObligationsMinor);
    expect(budgetAfter.remainingMinor, budgetBefore.remainingMinor);

    expect(
      bucket(dashboardAfter, inr)!.net.minorUnits,
      bucket(dashboardBefore, inr)!.net.minorUnits,
    );
    expect(
      bucket(dashboardAfter, inr)!.iOweMinor,
      bucket(dashboardBefore, inr)!.iOweMinor,
    );
    expect(
      bucket(dashboardAfter, inr)!.owedToMeMinor,
      bucket(dashboardBefore, inr)!.owedToMeMinor,
    );

    // The split's individual shares survived as shares, not as one lump: the
    // per-debt rows are what a debt's own page and the statement read.
    final List<Payment> restoredShares =
        await PaymentRepositoryImpl(db).forDebt(toMeSecond.id);
    expect(restoredShares, isNotEmpty);
    expect(
      restoredShares.fold(0, (int s, Payment p) => s + p.amountMinor),
      30000,
      reason: 'the newer record received exactly its share of the split, and it '
          'came back as a share rather than as part of one lump',
    );

    // A backup taken from the restored database is the same database, so the
    // round trip is stable rather than merely once-true. `BackupCodec` is the
    // one place that decides what that means.
    final File second = (await backups.create(kind: BackupKind.manual)).file;
    expect(second.existsSync(), isTrue);
    final Map<String, int> after = await fingerprint();
    expect(after, before);
  });
}
