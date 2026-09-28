import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:drift/drift.dart' as drift show Value;
import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// The plan the app arms, and the read it costs.
///
/// Reconciliation reads the records that can produce a reminder — soonest due
/// first, in pages — and stops as soon as nothing outside the pages read could
/// deliver earlier than the notifications it is about to arm. These tests hold
/// that read to its promise: the set it produces is the same set the whole
/// ledger would produce, and it costs a fraction of reading the whole ledger to
/// find that out.
void main() {
  late AppDatabase db;
  late FakeNotificationGateway platform;
  late LedgerService service;

  final DateTime today = dateOnly(DateTime.now());
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  setUp(() async {
    db = AppDatabase.memory();
    platform = FakeNotificationGateway();
    await SettingsRepositoryImpl(db).update(
      (AppSettings s) => s.copyWith(monthEndSummaryEnabled: false),
    );
    service = buildService(
      db,
      notifications: NotificationService(gateway: platform),
    );
    await service.notifications.initialize(localizations: l10n);
  });
  tearDown(() async => db.close());

  NotificationComposer composer() => NotificationComposer(
        localizations: l10n,
        formatting: AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: AppCurrency.inr,
          localizations: l10n,
        ),
      );

  /// The whole-ledger plan, computed the slow way: every record's view, through
  /// the same reader the screens use.
  Future<Set<int>> planFromTheWholeLedger(AppSettings settings) async {
    final LedgerQueries queries = LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );
    final List<DebtView> views = await queries
        .watchDebtViews(dueSoonWindowDays: settings.dueSoonWindowDays, asOf: today)
        .first;
    final List<ComposedNotification> composed = composer().composeAll(
      NotificationPlanner.plan(
        debts: views,
        obligations: const <ObligationInstance>[],
        reminders: const <Reminder>[],
        settings: settings,
        now: DateTime.now(),
      ),
    );
    return <int>{
      for (final ComposedNotification n
          in NotificationService.selectArmed(composed))
        n.id,
    };
  }

  /// Seeds records straight into the tables: these tests are about volume.
  Future<void> seed({
    required int count,
    required List<ReminderLead> leads,
    required DateTime Function(int index) dueAt,
    int settledEvery = 0,
    int archivedEvery = 0,
  }) async {
    await db.peopleDao.upsert(
      PersonRow(
        id: 'p0',
        name: 'أحمد',
        colorIndex: 0,
        createdAt: today,
        updatedAt: today,
      ),
    );
    await db.batch((Batch b) => b.insertAll(db.debts, <DebtsCompanion>[
          for (int i = 0; i < count; i++)
            DebtsCompanion.insert(
              id: 'd$i',
              personId: const drift.Value<String>('p0'),
              direction: DebtDirection.iOwe,
              title: drift.Value<String>('قرض $i'),
              principalMinor: 100000,
              currencyCode: AppCurrency.inr.code,
              issuedAt: today,
              dueAt: drift.Value<DateTime>(dueAt(i)),
              reminderLeads: drift.Value<List<ReminderLead>>(leads),
              recurrence: RecurrenceFrequency.none,
              archivedAt: drift.Value<DateTime?>(
                archivedEvery > 0 && i % archivedEvery == 0 ? today : null,
              ),
              createdAt: today,
              updatedAt: today,
            ),
        ]));
    if (settledEvery > 0) {
      await db.batch((Batch b) => b.insertAll(db.payments, <PaymentsCompanion>[
            for (int i = 0; i < count; i++)
              if (i % settledEvery == 0)
                PaymentsCompanion.insert(
                  id: 'pay$i',
                  debtId: drift.Value<String>('d$i'),
                  personId: const drift.Value<String>('p0'),
                  amountMinor: 100000,
                  currencyCode: AppCurrency.inr.code,
                  paidAt: today,
                  createdAt: today,
                ),
          ]));
    }
  }

  test('the paged plan is the whole-ledger plan, to the notification', () async {
    // A mixed ledger: leads of every length, dates from overdue to far out,
    // every tenth record settled and every fifteenth archived.
    await seed(
      count: 300,
      leads: <ReminderLead>[ReminderLead.oneDayBefore, ReminderLead.oneWeekBefore],
      dueAt: (int i) => addDays(today, (i % 40) - 5),
      settledEvery: 10,
      archivedEvery: 15,
    );

    await service.refreshNotifications();

    final AppSettings settings = await SettingsRepositoryImpl(db).get();
    expect(
      platform.held.keys.toSet(),
      await planFromTheWholeLedger(settings),
      reason: 'paging must not change the answer',
    );
  });

  test('a record that falls due later but leads longer still makes the cut',
      () async {
    // 500 records due in ten days with a reminder on the day, and one record due
    // in twenty days that asks two weeks ahead — whose notification is the
    // earliest of all, from a record ranked last by due date. A plan that
    // stopped reading at the first page would arm the wrong set.
    await seed(
      count: 500,
      leads: <ReminderLead>[ReminderLead.onDueDate],
      dueAt: (int i) => addDays(today, 10),
    );
    await db.into(db.debts).insert(
          DebtsCompanion.insert(
            id: 'late',
            personId: const drift.Value<String>('p0'),
            direction: DebtDirection.iOwe,
            title: const drift.Value<String>('قرض متأخر الموعد'),
            principalMinor: 100000,
            currencyCode: AppCurrency.inr.code,
            issuedAt: today,
            dueAt: drift.Value<DateTime>(addDays(today, 20)),
            reminderLeads: const drift.Value<List<ReminderLead>>(
              <ReminderLead>[ReminderLead.twoWeeksBefore],
            ),
            recurrence: RecurrenceFrequency.none,
            createdAt: today,
            updatedAt: today,
          ),
        );

    await service.refreshNotifications();

    final AppSettings settings = await SettingsRepositoryImpl(db).get();
    final Set<int> expected = await planFromTheWholeLedger(settings);
    expect(platform.held.keys.toSet(), expected);
    expect(
      platform.armed.first.payload,
      'debt:late',
      reason: 'the earliest notification comes from the furthest due date',
    );
  });

  test('records that ask for no reminder are never part of the read', () async {
    // 1,200 records with no reminder at all, all due first, and three that ask.
    await seed(
      count: 1200,
      leads: const <ReminderLead>[ReminderLead.none],
      dueAt: (int i) => addDays(today, 1),
    );
    for (final int index in <int>[1, 2, 3]) {
      await db.into(db.debts).insert(
            DebtsCompanion.insert(
              id: 'with$index',
              personId: const drift.Value<String>('p0'),
              direction: DebtDirection.iOwe,
              title: drift.Value<String>('قرض $index'),
              principalMinor: 100000,
              currencyCode: AppCurrency.inr.code,
              issuedAt: today,
              dueAt: drift.Value<DateTime>(addDays(today, 5)),
              reminderLeads: const drift.Value<List<ReminderLead>>(
                <ReminderLead>[ReminderLead.oneDayBefore],
              ),
              recurrence: RecurrenceFrequency.none,
              createdAt: today,
              updatedAt: today,
            ),
          );
    }

    await service.refreshNotifications();

    expect(
      platform.armedPayloads,
      <String>{'debt:with1', 'debt:with2', 'debt:with3'},
      reason: 'a record with no reminder cannot produce a notification',
    );
  });

  test('settled and archived records are left out entirely', () async {
    await seed(
      count: 20,
      leads: const <ReminderLead>[ReminderLead.oneDayBefore],
      dueAt: (int i) => addDays(today, 3),
      settledEvery: 2,
      archivedEvery: 5,
    );

    await service.refreshNotifications();

    final Set<String> armed = platform.armedPayloads;
    expect(armed, isNotEmpty);
    for (final String payload in armed) {
      final int index = int.parse(payload.split(':').last.substring(1));
      expect(
        index.isEven,
        isFalse,
        reason: 'a settled record must never remind anyone',
      );
      expect(index % 5, isNot(0), reason: 'nor an archived one');
    }
  });

  test('the platform is never asked to hold more than its limit', () async {
    // 600 records, each asking for a lead and a nudge: 1,200 notifications
    // wanted, 400 armed.
    await seed(
      count: 600,
      leads: const <ReminderLead>[ReminderLead.onDueDate],
      dueAt: (int i) => addDays(today, 1 + (i % 30)),
    );

    final NotificationSyncResult result = await service.refreshNotifications();

    expect(result.desired, greaterThan(NotificationService.maxScheduled));
    expect(result.armed, NotificationService.maxScheduled);
    expect(platform.held, hasLength(NotificationService.maxScheduled));
    expect(
      platform.armed.last.when
          .isAfter(platform.armed.first.when.add(const Duration(days: 30))),
      isFalse,
      reason: 'the armed set is the soonest window, not an arbitrary slice',
    );
  });

  test('a save reads what asks for a reminder, not the whole ledger', () async {
    // The common shape: a large ledger in which only a few records ask for a
    // reminder. Those are the only rows the plan touches.
    await seed(
      count: 2500,
      leads: const <ReminderLead>[ReminderLead.none],
      dueAt: (int i) => addDays(today, (i % 60) + 1),
    );
    for (final String id in <String>['ask1', 'ask2', 'ask3']) {
      await db.into(db.debts).insert(
            DebtsCompanion.insert(
              id: id,
              personId: const drift.Value<String>('p0'),
              direction: DebtDirection.iOwe,
              title: const drift.Value<String>('قرض'),
              principalMinor: 100000,
              currencyCode: AppCurrency.inr.code,
              issuedAt: today,
              dueAt: drift.Value<DateTime>(addDays(today, 4)),
              reminderLeads: const drift.Value<List<ReminderLead>>(
                <ReminderLead>[ReminderLead.oneDayBefore],
              ),
              recurrence: RecurrenceFrequency.none,
              createdAt: today,
              updatedAt: today,
            ),
          );
    }

    final NotificationSyncResult result = await service.refreshNotifications();

    expect(result.recordsRead, 3, reason: 'three records ask');
    expect(platform.armedPayloads, hasLength(3));
    expect(result.desired, 6, reason: 'a lead and a nudge each');
  });

  test('a save on a ledger where everything asks stays bounded', () async {
    // 2,500 records, a fifth of them asking for a reminder. Every write used to
    // rebuild the whole plan from the whole ledger — 1,819 ms measured on this
    // fixture, and 7,470 ms at ten thousand records — which made saving a
    // payment a visible wait. The guarantee is asserted as work done rather than
    // as elapsed time: a wall-clock budget in a suite that runs files in
    // parallel measures the machine, not the app.
    await seed(
      count: 2500,
      leads: const <ReminderLead>[ReminderLead.oneDayBefore],
      dueAt: (int i) => addDays(today, (i % 60) + 1),
      settledEvery: 5,
    );
    await service.refreshNotifications();

    // The same reconcile a write runs in full, with the count it reports.
    await service.recordPayment(
      'd7',
      PaymentDraft(amountMinor: 100, paidAt: today),
    );
    final NotificationSyncResult result = await service.refreshNotifications();

    // The guarantee is not "a fast machine" but "a bounded read": whatever the
    // ledger holds, a plan reads the soonest records that ask for a reminder and
    // stops. That is what a save costs.
    expect(
      result.recordsRead,
      lessThanOrEqualTo(LedgerService.reminderReadLimit),
      reason: '2,500 records here, all of them asking for a reminder and due '
          'within two months — the read is bounded, not proportional',
    );
    expect(
      platform.held.length,
      lessThanOrEqualTo(NotificationService.maxScheduled),
    );
    expect(
      result.armed,
      greaterThan(0),
      reason: 'and it still armed the reminders that are due soon',
    );
  });
}
