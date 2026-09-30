import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../enums/preference_enums.dart';
import '../enums/recurrence.dart';

/// User preferences. Stored as a single row so reads are one lookup and writes
/// are atomic.
@immutable
class AppSettings {
  const AppSettings({
    required this.languagePreference,
    required this.themeMode,
    required this.numerals,
    required this.defaultCurrency,
    required this.notificationsEnabled,
    required this.notificationHour,
    required this.notificationMinute,
    required this.defaultReminderLeads,
    required this.monthEndSummaryEnabled,
    required this.monthEndDay,
    required this.monthEndHour,
    required this.monthEndMinute,
    required this.dueSoonWindowDays,
    required this.lockEnabled,
    required this.biometricEnabled,
    required this.onboardingCompleted,
    this.backupAutoEnabled = true,
    this.lastExportedAt,
    this.lastSummarySentOn,
  });

  /// The state a brand-new install starts from.
  ///
  /// The phone's language and the phone's theme, and reminders on: the app should
  /// be useful the moment it opens, in the language the phone is already in, with
  /// every one of these changeable in Settings.
  static const AppSettings initial = AppSettings(
    languagePreference: LanguagePreference.system,
    themeMode: AppThemeMode.system,
    numerals: NumeralsStyle.latin,
    defaultCurrency: AppCurrency.inr,
    notificationsEnabled: true,
    notificationHour: 20,
    notificationMinute: 0,
    defaultReminderLeads: <ReminderLead>[ReminderLead.oneDayBefore],
    monthEndSummaryEnabled: true,
    monthEndDay: MonthEndDay.lastDay,
    monthEndHour: 20,
    monthEndMinute: 0,
    dueSoonWindowDays: 7,
    lockEnabled: false,
    biometricEnabled: false,
    onboardingCompleted: false,
  );

  /// Follow the phone, or one language regardless of it.
  ///
  /// Deliberately not the language itself: which language that is depends on
  /// the phone, and is worked out where the phone can be asked — see
  /// `appLanguageProvider`. Nothing may read this as if it were the answer.
  final LanguagePreference languagePreference;
  final AppThemeMode themeMode;
  final NumeralsStyle numerals;

  /// Pre-selected currency on new records.
  final AppCurrency defaultCurrency;

  // --- Reminders -----------------------------------------------------------
  final bool notificationsEnabled;

  /// Local time of day at which reminders are delivered.
  final int notificationHour;
  final int notificationMinute;

  /// Lead times pre-selected on new records. The user can change them per
  /// record.
  final List<ReminderLead> defaultReminderLeads;

  /// How many days ahead counts as "due soon" on the dashboard.
  final int dueSoonWindowDays;

  // --- Month-end summary ---------------------------------------------------
  final bool monthEndSummaryEnabled;
  final MonthEndDay monthEndDay;
  final int monthEndHour;
  final int monthEndMinute;

  /// `yyyy-MM-dd` of the last summary that was actually delivered, so the app
  /// never sends the same month twice after a restart.
  final DateTime? lastSummarySentOn;

  // --- Security ------------------------------------------------------------
  final bool lockEnabled;

  /// Whether a PIN has been set. The hash itself never leaves secure storage.
  final bool biometricEnabled;

  // --- Lifecycle -----------------------------------------------------------
  final bool onboardingCompleted;

  /// Whether the app takes its own snapshots as the ledger changes.
  final bool backupAutoEnabled;
  final DateTime? lastExportedAt;

  bool get hasPasscodeConfigured => lockEnabled;

  /// True when a reminder should be scheduled at all.
  bool get schedulingEnabled => notificationsEnabled;

