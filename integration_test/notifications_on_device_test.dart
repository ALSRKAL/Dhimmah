import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/domain/services/notification_planner.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Person;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/support/app_harness.dart';

/// The notification system against the real Android plugin.
///
/// `test/core/notifications/` proves the policy against a fake platform; this
/// proves the app talks to the real one: that channels are created, that the
/// alarms are actually registered with the phone, that a notification is
/// delivered, and that switching reminders off leaves nothing armed behind.
///
///   flutter test integration_test/notifications_on_device_test.dart -d `device`
///
/// Nothing is left on the device: every notification this test arms is cancelled
/// before it ends, and the delivered one is cleared immediately.
///
/// Android 13+ installs an app with notifications off, so the test asks the
/// phone which state it is in and checks the matching behaviour. To exercise the
/// armed path on a fresh install, allow notifications for the app first:
///
///   adb shell pm grant com.dhimmah.dhimmah android.permission.POST_NOTIFICATIONS
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));

  /// The Android side of the plugin, for reading back what the system holds.
  AndroidFlutterLocalNotificationsPlugin android() =>
      FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()!;

  testWidgets('the phone arms, delivers and clears the reminders', (
    WidgetTester tester,
  ) async {
    final AppDatabase db = AppDatabase.memory();
    final NotificationService notifications = NotificationService();
    final DateTime today = dateOnly(DateTime.now());

    await notifications.initialize(localizations: l10n);
    // Best effort: whatever happens, nothing this test armed is left behind.
    addTearDown(() async {
      await notifications.cancelAll();
    });

    expect(
      notifications.supportsScheduling,
      isTrue,
      reason: 'this is running on a phone',
    );
    final bool allowed =
        notifications.permission == NotificationPermission.granted;
    // ignore: avoid_print
    print('DEVICE permission: ${notifications.permission.name}');

    // The month-end summary is armed in the last days of every month and is
    // not one of the records' reminders this test counts.
    await SettingsRepositoryImpl(db).update(
      (AppSettings s) => s.copyWith(monthEndSummaryEnabled: false),
    );
    final LedgerService service = buildService(db, notifications: notifications);
    final Person ahmed = await service.createPerson(
      const PersonDraft(name: 'أحمد'),
    );
    // Two records asking for a reminder, and one asking for nothing.
    final DebtDraft first = DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[ahmed.id],
      title: 'قرض سيارة',
      principalMinor: 100000,
      currency: AppCurrency.inr,
      issuedAt: today,
      dueAt: addDays(today, 3),
      reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
    );
    await service.createDebt(first);
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: 'سلفة',
        principalMinor: 50000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 5),
        reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
      ),
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'بلا تذكير',
        principalMinor: 7000,
        currency: AppCurrency.inr,
        issuedAt: today,
        dueAt: addDays(today, 2),
        reminderLeads: const <ReminderLead>[ReminderLead.none],
      ),
    );

    final int armed = await notifications.pendingCount();
    // ignore: avoid_print
    print('DEVICE armed after a write: $armed');

    if (!allowed) {
      // The state a fresh install starts in: nothing may be armed, and the
      // ledger has to be completely usable anyway.
      expect(armed, 0);
      expect(await db.debtsDao.getAll(), hasLength(3));
      await SettingsRepositoryImpl(db).update(
        (AppSettings s) => s.copyWith(notificationsEnabled: true),
      );
      await service.refreshNotifications();
      expect(
        await notifications.pendingCount(),
        0,
        reason: 'the app switch cannot override the system',
      );
      // ignore: avoid_print
      print('DEVICE denied path: nothing armed, ledger intact');
      await db.close();
      return;
    }

    expect(
      armed,
      4,
      reason: 'two records, each with a lead and the nudge after its deadline — '
          'and nothing for the record that asked for no reminder',
    );

    // Idempotence on the real plugin: a second pass changes nothing.
    final NotificationSyncResult again = await service.refreshNotifications();
    expect(again.scheduled, 0);
    expect(again.cancelled, 0);
    expect(await notifications.pendingCount(), armed);

    // A reminder that is delivered, checked against the system's own list and
    // then cleared.
    final NotificationComposer composer = NotificationComposer(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    );
    final ComposedNotification delivered = composer.compose(
      NotificationIntent(
        kind: NotificationKind.debtDueToday,
        when: DateTime.now(),
        payload: 'debt:${ahmed.id}',
        personName: 'أحمد',
        amount: const Money(100000, AppCurrency.inr),
        direction: DebtDirection.iOwe,
      ),
      NotificationComposer.idFor(
        NotificationIntent(
          kind: NotificationKind.debtDueToday,
          when: DateTime.now(),
          payload: 'debt:${ahmed.id}',
        ),
      ),
    );
    await notifications.showNow(delivered);
    final List<ActiveNotification> active =
        await android().getActiveNotifications();
    // ignore: avoid_print
    print('DEVICE delivered: ${active.length} notification(s) in the shade');
    expect(
      active,
      isNotEmpty,
      reason: 'the notification really reached the system',
    );
    for (final ActiveNotification notification in active) {
      final int? id = notification.id;
      if (id != null) await android().cancel(id: id);
    }

    // Turning reminders off has to leave the phone with nothing armed.
    await SettingsRepositoryImpl(db).update(
      (AppSettings s) => s.copyWith(notificationsEnabled: false),
    );
    await service.refreshNotifications();
    expect(await notifications.pendingCount(), 0);

    await db.close();
  });
}
