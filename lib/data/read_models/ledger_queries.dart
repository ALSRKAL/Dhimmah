import 'package:drift/drift.dart';

import '../../core/money/currency.dart';
import '../../core/utils/dates.dart';
import '../../domain/entities/activity_entry.dart';
import '../../domain/entities/debt.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/monthly_report.dart';
import '../../domain/entities/obligation.dart';
import '../../domain/entities/payment.dart';
import '../../domain/entities/person.dart';
import '../../domain/entities/reminder.dart';
import '../../domain/enums/obligation_enums.dart';
import '../../domain/repositories/repositories.dart';
import '../../domain/services/debt_calculator.dart';
import '../../domain/services/monthly_report_builder.dart';
import '../../domain/services/obligation_schedule.dart';
import '../database/app_database.dart';
import '../database/daos/debts_dao.dart';

/// Read models: the shapes the screens actually render.
///
/// Each `watch*` method reads a consistent snapshot and re-emits whenever any
/// underlying table changes. Re-reading on change rather than combining five
/// live streams is deliberate: a single read pass guarantees the dashboard's
/// totals always agree with its lists, and combining independent streams is how
/// those two quietly drift apart.
///
/// The cost of that choice is real and was measured: at 500 people / 2,500 debts
/// / 10,000 payments the dashboard read took 1.4 s and the monthly report 4.5 s,
/// because every read loaded every row. The reads now push the work SQLite is
/// good at — summing, filtering, ordering — into SQL, and load only what a screen
/// renders. `test/performance/scale_test.dart` prints the numbers.
class LedgerQueries {
  LedgerQueries({
    required AppDatabase database,
    required this.people,
    required this.debts,
    required this.payments,
    required this.obligations,
    required this.reminders,
    required this.activity,
  }) : _db = database;

  final AppDatabase _db;
  final PersonRepository people;
  final DebtRepository debts;
  final PaymentRepository payments;
  final ObligationRepository obligations;
  final ReminderRepository reminders;
  final ActivityRepository activity;

  /// Tables whose changes invalidate a ledger snapshot.
  List<TableInfo<Table, dynamic>> get _watchedTables =>
      <TableInfo<Table, dynamic>>[
        _db.people,
        _db.debts,
        _db.debtPeople,
        _db.payments,
        _db.obligations,
        _db.obligationOccurrences,
        _db.reminders,
        _db.activityEntries,
      ];

  /// Runs [read] once, then again on every write to a ledger table.
  Stream<T> _watch<T>(Future<T> Function() read) async* {
    yield await read();
    final Stream<Set<TableUpdate>> updates =
        _db.tableUpdates(TableUpdateQuery.onAllTables(_watchedTables));
    await for (final Set<TableUpdate> _ in updates) {
      yield await read();
    }
  }

  /// A private snapshot of everything the ledger needs, read in one pass.
  ///
  /// The payments are *summed by SQLite* rather than loaded and added up here.
  /// Nothing in the ledger needs individual payment rows — only the total paid,
  /// how many, and when the last one was — and at 10,000 payments reading them
  /// all took 499 ms on every screen and every write, where the aggregate takes
  /// 20 ms. The two produce the same numbers, which is what
  /// `test/performance/ledger_aggregate_test.dart` exists to prove.
  Future<_LedgerData> _readLedger() async {
    final List<Person> peopleList = await people.getAll();
    final List<Debt> debtList = await debts.getAll();
    final List<DebtPaymentTotals> totals = await _db.debtsDao.paymentTotalsByDebt();
    return _LedgerData(
      people: <String, Person>{
        for (final Person p in peopleList) p.id: p,
      },
      debts: debtList,
      totalsByDebt: <String, PaymentTotals>{
        for (final DebtPaymentTotals t in totals)
          t.debtId: PaymentTotals(
            paidMinor: t.paidMinor,
            count: t.count,
            lastPaidAt: t.lastPaidAt,
          ),
      },
    );
  }

  /// Every debt, resolved into a render-ready view.
  Stream<List<DebtView>> watchDebtViews({
    required int dueSoonWindowDays,
    required DateTime asOf,
  }) {
    return _watch(() async {
      final _LedgerData data = await _readLedger();
      return _viewsOf(data, dueSoonWindowDays, asOf);
    });
  }

