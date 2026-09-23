import 'package:meta/meta.dart';

import '../../core/money/currency.dart';
import '../enums/preference_enums.dart';
import '../enums/recurrence.dart';

/// User preferences. Stored as a single row so reads are one lookup and writes
/// are atomic.
@immutable
class AppSettings {
  const AppSettings({
    required this.language,
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
    this.lastExportedAt,
    this.lastSummarySentOn,
  });

  /// The state a brand-new install starts from.
  ///
  /// Arabic, light-following-system, and reminders on: the app should be useful
  /// the moment it opens, with every one of these changeable in Settings.
  static const AppSettings initial = AppSettings(
    language: AppLanguage.arabic,
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

  final AppLanguage language;
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
  final DateTime? lastExportedAt;

  bool get hasPasscodeConfigured => lockEnabled;

  /// True when a reminder should be scheduled at all.
  bool get schedulingEnabled => notificationsEnabled;

  AppSettings copyWith({
    AppLanguage? language,
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
    Object? lastSummarySentOn = _unset,
    Object? lastExportedAt = _unset,
  }) {
    return AppSettings(
      language: language ?? this.language,
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
      lastSummarySentOn: identical(lastSummarySentOn, _unset)
          ? this.lastSummarySentOn
          : lastSummarySentOn as DateTime?,
      lastExportedAt: identical(lastExportedAt, _unset)
          ? this.lastExportedAt
          : lastExportedAt as DateTime?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.language == language &&
      other.themeMode == themeMode &&
      other.numerals == numerals &&
      other.defaultCurrency == defaultCurrency &&
      other.notificationsEnabled == notificationsEnabled &&
      other.notificationHour == notificationHour &&
      other.notificationMinute == notificationMinute &&
      other.monthEndSummaryEnabled == monthEndSummaryEnabled &&
      other.monthEndDay == monthEndDay &&
      other.monthEndHour == monthEndHour &&
      other.monthEndMinute == monthEndMinute &&
      other.dueSoonWindowDays == dueSoonWindowDays &&
      other.lockEnabled == lockEnabled &&
      other.biometricEnabled == biometricEnabled &&
      other.onboardingCompleted == onboardingCompleted &&
      other.lastSummarySentOn == lastSummarySentOn &&
      other.lastExportedAt == lastExportedAt;

  @override
  int get hashCode => Object.hash(
        language,
        themeMode,
        numerals,
        defaultCurrency,
        notificationsEnabled,
        notificationHour,
        notificationMinute,
        monthEndSummaryEnabled,
        monthEndDay,
        monthEndHour,
        monthEndMinute,
        dueSoonWindowDays,
        lockEnabled,
        biometricEnabled,
        onboardingCompleted,
        lastSummarySentOn,
        lastExportedAt,
      );
}

const Object _unset = Object();
