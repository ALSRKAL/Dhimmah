import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/utils/dates.dart';
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
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Shared setup for widget tests: a real database, a real service, and the real
/// app pumped against them.
///
/// The app is exercised as a whole rather than screen by screen, so a change to
/// navigation or to a shared widget shows up here instead of only on a device.
LedgerService buildService(AppDatabase db) {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  return LedgerService(
    database: db,
    people: PersonRepositoryImpl(db),
    debts: DebtRepositoryImpl(db),
    payments: PaymentRepositoryImpl(db),
    obligations: ObligationRepositoryImpl(db),
    reminders: ReminderRepositoryImpl(db),
    activity: ActivityRepositoryImpl(db),
    settings: SettingsRepositoryImpl(db),
    notifications: NotificationService(),
    localizations: () => l10n,
    composer: () => NotificationComposer(
      localizations: l10n,
      formatting: AppFormatting(
        language: AppLanguage.arabic,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
    ),
    clock: DateTime.now,
  );
}

/// A ledger with something in each direction: one late debt, one partial, one
/// payment already received, and a recurring bill.
///
/// Long Arabic names and a second currency on purpose — short placeholder names
/// hide exactly the layout problems worth catching.
///
/// Returns the people it created, so a test can open one of them by id.
Future<({Person ahmed, Person khalid})> seedLedger(
  AppDatabase db, {
  AppCurrency extraCurrency = AppCurrency.usd,
}) async {
  final LedgerService service = buildService(db);
  final DateTime today = dateOnly(DateTime.now());

  final Person ahmed = await service.createPerson(
    const PersonDraft(name: 'محمد أحمد عبدالرحمن', phone: '+967 771 234 567'),
  );
  final Person khalid = await service.createPerson(
    const PersonDraft(name: 'خالد العلي'),
  );

  final Debt late = await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personId: ahmed.id,
      title: 'قرض سيارة',
      principalMinor: 3500000,
      currency: AppCurrency.inr,
      issuedAt: addDays(today, -90),
      dueAt: addDays(today, -4),
    ),
  );
  await service.recordPayment(
    late.id,
    PaymentDraft(amountMinor: 1200000, paidAt: addDays(today, -8)),
  );

  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personId: khalid.id,
      title: 'سلفة',
      principalMinor: 1500000,
      currency: AppCurrency.inr,
      issuedAt: addDays(today, -30),
      dueAt: addDays(today, 2),
    ),
  );

  if (extraCurrency != AppCurrency.inr) {
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personId: ahmed.id,
        title: 'Transfer',
        principalMinor: 120000,
        currency: extraCurrency,
        issuedAt: addDays(today, -3),
        dueAt: addDays(today, 20),
      ),
    );
  }

  await service.createObligation(
    ObligationDraft(
      name: 'فاتورة الإنترنت',
      category: ObligationCategory.telecom,
      amountMinor: 120000,
      currency: AppCurrency.inr,
      frequency: RecurrenceFrequency.monthly,
      startAt: DateTime(today.year, today.month, 5),
      dayOfMonth: 5,
    ),
  );
  await service.ensureOccurrences();

  return (ahmed: ahmed, khalid: khalid);
}

/// Pumps the whole app against [db].
Future<void> pumpDhimmah(
  WidgetTester tester, {
  required AppDatabase db,
  bool onboardingCompleted = true,
  AppSettings? settings,
}) async {
  if (settings != null) {
    await db.settingsDao.replace(
      Setting(
        id: Settings.singletonId,
        language: settings.language,
        themeMode: settings.themeMode,
        numerals: settings.numerals,
        defaultCurrencyCode: settings.defaultCurrency.code,
        notificationsEnabled: settings.notificationsEnabled,
        notificationHour: settings.notificationHour,
        notificationMinute: settings.notificationMinute,
        defaultReminderLeads: settings.defaultReminderLeads,
        monthEndSummaryEnabled: settings.monthEndSummaryEnabled,
        monthEndDay: settings.monthEndDay,
        monthEndHour: settings.monthEndHour,
        monthEndMinute: settings.monthEndMinute,
        dueSoonWindowDays: settings.dueSoonWindowDays,
        lockEnabled: settings.lockEnabled,
        biometricEnabled: settings.biometricEnabled,
        onboardingCompleted: true,
      ),
    );
  }

  final ProviderContainer container = ProviderContainer(
    overrides: [databaseProvider.overrideWithValue(db)],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: DhimmahApp(onboardingCompleted: onboardingCompleted),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