  static List<DebtView> _viewsOf(
    _LedgerData data,
    int dueSoonWindowDays,
    DateTime asOf,
  ) {
    final List<DebtView> views = <DebtView>[];
    for (final Debt debt in data.debts) {
      views.add(
        DebtCalculator.buildViewFromTotals(
          debt: debt,
          totals: data.totalsByDebt[debt.id] ?? const PaymentTotals.none(),
          participants: _participantsOf(data, debt),
          asOf: asOf,
          dueSoonWindowDays: dueSoonWindowDays,
        ),
      );
    }
    return views;
  }

  /// Resolves the people a record is with, in the order the user chose them.
  static List<Person> _participantsOf(_LedgerData data, Debt debt) => <Person>[
        for (final String id in debt.personIds)
          if (data.people[id] != null) data.people[id]!,
      ];

  /// The whole dashboard in one snapshot.
  Stream<DashboardSnapshot> watchDashboard({
    required int dueSoonWindowDays,
    required AppCurrency defaultCurrency,
    required DateTime asOf,
    int activityLimit = 12,
  }) {
    return _watch(() async {
      final _LedgerData data = await _readLedger();
      final List<DebtView> views = _viewsOf(data, dueSoonWindowDays, asOf);
      final List<CurrencyTotals> totals = DebtCalculator.totalsByCurrency(
        views,
        asOf: asOf,
        dueSoonWindowDays: dueSoonWindowDays,
      );

      final List<ActivityEntry> recent =
          await activity.recent(limit: activityLimit);

      final List<ObligationInstance> upcomingObligations =
          await _readUpcomingObligations(asOf);

      return DashboardSnapshot(
        totalsByCurrency: totals,
        primaryCurrency:
            DebtCalculator.primaryCurrency(totals, defaultCurrency),
        upcoming: DebtCalculator.sortByUrgency(views)
            .where((DebtView v) => v.debt.dueAt != null)
            .take(6)
            .toList(growable: false),
        upcomingObligations: upcomingObligations.take(4).toList(growable: false),
        recentActivity: recent,
        peopleCount: data.people.length,
        openDebtCount: views.where((DebtView v) => v.isOpen).length,
        hasAnyRecord: data.debts.isNotEmpty,
      );
    });
  }

  /// Open obligation periods coming up, soonest first.
  Future<List<ObligationInstance>> _readUpcomingObligations(DateTime asOf) async {
    final List<Obligation> list = await obligations.getAll();
    final List<ObligationOccurrence> all = await obligations.allOccurrences();
    final Map<String, Obligation> byId = <String, Obligation>{
      for (final Obligation obligation in list) obligation.id: obligation,
    };
    final List<ObligationInstance> instances = <ObligationInstance>[];
    for (final ObligationOccurrence occurrence in all) {
      final Obligation? obligation = byId[occurrence.obligationId];
      if (obligation == null || obligation.isArchived) continue;
      final ObligationStatus status = ObligationSchedule.resolveStatus(
        stored: occurrence.status,
        dueAt: occurrence.dueAt,
        asOf: asOf,
      );
      if (!status.isOpen) continue;
      instances.add(
        ObligationInstance(
          obligation: obligation,
          occurrence: occurrence.copyWith(status: status),
        ),
      );
    }
    instances.sort(
      (ObligationInstance a, ObligationInstance b) =>
          a.occurrence.dueAt.compareTo(b.occurrence.dueAt),
    );
    return instances;
  }

