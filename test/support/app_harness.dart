import 'dart:io';

import 'package:dhimmah/app/app.dart';
import 'package:dhimmah/app/backup_providers.dart';
import 'package:dhimmah/app/providers.dart';
import 'package:dhimmah/core/files/backup_location_repository.dart';
import 'package:dhimmah/core/files/file_gateway.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/security/biometric_service.dart';
import 'package:dhimmah/core/security/pin_service.dart';
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
/// [notifications] lets a test hand the service a fake platform, so the
/// delivery policy can be driven without a phone.
/// [language] is the language the service writes notifications in — Arabic,
/// like the phone the suite runs on, unless a test is about another one.
LedgerService buildService(
  AppDatabase db, {
  NotificationService? notifications,
  AppLanguage language = AppLanguage.arabic,
}) {
  final AppLocalizations l10n = lookupAppLocalizations(Locale(language.code));
  return LedgerService(
    database: db,
    people: PersonRepositoryImpl(db),
    debts: DebtRepositoryImpl(db),
    payments: PaymentRepositoryImpl(db),
    obligations: ObligationRepositoryImpl(db),
    reminders: ReminderRepositoryImpl(db),
    activity: ActivityRepositoryImpl(db),
    settings: SettingsRepositoryImpl(db),
    notifications: notifications ?? NotificationService(),
    localizations: () => l10n,
    composer: () => NotificationComposer(
      localizations: l10n,
      formatting: AppFormatting(
        language: language,
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
      personIds: <String>[ahmed.id],
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
      personIds: <String>[khalid.id],
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
        personIds: <String>[ahmed.id],
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

/// A keystore the test writes by hand: it can hold a PIN, be empty, or refuse
/// to answer at all — the three states the lock gate has to tell apart, and the
/// reason the gate could not be tested against the real [PinService], whose
/// storage is a platform plugin the test environment does not have.
class FakePinService implements PinService {
  FakePinService({this.configured = false, this.readError});

  /// Whether a digest exists in the keystore.
  bool configured;

  /// When set, every keystore access throws it — the platform that cannot be
  /// read, as opposed to one that is empty.
  final Object? readError;

  String? _pin;

  @override
  Future<bool> isConfigured() async {
    if (readError != null) throw readError!;
    return configured;
  }

  @override
  Future<void> setPin(String pin) async {
    if (readError != null) throw readError!;
    _pin = pin;
    configured = true;
  }

  @override
  Future<PinVerification> verify(String pin) async {
    if (readError != null) throw readError!;
    if (!configured) {
      return const PinVerification(accepted: false, configured: false);
    }
    return PinVerification(accepted: pin == _pin, configured: true);
  }

  @override
  Future<void> clear() async {
    if (readError != null) throw readError!;
    _pin = null;
    configured = false;
  }

  @override
  Future<Duration> lockoutRemaining() async => Duration.zero;
}

/// Pumps the whole app against [db].
///
/// [clock] stands in for the wall clock everywhere the app reads the time
/// through `clockProvider`, so a test can move time instead of waiting for it.
///
/// Returns the container the app was built on, so a test that needs to wait for
/// a real asynchronous step — a directory read, a file write — can watch the
/// provider that holds its result instead of guessing how many frames to pump.
Future<ProviderContainer> pumpDhimmah(
  WidgetTester tester, {
  required AppDatabase db,
  bool onboardingCompleted = true,
  AppSettings? settings,
  NotificationPermission? notificationPermission,
  FileGateway? fileGateway,
  Directory? backupDirectory,
  BackupLocationRepository? backupFolders,
  PinService? pinService,
  BiometricService? biometricService,
  Future<bool> Function(Uri)? urlOpener,
  NotificationService? notificationService,
  DateTime Function()? clock,
  bool firstFrameOnly = false,
}) async {
  if (settings != null) {
    await db.settingsDao.replace(
      Setting(
        id: Settings.singletonId,
        languagePreference: settings.languagePreference,
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
        // Taken from the caller rather than forced. It used to be pinned to
        // true, which meant a test could not express the state an upgrade can
        // land in — automatic saving switched off — and the screen was free to
        // claim protection while nothing was watching.
        backupAutoEnabled: settings.backupAutoEnabled,
      ),
    );
  }

  final ProviderContainer container = ProviderContainer(
    // The list's element type comes from the constructor, so no test has to
    // name Riverpod's override type (it is not part of the public API).
    overrides: [
      databaseProvider.overrideWithValue(db),
      if (notificationPermission != null)
        notificationPermissionProvider.overrideWith(
          (Ref ref) =>
              Stream<NotificationPermission>.value(notificationPermission),
        ),
      if (fileGateway != null)
        fileGatewayProvider.overrideWithValue(fileGateway),
      if (backupDirectory != null)
        backupDirectoryProvider.overrideWithValue(backupDirectory),
      if (backupFolders != null)
        backupLocationRepositoryProvider.overrideWithValue(backupFolders),
      if (pinService != null) pinServiceProvider.overrideWithValue(pinService),
      if (biometricService != null)
        biometricServiceProvider.overrideWithValue(biometricService),
      if (urlOpener != null) urlOpenerProvider.overrideWithValue(urlOpener),
      if (notificationService != null)
        notificationServiceProvider.overrideWithValue(notificationService),
      if (clock != null) clockProvider.overrideWithValue(clock),
    ],
  );
  addTearDown(container.dispose);

  // What `main` does before `runApp`, so the first frame a test sees is the one
  // a phone would draw: already in the stored language and theme.
  await loadBootSettings(container);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: DhimmahApp(onboardingCompleted: onboardingCompleted),
    ),
  );
  // What a phone draws before anything asynchronous has answered.
  if (firstFrameOnly) return container;
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}
