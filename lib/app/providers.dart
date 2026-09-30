import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/formatting/app_formatting.dart';
import '../core/money/currency.dart';
import '../core/notifications/notification_composer.dart';
import '../core/notifications/notification_service.dart';
import '../core/security/biometric_service.dart';
import '../core/security/pin_service.dart';
import '../core/utils/dates.dart';
import '../data/database/app_database.dart';
import '../data/read_models/ledger_queries.dart';
import '../data/repositories/activity_repository_impl.dart';
import '../data/repositories/debt_repository_impl.dart';
import '../data/repositories/obligation_repository_impl.dart';
import '../data/repositories/person_repository_impl.dart';
import '../data/repositories/reminder_repository_impl.dart';
import '../data/repositories/settings_repository_impl.dart';
import '../data/services/data_export_service.dart';
import '../data/services/ledger_service.dart';
import '../data/services/statement_service.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/debt.dart';
import '../domain/entities/ledger_views.dart';
import '../domain/entities/monthly_report.dart';
import '../domain/entities/obligation.dart';
import '../domain/entities/person.dart';
import '../domain/entities/reminder.dart';
import '../domain/enums/preference_enums.dart';
import '../domain/enums/recurrence.dart';
import '../domain/repositories/repositories.dart';
import '../l10n/enum_labels.dart';
import '../l10n/generated/app_localizations.dart';

// ---------------------------------------------------------------------------
// Infrastructure
// ---------------------------------------------------------------------------

/// The open database. Closing is wired to the provider's disposal so hot restart
/// and tests do not leak file handles.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>((Ref ref) {
  final AppDatabase database = AppDatabase.open();
  ref.onDispose(() => unawaited(database.close()));
  return database;
});

/// A clock, injected so tests can move time instead of waiting for it.
final Provider<DateTime Function()> clockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// The installed app's version, as the platform reports it.
///
/// Read from the build rather than written down: the About screen used to print
/// a hardcoded `1.0.0`, which is correct exactly until the first release and
/// then quietly lies about which build a user is running.
///
/// This is display only. Whether an update exists is Google Play's answer — see
/// `app_update_controller.dart` — and the app never compares these numbers to
/// decide anything.
final FutureProvider<AppVersion> appVersionProvider =
    FutureProvider<AppVersion>((Ref ref) => AppVersion.read());

/// The two numbers the platform holds, and nothing else.
@immutable
class AppVersion {
  const AppVersion({required this.name, required this.build});

  /// `versionName` — what a person reads.
  final String name;

  /// `versionCode` — what Google Play compares, and what support asks for.
  final String build;

  /// Reads them from the installed package.
  ///
  /// Falls back to the values in `pubspec.yaml`'s shape rather than to an empty
  /// string: on a platform where the plugin has no implementation — which is
  /// every widget test — the screen should still say something true-looking
  /// rather than "Version ()".
  static Future<AppVersion> read() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      return AppVersion(name: info.version, build: info.buildNumber);
    } on Object {
      return const AppVersion(name: '—', build: '—');
    }
  }
}

/// Today, as a plain date.
///
/// Everything that decides whether something is late reads this, so a single
/// refresh at midnight or on resume moves the whole app forward together.
class TodayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => dateOnly(DateTime.now());

  /// Re-reads the clock; only notifies when the calendar day actually changed.
  void refresh() {
    final DateTime now = dateOnly(DateTime.now());
    if (now != state) state = now;
  }
}

final NotifierProvider<TodayNotifier, DateTime> todayProvider =
    NotifierProvider<TodayNotifier, DateTime>(TodayNotifier.new);