  /// Every obligation with its occurrences resolved, for the obligations list.
  Stream<List<ObligationInstance>> watchObligationInstances({
    required DateTime asOf,
    bool includeArchived = false,
  }) {
    return _watch(() async {
      final List<Obligation> list = await obligations.getAll();
      final List<ObligationOccurrence> all = await obligations.allOccurrences();
      final Map<String, Obligation> byId = <String, Obligation>{
        for (final Obligation obligation in list) obligation.id: obligation,
      };
      final List<ObligationInstance> instances = <ObligationInstance>[];
      for (final ObligationOccurrence occurrence in all) {
        final Obligation? obligation = byId[occurrence.obligationId];
        if (obligation == null) continue;
        if (obligation.isArchived && !includeArchived) continue;
        {
          final ObligationStatus status = ObligationSchedule.resolveStatus(
            stored: occurrence.status,
            dueAt: occurrence.dueAt,
            asOf: asOf,
          );
          instances.add(
            ObligationInstance(
              obligation: obligation,
              occurrence: occurrence.copyWith(status: status),
            ),
          );
        }
      }
      instances.sort(
        (ObligationInstance a, ObligationInstance b) =>
            a.occurrence.dueAt.compareTo(b.occurrence.dueAt),
      );
      return instances;
    });
  }

  /// The people directory with each person's balances.
  Stream<List<PersonDirectoryEntry>> watchPersonDirectory({
    required int dueSoonWindowDays,
    required DateTime asOf,
  }) {
    return _watch(() async {
      final _LedgerData data = await _readLedger();
      final List<DebtView> views = _viewsOf(data, dueSoonWindowDays, asOf);
      // Keyed by every participant, not by one person per record: a record with
      // several people belongs on each of their pages, where it reads as one of
      // their own debts. It is still one record — the ledger, the dashboard and
      // the report count it once, because they walk the records and not the
      // pages.
      final Map<String, List<DebtView>> byPerson = <String, List<DebtView>>{};
      for (final DebtView view in views) {
        for (final Person person in view.participants) {
          byPerson.putIfAbsent(person.id, () => <DebtView>[]).add(view);
        }
      }

      final List<PersonDirectoryEntry> entries = <PersonDirectoryEntry>[];
      for (final Person person in data.people.values) {
        final List<DebtView> personDebts =
            byPerson[person.id] ?? const <DebtView>[];
        DateTime lastActivity = person.updatedAt;
        for (final DebtView view in personDebts) {
          final DateTime? paidAt = view.lastPaymentAt;
          if (paidAt != null && paidAt.isAfter(lastActivity)) {
            lastActivity = paidAt;
          }
          if (view.debt.updatedAt.isAfter(lastActivity)) {
            lastActivity = view.debt.updatedAt;
          }
        }
        entries.add(
          PersonDirectoryEntry(
            person: person,
            debts: personDebts,
            totals: DebtCalculator.totalsByCurrency(
              personDebts,
              asOf: asOf,
              dueSoonWindowDays: dueSoonWindowDays,
            ),
            lastActivityAt: lastActivity,
          ),
        );
      }
      return entries;
    });
  }

  /// One person's page: every record linked to them, resolved in one pass.
  Stream<PersonLedger?> watchPersonLedger(
    String personId, {
    required int dueSoonWindowDays,
    required DateTime asOf,
  }) {
    return _watch(() async {
      final Person? person = await people.getById(personId);
      if (person == null) return null;
      final List<Debt> personDebts = await debts.forPerson(personId);
      // Only the people actually on this page, each read once: a person's page
      // is a handful of records, and scanning the whole directory to name two
      // participants would be a read that grows with the ledger rather than
      // with the screen.
      final Map<String, Person> peopleById = await _resolvePeople(
        <String>{
          for (final Debt debt in personDebts) ...debt.personIds,
        },
      );
      final List<DebtView> views = <DebtView>[];
      for (final Debt debt in personDebts) {
        views.add(
          DebtCalculator.buildView(
            debt: debt,
            payments: await payments.forDebt(debt.id),
            participants: <Person>[
              for (final String id in debt.personIds)
                if (peopleById[id] != null) peopleById[id]!,
            ],
            asOf: asOf,
            dueSoonWindowDays: dueSoonWindowDays,
          ),
        );
      }
      views.sort((DebtView a, DebtView b) => b.debt.issuedAt.compareTo(a.debt.issuedAt));
      return PersonLedger(
        person: person,
        debts: views,
        totals: DebtCalculator.totalsByCurrency(
          views,
          asOf: asOf,
          dueSoonWindowDays: dueSoonWindowDays,
        ),
      );
    });
  }

