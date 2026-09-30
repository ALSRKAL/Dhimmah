import 'package:dhimmah/app/router.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/entities/reminder.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/app_harness.dart';
import '../support/fake_notification_gateway.dart';

/// A reminder the user can trust: the whole lifecycle of a notification, driven
/// through the real service and a real database against a fake platform.
///
/// This is the regression matrix. Every case is a way a reminder app has been
/// known to let its user down — a duplicate after an edit, a stale notification
/// after a deletion, a reminder that outlives the debt being paid — and each one
/// ends by asserting the same thing: what the platform is holding is exactly
/// what the records ask for.
///
/// Two things about the shape of these expectations:
///
/// * A record's notifications are identified by the *record*, so every
///   assertion is written against payloads rather than counts of unrelated
///   notifications.
/// * A record asks for its lead **and** for the single nudge that follows if it
///   is still unpaid two days after the deadline. Both are its own, both are
///   armed in advance, and paying the record cancels both.
void main() {
  late AppDatabase db;
  late FakeNotificationGateway platform;
  late LedgerService service;

  final DateTime today = dateOnly(DateTime.now());

  setUp(() async {
    db = AppDatabase.memory();
    platform = FakeNotificationGateway();
    // The month-end summary is its own subject and would otherwise deliver on
    // the first write of every one of these tests.
    await SettingsRepositoryImpl(db).update(
      (AppSettings s) => s.copyWith(monthEndSummaryEnabled: false),
    );
    service = buildService(
      db,
      notifications: NotificationService(gateway: platform),
    );
    // What the app's own start-up does before it can write anything.
    await service.notifications.initialize(
      localizations: lookupAppLocalizations(const Locale('ar')),
    );
  });
  tearDown(() async => db.close());

  Future<Person> addPerson(String name) =>
      service.createPerson(PersonDraft(name: name));

  Future<Debt> addDebt({
    required Person person,
    DateTime? dueAt,
    List<ReminderLead> leads = const <ReminderLead>[ReminderLead.oneDayBefore],
    int principalMinor = 100000,
  }) =>
      service.createDebt(
        DebtDraft(
          direction: DebtDirection.iOwe,
          personIds: <String>[person.id],
          title: 'قرض',
          principalMinor: principalMinor,
          currency: AppCurrency.inr,
          issuedAt: today,
          dueAt: dueAt ?? addDays(today, 5),
          reminderLeads: leads,
        ),
      );

  Future<void> editDebt(Debt debt, {DateTime? dueAt, String? title}) =>
      service.updateDebt(
        debt.id,
        DebtDraft(
          direction: debt.direction,
          personIds: debt.personIds,
          title: title ?? debt.title,
          principalMinor: debt.principalMinor,
          currency: debt.currency,
          issuedAt: debt.issuedAt,
          dueAt: dueAt ?? debt.dueAt,
          reminderLeads: debt.reminderLeads,
        ),
      );

  /// The payloads the platform is holding.
  Set<String> armed() => platform.armedPayloads;

  /// The moments armed for one record, in order.
  List<DateTime> momentsFor(String payload) => <DateTime>[
        for (final FakeScheduledNotification n in platform.armed)
          if (n.payload == payload) n.when,
      ];

  /// The user's reminder time, which the default settings put at 20:00.
  DateTime atReminderTime(DateTime date, {int hour = 20}) =>
      DateTime(date.year, date.month, date.day, hour);

  /// The two moments a record asks for: the lead the user chose, and the single
  /// nudge that follows when it is still unpaid.
  ///
  /// The nudge is armed in advance rather than after the fact — an app that
  /// cannot run in the background has no other way to offer it — and a payment
  /// cancels it, which is what case 6 checks.
  List<DateTime> leadAndNudge(DateTime due, {int leadDays = 1, int hour = 20}) =>
      <DateTime>[
        atReminderTime(addDays(due, -leadDays), hour: hour),
        atReminderTime(
          addDays(due, NotificationPlanner.overdueNudgeAfterDays),
          hour: hour,
        ),
      ];

  test('1. creating a reminder arms exactly the record’s own notifications',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);

    expect(armed(), <String>{'debt:${debt.id}'});
    expect(
      momentsFor('debt:${debt.id}'),
      leadAndNudge(addDays(today, 5)),
      reason: 'the lead the user chose, and the one nudge after the deadline',
    );
  });

  test('2. saving the same record twice leaves exactly one set', () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    // The shape a double-tapped save produces: no await between the calls.
    await Future.wait<void>(<Future<void>>[editDebt(debt), editDebt(debt)]);

    expect(platform.held.keys.toSet(), before, reason: 'same ids, same set');
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  test('3. changing when a reminder fires replaces it, never doubles it',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    // Moving the reminder time in Settings moves every lead on every record.
    await SettingsRepositoryImpl(db).update(
      (AppSettings s) => s.copyWith(notificationHour: 9),
    );
    await service.refreshNotifications();

    final Set<int> after = platform.held.keys.toSet();
    expect(
      after.intersection(before),
      isEmpty,
      reason: 'a different moment is a different notification',
    );
    expect(after, hasLength(before.length), reason: 'replaced, not added to');
    expect(armed(), <String>{'debt:${debt.id}'});
    expect(
      momentsFor('debt:${debt.id}'),
      leadAndNudge(addDays(today, 5), hour: 9),
      reason: 'the same two moments, at the time the user just chose',
    );
    expect(
      platform.cancelled.toSet(),
      before,
      reason: 'the old moments were cancelled, not left behind',
    );
  });

  test('4. turning the reminder off cancels every notification for the record',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    await service.updateDebt(
      debt.id,
      DebtDraft(
        direction: debt.direction,
        personIds: debt.personIds,
        principalMinor: debt.principalMinor,
        currency: debt.currency,
        issuedAt: debt.issuedAt,
        dueAt: debt.dueAt,
        reminderLeads: const <ReminderLead>[ReminderLead.none],
      ),
    );

    expect(armed(), isEmpty);
    expect(platform.cancelled.toSet(), before);
  });

  test('5. deleting the record cancels every notification for it', () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    await service.deleteDebt(debt.id);

    expect(armed(), isEmpty);
    expect(platform.cancelled.toSet(), before);
  });

  test('6. a paid-off record stops reminding, and stops immediately',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed, principalMinor: 50000);
    expect(armed(), isNotEmpty);

    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 50000, paidAt: today),
    );

    expect(platform.held, isEmpty, reason: 'a settled debt must never nag');

    // And it stays that way through an edit that keeps it settled.
    await service.updateDebt(
      debt.id,
      DebtDraft(
        direction: debt.direction,
        personIds: debt.personIds,
        principalMinor: 40000,
        currency: debt.currency,
        issuedAt: debt.issuedAt,
        dueAt: debt.dueAt,
        reminderLeads: debt.reminderLeads,
      ),
    );
    expect(platform.held, isEmpty);
  });

  test('7. restarting the app leaves the schedule correct', () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    // A new process over the same store: the app re-plans from the records and
    // finds the platform already holding exactly that.
    final LedgerService restarted = buildService(
      db,
      notifications: NotificationService(gateway: platform),
    );
    await restarted.notifications.initialize(
      localizations: lookupAppLocalizations(const Locale('ar')),
    );
    await restarted.refreshNotifications();

    expect(platform.held.keys.toSet(), before);
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  test('8. a reboot that empties the platform’s store is repaired', () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    // The plugin re-arms its own store after a reboot; if the alarms were lost
    // instead, the next reconciliation has to put them back.
    platform.loseEverythingOnReboot();
    expect(platform.held, isEmpty);

    await service.refreshNotifications();

    expect(platform.held.keys.toSet(), before, reason: 'the same ids return');
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  test('9. a tap points at the record, never at a position in a list',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);

    for (final FakeScheduledNotification notification in platform.armed) {
      expect(
        AppRoutes.forNotificationPayload(notification.payload),
        AppRoutes.debtPath(debt.id),
        reason: 'every notification for the record opens the record',
      );
    }
    expect(
      AppRoutes.forNotificationPayload('debt:deleted-long-ago'),
      '/debts/deleted-long-ago',
      reason: 'a stale id still resolves; the screen is what says it is gone',
    );
  });

  test('10. two records due at the same moment are two notifications',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final DateTime due = addDays(today, 5);
    final Debt first = await addDebt(person: ahmed, dueAt: due);
    final Debt second = await addDebt(person: ahmed, dueAt: due);

    expect(armed(), <String>{'debt:${first.id}', 'debt:${second.id}'});
    expect(momentsFor('debt:${first.id}'), leadAndNudge(due));
    expect(momentsFor('debt:${second.id}'), leadAndNudge(due));
    expect(
      platform.held.keys.toSet(),
      hasLength(4),
      reason: 'four notifications, four identities',
    );
  });

  test('11. a record with three people is still one reminder', () async {
    final Person ahmed = await addPerson('أحمد');
    final Person khalid = await addPerson('خالد');
    final Person maryam = await addPerson('مريم');

    final Debt debt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id, khalid.id, maryam.id],
        title: 'فاتورة العشاء',
        principalMinor: 150000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 3),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );

    expect(armed(), <String>{'debt:${debt.id}'});
    expect(momentsFor('debt:${debt.id}'), leadAndNudge(addDays(today, 3)));
  });

  test('12. editing a record keeps the notification on the same record',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    await editDebt(debt, title: 'قرض السيارة');

    expect(
      platform.held.keys.toSet(),
      before,
      reason: 'the moments did not move, so neither did the notifications',
    );
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  test('13. moving the due date moves the reminder with it', () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    await editDebt(debt, dueAt: addDays(today, 12));

    final Set<int> after = platform.held.keys.toSet();
    expect(after.intersection(before), isEmpty);
    expect(
      momentsFor('debt:${debt.id}'),
      leadAndNudge(addDays(today, 12)),
      reason: 'a reminder is defined relative to the due date',
    );
  });

  test('14. a timezone change re-arms without losing or doubling anything',
      () async {
    final Person ahmed = await addPerson('أحمد');
    final Debt debt = await addDebt(person: ahmed);
    final Set<int> before = platform.held.keys.toSet();

    platform.timezone = 'Europe/London';
    final NotificationEnvironment environment =
        await service.notifications.refreshEnvironment();
    expect(environment.changed, isTrue);
    await service.refreshNotifications();

    expect(platform.held.keys.toSet(), before);
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  test('15. denied permission leaves the ledger completely usable', () async {
    final Person ahmed = await addPerson('أحمد');
    platform.enabled = false;
    await service.notifications.refreshEnvironment();

    final Debt debt = await addDebt(person: ahmed);

    expect(platform.held, isEmpty, reason: 'nothing can be delivered');
    final Debt stored = (await service.debts.getById(debt.id))!;
    expect(stored.principalMinor, 100000, reason: 'the record is saved anyway');
    expect(
      stored.reminderLeads,
      <ReminderLead>[ReminderLead.oneDayBefore],
      reason: 'and keeps the reminder the user chose',
    );

    // Granting it later arms what the records ask for, without a restart.
    platform.enabled = true;
    await service.notifications.refreshEnvironment();
    await service.refreshNotifications();
    expect(armed(), <String>{'debt:${debt.id}'});
  });

  group('the other things that ask to be remembered', () {
    test('an obligation period reminds, and stops the moment it is paid',
        () async {
      // Yearly, so exactly one period exists in the horizon and paying it can
      // be asserted against an empty set.
      await service.createObligation(
        ObligationDraft(
          name: 'التأمين',
          category: ObligationCategory.insurance,
          amountMinor: 200000,
          currency: AppCurrency.inr,
          frequency: RecurrenceFrequency.yearly,
          startAt: addDays(today, 2),
          reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
        ),
      );
      await service.ensureOccurrences();

      expect(armed(), hasLength(1));
      final String payload = platform.armed.first.payload;
      expect(payload.split(':').first, 'obligation');

      final Obligation obligation = (await service.obligations.getAll()).single;
      final ObligationOccurrence occurrence =
          (await service.obligations.allOccurrences()).single;
      await service.markObligationPaid(
        ObligationInstance(obligation: obligation, occurrence: occurrence),
      );

      expect(armed(), isEmpty, reason: 'a paid period is not reminded about');
    });

    test('a reminder the user made reminds once and then stops', () async {
      final Reminder reminder = await service.createReminder(
        ReminderDraft(title: 'اتصل بالمحاسب', dueAt: addDays(today, 1)),
      );
      expect(armed(), <String>{'reminder:${reminder.id}'});

      await service.setReminderDone(reminder.id, true);
      expect(armed(), isEmpty);
    });
  });

  group('the month-end summary', () {
    test('is not sent for a ledger with nothing in it', () async {
      await SettingsRepositoryImpl(db).update(
        (AppSettings s) => s.copyWith(monthEndSummaryEnabled: true),
      );
      await service.refreshNotifications();

      expect(
        platform.shown,
        isEmpty,
        reason: 'an install with no records is not told its totals are zero',
      );
    });

    test('is delivered once, and not again on the next write', () async {
      final Person ahmed = await addPerson('أحمد');
      await addDebt(person: ahmed);
      await SettingsRepositoryImpl(db).update(
        (AppSettings s) => s.copyWith(monthEndSummaryEnabled: true),
      );

      await service.refreshNotifications();
      expect(platform.shown, hasLength(1));
      expect(platform.shown.single.split(':').first, 'report');

      await service.refreshNotifications();
      expect(
        platform.shown,
        hasLength(1),
        reason: 'what was sent is recorded in the settings row',
      );
    });
  });

  group('one pass at a time', () {
    test('overlapping calls share one pass after the one that is running',
        () async {
      final Person ahmed = await addPerson('أحمد');
      await addDebt(person: ahmed);
      final int before = platform.pendingReads;

      await Future.wait(<Future<NotificationSyncResult>>[
        service.refreshNotifications(),
        service.refreshNotifications(),
        service.refreshNotifications(),
      ]);

      expect(
        platform.pendingReads - before,
        2,
        reason: 'the pass already running, then one more that reads what '
            'every waiting caller wrote — not one pass per caller',
      );
    });

    test('a record written while a pass runs is armed by the next pass',
        () async {
      final Person ahmed = await addPerson('أحمد');
      // A pass is running when the write lands, and it may have read the
      // records before it; the write's own refresh must not be lost to it.
      final Future<NotificationSyncResult> running =
          service.refreshNotifications();
      final Debt debt = await addDebt(person: ahmed);
      await running;

      expect(armed(), contains('debt:${debt.id}'));
    });

    test('a pass that fails does not strand the one queued behind it',
        () async {
      final Person ahmed = await addPerson('أحمد');
      final Debt debt = await addDebt(person: ahmed);
      platform.loseEverythingOnReboot();

      platform.pendingFailure = StateError('the platform refused');
      final Future<NotificationSyncResult> failing =
          service.refreshNotifications();
      final Future<NotificationSyncResult> queued =
          service.refreshNotifications();

      await expectLater(failing, throwsStateError);
      await queued;
      expect(armed(), contains('debt:${debt.id}'),
          reason: 'the queued pass still ran, and put the reminders back');
    });
  });

  group('the words follow the language', () {
    test('a pass in another language re-words what is armed, in place',
        () async {
      final Person ahmed = await addPerson('Ahmed');
      final Debt debt = await addDebt(person: ahmed);
      final Map<int, String> arabicTitles = <int, String>{
        for (final FakeScheduledNotification n in platform.held.values)
          n.id: n.title,
      };
      expect(arabicTitles, isNotEmpty);

      final LedgerService english = buildService(
        db,
        notifications: service.notifications,
        language: AppLanguage.english,
      );
      final NotificationSyncResult result = await english.refreshNotifications();

      expect(result.reworded, arabicTitles.length);
      expect(result.scheduled, 0);
      expect(result.cancelled, 0);
      expect(platform.held.keys.toSet(), arabicTitles.keys.toSet());
      for (final FakeScheduledNotification n in platform.held.values) {
        expect(n.title, isNot(arabicTitles[n.id]));
        expect(RegExp(r'[\u0600-\u06FF]').hasMatch(n.title), isFalse,
            reason: n.title);
      }
      expect(armed(), contains('debt:${debt.id}'));
    });
  });
}