  AppSettings copyWith({
    LanguagePreference? languagePreference,
    AppThemeMode? themeMode,
    NumeralsStyle? numerals,
    AppCurrency? defaultCurrency,
    bool? notificationsEnabled,
    int? notificationHour,
    int? notificationMinute,
    List<ReminderLead>? defaultReminderLeads,
    bool? monthEndSummaryEnabled,
    MonthEndDay? monthEndDay,
    int? monthEndHour,
    int? monthEndMinute,
    int? dueSoonWindowDays,
    bool? lockEnabled,
    bool? biometricEnabled,
    bool? onboardingCompleted,
    bool? backupAutoEnabled,
    Object? lastSummarySentOn = _unset,
    Object? lastExportedAt = _unset,
  }) {
    return AppSettings(
      languagePreference: languagePreference ?? this.languagePreference,
      themeMode: themeMode ?? this.themeMode,
      numerals: numerals ?? this.numerals,
      defaultCurrency: defaultCurrency ?? this.defaultCurrency,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      notificationHour: notificationHour ?? this.notificationHour,
      notificationMinute: notificationMinute ?? this.notificationMinute,
      defaultReminderLeads: defaultReminderLeads ?? this.defaultReminderLeads,
      monthEndSummaryEnabled:
          monthEndSummaryEnabled ?? this.monthEndSummaryEnabled,
      monthEndDay: monthEndDay ?? this.monthEndDay,
      monthEndHour: monthEndHour ?? this.monthEndHour,
      monthEndMinute: monthEndMinute ?? this.monthEndMinute,
      dueSoonWindowDays: dueSoonWindowDays ?? this.dueSoonWindowDays,
      lockEnabled: lockEnabled ?? this.lockEnabled,
      biometricEnabled: biometricEnabled ?? this.biometricEnabled,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      backupAutoEnabled: backupAutoEnabled ?? this.backupAutoEnabled,
      lastSummarySentOn: identical(lastSummarySentOn, _unset)
          ? this.lastSummarySentOn
          : lastSummarySentOn as DateTime?,
      lastExportedAt: identical(lastExportedAt, _unset)
          ? this.lastExportedAt
          : lastExportedAt as DateTime?,
    );
  }

  /// Every field, and that is not a formality.
  ///
  /// This used to leave out `backupAutoEnabled` and `defaultReminderLeads`, and
  /// the omission was not a cosmetic one: a value object that says two different
  /// settings are equal makes every consumer that compares with `==` skip its
  /// work. Turning automatic saving off wrote the database, the row streamed
  /// back, and the screen kept showing "on" — because the new settings compared
  /// equal to the old ones and nothing downstream was told anything had changed.
  /// A restart was the only way to see the truth.
  ///
  /// The rule this now follows: a field that is not in `==` is a field the app
  /// cannot react to. `test/domain/app_settings_equality_test.dart` walks every
  /// field so the next one added cannot be forgotten.
  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.languagePreference == languagePreference &&
      other.themeMode == themeMode &&
      other.numerals == numerals &&
      other.defaultCurrency == defaultCurrency &&
      other.notificationsEnabled == notificationsEnabled &&
      other.notificationHour == notificationHour &&
      other.notificationMinute == notificationMinute &&
      _sameLeads(other.defaultReminderLeads, defaultReminderLeads) &&
      other.monthEndSummaryEnabled == monthEndSummaryEnabled &&
      other.monthEndDay == monthEndDay &&
      other.monthEndHour == monthEndHour &&
      other.monthEndMinute == monthEndMinute &&
      other.dueSoonWindowDays == dueSoonWindowDays &&
      other.lockEnabled == lockEnabled &&
      other.biometricEnabled == biometricEnabled &&
      other.onboardingCompleted == onboardingCompleted &&
      other.backupAutoEnabled == backupAutoEnabled &&
      other.lastSummarySentOn == lastSummarySentOn &&
      other.lastExportedAt == lastExportedAt;

  @override
  int get hashCode => Object.hash(
        languagePreference,
        themeMode,
        numerals,
        defaultCurrency,
        notificationsEnabled,
        notificationHour,
        notificationMinute,
        Object.hashAll(defaultReminderLeads),
        monthEndSummaryEnabled,
        monthEndDay,
        monthEndHour,
        monthEndMinute,
        dueSoonWindowDays,
        lockEnabled,
        biometricEnabled,
        onboardingCompleted,
        backupAutoEnabled,
        lastSummarySentOn,
        lastExportedAt,
      );

  /// Element-wise, because the list is read back from the database each time and
  /// two reads are never the same object. Comparing identity would make every
  /// emission look like a change; comparing nothing at all — which is what the
  /// old `==` effectively did — makes a real change invisible.
  static bool _sameLeads(List<ReminderLead> a, List<ReminderLead> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

const Object _unset = Object();
