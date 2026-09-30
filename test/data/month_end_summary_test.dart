import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_notification_gateway.dart';

/// The month-end summary: armed to arrive at the moment the user chose, caught
/// up when the phone could not deliver it, never twice and never skipped.
///
/// Driven through the real service and database on a clock the test moves,
/// because every one of the failures this guards against was a question of
/// *which day* the app was opened on:
///
/// * nothing armed the summary at all, so it only ever arrived late;
/// * a catch-up recorded the day it was delivered, which is in the following
///   month, so the following month's summary was skipped — every other month;
/// * "paid" added up whole debts, and measured the month of delivery.
void main() {
  late AppDatabase db;
  late FakeNotificationGateway platform;
  late SettingsRepositoryImpl settings;
  late LedgerService service;
  late DateTime now;

  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  final AppFormatting formatting = AppFormatting(
    language: AppLanguage.arabic,
    numerals: NumeralsStyle.latin,
    defaultCurrency: AppCurrency.inr,
    localizations: l10n,
  );

  setUp(() async {
    db = AppDatabase.memory();
    platform = FakeNotificationGateway();
    settings = SettingsRepositoryImpl(db);
    now = DateTime(2026, 9, 5, 10);
    service = LedgerService(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
      settings: settings,
      notifications: NotificationService(gateway: platform),
      localizations: () => l10n,
      composer: () =>
          NotificationComposer(localizations: l10n, formatting: formatting),
      clock: () => now,
    );
    await service.notifications.initialize(localizations: l10n);
    // August's summary is already behind this phone, so each test starts from
    // a clean month.
    await settings.update(
      (AppSettings s) => s.copyWith(lastSummarySentOn: DateTime(2026, 8, 31)),
    );
  });
  tearDown(() async => db.close());

  Future<Debt> addDebt({
    AppCurrency currency = AppCurrency.inr,
    int principalMinor = 100000,
  }) async {
    final Person person =
        await service.createPerson(const PersonDraft(name: 'أحمد'));
    return service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[person.id],
        title: 'سلفة',
        principalMinor: principalMinor,
        currency: currency,
        issuedAt: DateTime(2026, 9),
      ),
    );
  }

  Iterable<FakeScheduledNotification> armedSummaries() => platform.armed
      .where((FakeScheduledNotification n) => n.payload.startsWith('report:'));

  test('is armed in its last days, at its moment, and not caught up again',
      () async {
    await addDebt();
    expect(armedSummaries(), isEmpty,
        reason: 'weeks out, nothing reads the ledger for it yet');

    now = DateTime(2026, 9, 28, 10);
    await service.refreshNotifications();

    final FakeScheduledNotification summary = armedSummaries().single;
    expect(summary.payload, 'report:2026-09');
    expect(summary.when, DateTime(2026, 9, 30, 20));
    expect((await settings.get()).lastSummarySentOn, DateTime(2026, 9, 30));

    // The phone delivered it at 20:00. The first launch afterwards must not
    // deliver September again.
    now = DateTime(2026, 10, 1, 9);
    await service.refreshNotifications();
    expect(platform.shown, isEmpty);
  });

  test('a catch-up does not cost the next month its summary', () async {
    await addDebt();

    // The app was closed through September's moment.
    now = DateTime(2026, 10, 2, 10);
    await service.refreshNotifications();
    expect(platform.shown, <String>['report:2026-09']);

    // And through October's.
    now = DateTime(2026, 11, 2, 10);
    await service.refreshNotifications();
    expect(platform.shown, <String>['report:2026-09', 'report:2026-10'],
        reason: 'the catch-up for September used to record 2 October, and '
            'October was then taken as already sent');

    // Nothing is delivered twice.
    await service.refreshNotifications();
    expect(platform.shown, hasLength(2));
  });

  test('"paid" is what was paid during the month it summarises', () async {
    // 1,000 owed to the user.
    final Debt debt = await addDebt();
    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 20000, paidAt: DateTime(2026, 9, 10)),
    );

    // The first write after September's moment is a payment made in October.
    now = DateTime(2026, 10, 1, 10);
    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 35000, paidAt: DateTime(2026, 10)),
    );

    expect(platform.shown, <String>['report:2026-09']);
    final String body = platform.shownBodies.single;
    expect(body, contains(formatting.amount(Money(20000, AppCurrency.inr))));
    expect(
      body,
      isNot(contains(formatting.amount(Money(55000, AppCurrency.inr)))),
      reason: 'the lifetime total of a debt last paid in October is not '
          'what September paid',
    );
  });

  test('the figures are stated in the currency they were counted in',
      () async {
    // Nothing in the default currency: the ledger's main currency is USD.
    final Debt debt =
        await addDebt(currency: AppCurrency.usd, principalMinor: 70000);
    await service.recordPayment(
      debt.id,
      PaymentDraft(amountMinor: 10000, paidAt: DateTime(2026, 9, 12)),
    );

    now = DateTime(2026, 10, 2, 10);
    await service.refreshNotifications();

    final String body = platform.shownBodies.single;
    expect(body, contains(formatting.amount(Money(60000, AppCurrency.usd))));
    expect(
      body,
      isNot(contains(formatting.amount(Money(60000, AppCurrency.inr)))),
    );
  });

  test('a ledger with nothing in it is not armed a summary of zeroes',
      () async {
    now = DateTime(2026, 9, 29, 10);
    await service.refreshNotifications();
    expect(armedSummaries(), isEmpty);
    expect(platform.shown, isEmpty);
  });
}