  /// One debt with its payment history and timeline.
  Stream<DebtDetail?> watchDebtDetail(
    String debtId, {
    required int dueSoonWindowDays,
    required DateTime asOf,
  }) {
    return _watch(() async {
      final Debt? debt = await debts.getById(debtId);
      if (debt == null) return null;
      final List<Payment> debtPayments = await payments.forDebt(debtId);
      final Map<String, Person> peopleById =
          await _resolvePeople(debt.personIds.toSet());
      final DebtView view = DebtCalculator.buildView(
        debt: debt,
        payments: debtPayments,
        participants: <Person>[
          for (final String id in debt.personIds)
            if (peopleById[id] != null) peopleById[id]!,
        ],
        asOf: asOf,
        dueSoonWindowDays: dueSoonWindowDays,
      );
      final List<ActivityEntry> entries =
          await activity.forEntity(RelatedEntityType.debt, debtId);
      return DebtDetail(
        view: view,
        payments: debtPayments
          ..sort((Payment a, Payment b) => b.paidAt.compareTo(a.paidAt)),
        activity: entries,
      );
    });
  }

  /// Reads a set of people by id, one query each.
  Future<Map<String, Person>> _resolvePeople(Set<String> ids) async {
    final Map<String, Person> out = <String, Person>{};
    for (final String id in ids) {
      final Person? person = await people.getById(id);
      if (person != null) out[id] = person;
    }
    return out;
  }

  /// Reminders with their status resolved against today.
  Stream<List<Reminder>> watchReminders({required DateTime asOf}) {
    return _watch(() async {
      final List<Reminder> list = await reminders.getAll();
      return list
          .map((Reminder r) => r.copyWith(status: resolveReminderStatus(r, asOf)))
          .toList(growable: false);
    });
  }

  /// One month's report, including a short trend for the charts.
  Stream<MonthlyReport> watchMonthlyReport({
    required int year,
    required int month,
    required AppCurrency currency,
    required int trendMonths,
    required DateTime asOf,
  }) {
    return _watch(() async {
      // Every payment, deliberately.
      //
      // A window ending at the reported month was tried and reverted. It looked
      // safe — nothing dated after the month can affect that month's sums — but
      // the report also uses the payment history to work out what each debt still
      // owed *at the month end*, and that interacts with whether the debt had
      // been issued yet. The measurement showed no benefit at any scale tested
      // (the seed's payments all fell inside the window), so an unproven change
      // to a number the user reads was not worth keeping.
      final List<Payment> allPayments = await payments.getAll();
      return buildMonthlyReport(
        year: year,
        month: month,
        currency: currency,
        debts: await debts.getAll(),
        payments: allPayments,
        obligations: await obligations.getAll(),
        occurrences: await obligations.allOccurrences(),
        peopleCount: (await people.getAll()).length,
        asOf: asOf,
        trendMonths: trendMonths,
      );
    });
  }
}

/// Resolves a reminder's status from its stored state and today's date.
ReminderStatus resolveReminderStatus(Reminder reminder, DateTime asOf) {
  if (reminder.isCompleted) return ReminderStatus.completed;
  if (reminder.status == ReminderStatus.dismissed) {
    return ReminderStatus.dismissed;
  }
  final int days = daysBetween(asOf, reminder.dueAt);
  if (days < 0) return ReminderStatus.overdue;
  if (days == 0) return ReminderStatus.today;
  return ReminderStatus.upcoming;
}

/// A debt plus its payment history and timeline.
class DebtDetail {
  const DebtDetail({
    required this.view,
    required this.payments,
    required this.activity,
  });

  final DebtView view;
  final List<Payment> payments;
  final List<ActivityEntry> activity;
}

/// Internal snapshot of the ledger tables, read in one pass.
class _LedgerData {
  const _LedgerData({
    required this.people,
    required this.debts,
    required this.totalsByDebt,
  });

  final Map<String, Person> people;
  final List<Debt> debts;

  /// Each debt's payments, already summed. Absent means no payments yet.
  final Map<String, PaymentTotals> totalsByDebt;
}