final Provider<NotificationService> notificationServiceProvider =
    Provider<NotificationService>((Ref ref) {
  final NotificationService service = NotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Whether the phone will actually show Dhimmah's notifications.
///
/// A stream rather than a value read once: the user can grant or revoke this in
/// the system settings while the app is in the background, and every screen that
/// speaks about reminders has to tell the truth about it.
final StreamProvider<NotificationPermission> notificationPermissionProvider =
    StreamProvider<NotificationPermission>((Ref ref) {
  return ref.watch(notificationServiceProvider).permissionChanges;
});

final Provider<PinService> pinServiceProvider =
    Provider<PinService>((Ref ref) => PinService());

final Provider<BiometricService> biometricServiceProvider =
    Provider<BiometricService>((Ref ref) => BiometricService());

/// Opens a link in whatever app handles it — the browser, never in-app.
///
/// A provider over the launcher rather than a direct call, so a test can watch
/// which URL the app would open and what happens when nothing can open it —
/// without a browser, and without the platform channel.
final Provider<Future<bool> Function(Uri)> urlOpenerProvider =
    Provider<Future<bool> Function(Uri)>(
  (Ref ref) => (Uri url) => launchUrl(url, mode: LaunchMode.externalApplication),
);

// ---------------------------------------------------------------------------
// Repositories
// ---------------------------------------------------------------------------

final Provider<PersonRepository> personRepositoryProvider =
    Provider<PersonRepository>(
  (Ref ref) => PersonRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<DebtRepository> debtRepositoryProvider =
    Provider<DebtRepository>(
  (Ref ref) => DebtRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<PaymentRepository> paymentRepositoryProvider =
    Provider<PaymentRepository>(
  (Ref ref) => PaymentRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<ObligationRepository> obligationRepositoryProvider =
    Provider<ObligationRepository>(
  (Ref ref) => ObligationRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<ReminderRepository> reminderRepositoryProvider =
    Provider<ReminderRepository>(
  (Ref ref) => ReminderRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<ActivityRepository> activityRepositoryProvider =
    Provider<ActivityRepository>(
  (Ref ref) => ActivityRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<SettingsRepository> settingsRepositoryProvider =
    Provider<SettingsRepository>(
  (Ref ref) => SettingsRepositoryImpl(ref.watch(databaseProvider)),
);

final Provider<LedgerQueries> ledgerQueriesProvider = Provider<LedgerQueries>(
  (Ref ref) => LedgerQueries(
    database: ref.watch(databaseProvider),
    people: ref.watch(personRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    obligations: ref.watch(obligationRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activity: ref.watch(activityRepositoryProvider),
  ),
);

// ---------------------------------------------------------------------------
// Settings
// ---------------------------------------------------------------------------

/// Live settings. Screens read this rather than holding their own copy, which is
/// what makes a language or theme change apply everywhere at once.
final StreamProvider<AppSettings> settingsProvider =
    StreamProvider<AppSettings>((Ref ref) {
  return ref.watch(settingsRepositoryProvider).watch();
});

/// The settings as they stood before the first frame.
///
/// The stream above cannot answer synchronously: its first value arrives a query
/// later, after the first frame has already been drawn. Until then the app used
/// to draw [AppSettings.initial] — so someone who had chosen English, or the dark
/// theme, watched the app open in Arabic, or in light, and then change under
/// them. `main` reads the row once before `runApp` and seeds it here through
/// [loadBootSettings], so the first frame is already the app the user left.
class BootSettings extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.initial;

  void seed(AppSettings settings) => state = settings;
}

final NotifierProvider<BootSettings, AppSettings> bootSettingsProvider =
    NotifierProvider<BootSettings, AppSettings>(BootSettings.new);

/// Reads the stored settings and makes them the app's starting point.
///
/// Throws what the read throws: this is the first touch of the database, and
/// the start-up path turns a failure here into a screen that names it.
Future<AppSettings> loadBootSettings(ProviderContainer container) async {
  final AppSettings settings =
      await container.read(settingsRepositoryProvider).get();
  container.read(bootSettingsProvider.notifier).seed(settings);
  return settings;
}

/// Settings with the stored values folded in, for widgets that must render
/// before the first snapshot arrives.
final Provider<AppSettings> effectiveSettingsProvider =
    Provider<AppSettings>((Ref ref) {
  return ref.watch(settingsProvider).value ?? ref.watch(bootSettingsProvider);
});

/// The phone's languages, most preferred first.
///
/// Read from the binding's dispatcher rather than `PlatformDispatcher.instance`:
/// it is the same list on a phone, and the one a test can speak for. The app
/// root refreshes it when the platform reports a change and whenever the app
/// comes back to the foreground, so a phone switched to another language while
/// Dhimmah sat in the background is noticed on return.
class DeviceLocales extends Notifier<List<Locale>> {
  @override
  List<Locale> build() => _read();

  /// Re-reads the phone. Only notifies when the list actually changed.
  void refresh() {
    final List<Locale> next = _read();
    if (!listEquals(next, state)) state = next;
  }

  static List<Locale> _read() =>
      List<Locale>.unmodifiable(WidgetsBinding.instance.platformDispatcher.locales);
}

final NotifierProvider<DeviceLocales, List<Locale>> deviceLocalesProvider =
    NotifierProvider<DeviceLocales, List<Locale>>(DeviceLocales.new);

/// The language the phone asks for, among the two Dhimmah ships.
final Provider<AppLanguage> deviceLanguageProvider =
    Provider<AppLanguage>((Ref ref) {
  return AppLanguage.fromDevice(<String>[
    for (final Locale locale in ref.watch(deviceLocalesProvider))
      locale.languageCode,
  ]);
});

/// The language the app is in: the user's choice, or the phone's when the user
/// left it to the phone.
///
/// The one place a language is decided. The interface, the notifications, the
/// dates, the numbers and the statement all read this, so they cannot disagree
/// with each other — which they would if any of them resolved it separately.
final Provider<AppLanguage> appLanguageProvider = Provider<AppLanguage>((Ref ref) {
  final LanguagePreference preference = ref.watch(
    effectiveSettingsProvider
        .select((AppSettings settings) => settings.languagePreference),
  );
  return preference.resolve(ref.watch(deviceLanguageProvider));
});

class SettingsController {
  SettingsController(this._ref);

  final Ref _ref;

  SettingsRepository get _repository => _ref.read(settingsRepositoryProvider);

  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    final AppSettings next = await _repository.update(transform);
    // A change to languages, times or windows invalidates the scheduled set.
    await _ref.read(ledgerServiceProvider).refreshNotifications();
    // ignore: unused_local_variable
    next;
  }

  /// The automatic-snapshot switch. Deliberately does *not* rebuild the
  /// notification schedule: this is a preference about files, not a change to
  /// the ledger.
  Future<void> setBackupAutoEnabled(bool enabled) async {
    await _repository.update((AppSettings s) => s.copyWith(backupAutoEnabled: enabled));
  }

  Future<void> setLanguagePreference(LanguagePreference preference) =>
      update((AppSettings s) => s.copyWith(languagePreference: preference));

  Future<void> setThemeMode(AppThemeMode mode) =>
      update((AppSettings s) => s.copyWith(themeMode: mode));

  Future<void> setNumerals(NumeralsStyle style) =>
      update((AppSettings s) => s.copyWith(numerals: style));

  Future<void> setDefaultCurrency(AppCurrency currency) =>
      update((AppSettings s) => s.copyWith(defaultCurrency: currency));

  Future<void> setNotificationsEnabled(bool enabled) =>
      update((AppSettings s) => s.copyWith(notificationsEnabled: enabled));

  Future<void> setNotificationTime(int hour, int minute) => update(
        (AppSettings s) =>
            s.copyWith(notificationHour: hour, notificationMinute: minute),
      );

  Future<void> setDefaultReminderLeads(List<ReminderLead> leads) => update(
        (AppSettings s) =>
            s.copyWith(defaultReminderLeads: ReminderLead.sorted(leads)),
      );

  Future<void> setDueSoonWindow(int days) =>
      update((AppSettings s) => s.copyWith(dueSoonWindowDays: days));

  Future<void> setMonthEndEnabled(bool enabled) =>
      update((AppSettings s) => s.copyWith(monthEndSummaryEnabled: enabled));

  Future<void> setMonthEndDay(MonthEndDay day) =>
      update((AppSettings s) => s.copyWith(monthEndDay: day));

  Future<void> setMonthEndTime(int hour, int minute) => update(
        (AppSettings s) => s.copyWith(monthEndHour: hour, monthEndMinute: minute),
      );

  Future<void> setLockEnabled(bool enabled) =>
      update((AppSettings s) => s.copyWith(lockEnabled: enabled));

  Future<void> setBiometricEnabled(bool enabled) =>
      update((AppSettings s) => s.copyWith(biometricEnabled: enabled));

  /// Ends onboarding. The language is not part of it: it follows the phone, and
  /// the switch on the onboarding screen stores a choice the moment it is made.
  Future<void> completeOnboarding({
    required AppCurrency currency,
    required bool notificationsEnabled,
  }) =>
      update(
        (AppSettings s) => s.copyWith(
          defaultCurrency: currency,
          notificationsEnabled: notificationsEnabled,
          onboardingCompleted: true,
        ),
      );
}

final Provider<SettingsController> settingsControllerProvider =
    Provider<SettingsController>(SettingsController.new);

// ---------------------------------------------------------------------------
// Localisation-aware helpers
// ---------------------------------------------------------------------------

/// The active [AppLocalizations], in the resolved [appLanguageProvider].
///
/// Services run outside the widget tree, so they cannot ask a `BuildContext` for
/// their strings; this gives them the same instance the UI is using.
final Provider<AppLocalizations> localizationsProvider =
    Provider<AppLocalizations>((Ref ref) {
  return lookupAppLocalizations(ref.watch(appLanguageProvider).locale);
});

/// Formatting for the resolved language and the user's numerals and currency.
///
/// Watches only what formatting reads. It used to watch the whole settings row,
/// so switching automatic backups off rebuilt every formatter — and the
/// notification wording built from them.
final Provider<AppFormatting> formattingProvider = Provider<AppFormatting>(
  (Ref ref) {
    final ({NumeralsStyle numerals, AppCurrency currency}) style = ref.watch(
      effectiveSettingsProvider.select(
        (AppSettings s) => (numerals: s.numerals, currency: s.defaultCurrency),
      ),
    );
    return AppFormatting.of(
      language: ref.watch(appLanguageProvider),
      numerals: style.numerals,
      defaultCurrency: style.currency,
      localizations: ref.watch(localizationsProvider),
    );
  },
);

/// Notification wording, rebuilt exactly when what it says could change: the
/// language, the numerals or the default currency.
///
/// The app root listens to this and re-words the reminders already scheduled,
/// which is the only way a phone that changes language while the app is open
/// gets reminders in the new one.
final Provider<NotificationComposer> notificationComposerProvider =
    Provider<NotificationComposer>(
  (Ref ref) => NotificationComposer(
    localizations: ref.watch(localizationsProvider),
    formatting: ref.watch(formattingProvider),
  ),
);

// ---------------------------------------------------------------------------
// Application service
// ---------------------------------------------------------------------------

final Provider<LedgerService> ledgerServiceProvider = Provider<LedgerService>(
  (Ref ref) => LedgerService(
    database: ref.watch(databaseProvider),
    people: ref.watch(personRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    obligations: ref.watch(obligationRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activity: ref.watch(activityRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    notifications: ref.watch(notificationServiceProvider),
    localizations: () => ref.read(localizationsProvider),
    composer: () => ref.read(notificationComposerProvider),
    clock: () => ref.read(clockProvider)(),
  ),
);

/// Builds and renders a person's debt statement.
final Provider<StatementService> statementServiceProvider =
    Provider<StatementService>(
  (Ref ref) => StatementService(
    localizations: ref.watch(localizationsProvider),
    formatting: ref.watch(formattingProvider),
  ),
);

/// Exports the ledger to a file the user can keep.
final Provider<DataExportService> dataExportServiceProvider =
    Provider<DataExportService>(
  (Ref ref) => DataExportService(
    people: ref.watch(personRepositoryProvider),
    debts: ref.watch(debtRepositoryProvider),
    payments: ref.watch(paymentRepositoryProvider),
    obligations: ref.watch(obligationRepositoryProvider),
    reminders: ref.watch(reminderRepositoryProvider),
    activity: ref.watch(activityRepositoryProvider),
    localizations: ref.watch(localizationsProvider),
    formatting: ref.watch(formattingProvider),
  ),
);

// ---------------------------------------------------------------------------
// Read models
// ---------------------------------------------------------------------------

final StreamProvider<DashboardSnapshot> dashboardProvider =
    StreamProvider<DashboardSnapshot>((Ref ref) {
  final AppSettings settings = ref.watch(effectiveSettingsProvider);
  return ref.watch(ledgerQueriesProvider).watchDashboard(
        dueSoonWindowDays: settings.dueSoonWindowDays,
        defaultCurrency: settings.defaultCurrency,
        asOf: ref.watch(todayProvider),
      );
});

final StreamProvider<List<DebtView>> debtViewsProvider =
    StreamProvider<List<DebtView>>((Ref ref) {
  final AppSettings settings = ref.watch(effectiveSettingsProvider);
  return ref.watch(ledgerQueriesProvider).watchDebtViews(
        dueSoonWindowDays: settings.dueSoonWindowDays,
        asOf: ref.watch(todayProvider),
      );
});

final StreamProvider<List<PersonDirectoryEntry>> peopleDirectoryProvider =
    StreamProvider<List<PersonDirectoryEntry>>((Ref ref) {
  final AppSettings settings = ref.watch(effectiveSettingsProvider);
  return ref.watch(ledgerQueriesProvider).watchPersonDirectory(
        dueSoonWindowDays: settings.dueSoonWindowDays,
        asOf: ref.watch(todayProvider),
      );
});

final StreamProvider<List<ObligationInstance>> obligationInstancesProvider =
    StreamProvider<List<ObligationInstance>>((Ref ref) {
  return ref.watch(ledgerQueriesProvider).watchObligationInstances(
        asOf: ref.watch(todayProvider),
      );
});

final StreamProvider<List<Reminder>> remindersProvider =
    StreamProvider<List<Reminder>>((Ref ref) {
  return ref
      .watch(ledgerQueriesProvider)
      .watchReminders(asOf: ref.watch(todayProvider));
});

/// One reminder, for the edit form.
final reminderByIdProvider =
    StreamProvider.family<Reminder?, String>((Ref ref, String id) {
  return ref.watch(reminderRepositoryProvider).watchById(id);
});

/// One obligation, for the edit form.
final obligationByIdProvider =
    StreamProvider.family<Obligation?, String>((Ref ref, String id) {
  return ref.watch(obligationRepositoryProvider).watchById(id);
});

/// One person, for the edit form.
final personByIdProvider = StreamProvider.family<Person?, String>((Ref ref, String id) {
  return ref.watch(personRepositoryProvider).watchById(id);
});

/// One debt, for the edit form.
final debtByIdProvider = StreamProvider.family<Debt?, String>((Ref ref, String id) {
  return ref.watch(debtRepositoryProvider).watchById(id);
});

final personLedgerProvider = StreamProvider.family<PersonLedger?, String>((Ref ref, String personId) {
  final AppSettings settings = ref.watch(effectiveSettingsProvider);
  return ref.watch(ledgerQueriesProvider).watchPersonLedger(
        personId,
        dueSoonWindowDays: settings.dueSoonWindowDays,
        asOf: ref.watch(todayProvider),
      );
});

final debtDetailProvider = StreamProvider.family<DebtDetail?, String>((Ref ref, String debtId) {
  final AppSettings settings = ref.watch(effectiveSettingsProvider);
  return ref.watch(ledgerQueriesProvider).watchDebtDetail(
        debtId,
        dueSoonWindowDays: settings.dueSoonWindowDays,
        asOf: ref.watch(todayProvider),
      );
});

/// Arguments for the monthly report, so the family key is a value type.
typedef ReportArgs = ({int year, int month, AppCurrency currency});

final monthlyReportProvider = StreamProvider.family<MonthlyReport, ReportArgs>((Ref ref, ReportArgs args) {
  return ref.watch(ledgerQueriesProvider).watchMonthlyReport(
        year: args.year,
        month: args.month,
        currency: args.currency,
        trendMonths: 6,
        asOf: ref.watch(todayProvider),
      );
});

/// The currencies actually in use, derived from the records rather than from a
/// setting, so the report picker only offers currencies that have data.
final Provider<List<AppCurrency>> currenciesInUseProvider =
    Provider<List<AppCurrency>>((Ref ref) {
  final AsyncValue<List<DebtView>> views = ref.watch(debtViewsProvider);
  final Set<AppCurrency> used = <AppCurrency>{};
  for (final DebtView view in views.value ?? const <DebtView>[]) {
    used.add(view.currency);
  }
  for (final ObligationInstance instance
      in ref.watch(obligationInstancesProvider).value ??
          const <ObligationInstance>[]) {
    used.add(instance.obligation.currency);
  }
  final List<AppCurrency> sorted = used.toList()
    ..sort((AppCurrency a, AppCurrency b) => a.code.compareTo(b.code));
  final AppCurrency fallback = ref.watch(effectiveSettingsProvider).defaultCurrency;
  if (sorted.isEmpty) return <AppCurrency>[fallback];
  return sorted;
});
