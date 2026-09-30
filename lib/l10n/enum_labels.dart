import 'package:flutter/material.dart';

import '../core/money/currency.dart';
import '../domain/enums/activity_enums.dart';
import '../domain/enums/debt_enums.dart';
import '../domain/enums/obligation_enums.dart';
import '../domain/enums/preference_enums.dart';
import '../domain/enums/recurrence.dart';
import 'generated/app_localizations.dart';

/// Localised names for every enum the user can see.
///
/// The enums themselves carry no display text, which is what keeps Arabic and
/// English honest: a label can only come from the ARB files.
extension DebtLifecycleStatusL10n on DebtLifecycleStatus {
  String label(AppLocalizations l) => switch (this) {
        DebtLifecycleStatus.active => l.statusActive,
        DebtLifecycleStatus.upcoming => l.statusUpcoming,
        DebtLifecycleStatus.dueSoon => l.statusDueSoon,
        DebtLifecycleStatus.dueToday => l.statusDueToday,
        DebtLifecycleStatus.overdue => l.statusOverdue,
        DebtLifecycleStatus.paid => l.statusPaid,
        DebtLifecycleStatus.archived => l.statusArchived,
      };
}

extension DebtFilterL10n on DebtFilter {
  String label(AppLocalizations l) => switch (this) {
        DebtFilter.all => l.filterAll,
        DebtFilter.active => l.filterActive,
        DebtFilter.partiallyPaid => l.filterPartiallyPaid,
        DebtFilter.unpaid => l.filterUnpaid,
        DebtFilter.paid => l.statusPaid,
        DebtFilter.overdue => l.statusOverdue,
        DebtFilter.dueSoon => l.filterDueSoon,
        DebtFilter.archived => l.filterArchived,
      };
}

extension DebtSortOrderL10n on DebtSortOrder {
  String label(AppLocalizations l) => switch (this) {
        DebtSortOrder.dueDateSoonest => l.sortDueSoonest,
        DebtSortOrder.dueDateLatest => l.sortDueLatest,
        DebtSortOrder.amountHighest => l.sortAmountHighest,
        DebtSortOrder.amountLowest => l.sortAmountLowest,
        DebtSortOrder.recentlyAdded => l.sortRecentlyAdded,
        DebtSortOrder.oldestAdded => l.sortOldestAdded,
        DebtSortOrder.nameAscending => l.sortNameAscending,
      };
}

extension DebtDirectionL10n on DebtDirection {
  String label(AppLocalizations l) =>
      isIOwe ? l.navIOwe : l.navOwedToMe;

  String fullLabel(AppLocalizations l) =>
      isIOwe ? l.addDebtIOwe : l.addDebtOwedToMe;
}

extension ObligationStatusL10n on ObligationStatus {
  String label(AppLocalizations l) => switch (this) {
        ObligationStatus.upcoming => l.statusUpcoming,
        ObligationStatus.dueToday => l.statusDueToday,
        ObligationStatus.overdue => l.statusOverdue,
        ObligationStatus.paid => l.statusPaid,
        ObligationStatus.skipped => l.statusSkipped,
        ObligationStatus.cancelled => l.statusCancelled,
      };
}

extension ObligationCategoryL10n on ObligationCategory {
  String label(AppLocalizations l) => switch (this) {
        ObligationCategory.housing => l.categoryHousing,
        ObligationCategory.utilities => l.categoryUtilities,
        ObligationCategory.telecom => l.categoryTelecom,
        ObligationCategory.subscription => l.categorySubscription,
        ObligationCategory.loan => l.categoryLoan,
        ObligationCategory.installment => l.categoryInstallment,
        ObligationCategory.salary => l.categorySalary,
        ObligationCategory.insurance => l.categoryInsurance,
        ObligationCategory.tax => l.categoryTax,
        ObligationCategory.other => l.categoryOther,
      };

  /// A single-line glyph for the category chip. Deliberately from one icon
  /// family so nothing looks borrowed from another app.
  IconData get icon => switch (this) {
        ObligationCategory.housing => Icons.home_outlined,
        ObligationCategory.utilities => Icons.bolt_outlined,
        ObligationCategory.telecom => Icons.wifi_outlined,
        ObligationCategory.subscription => Icons.autorenew_outlined,
        ObligationCategory.loan => Icons.account_balance_outlined,
        ObligationCategory.installment => Icons.calendar_month_outlined,
        ObligationCategory.salary => Icons.badge_outlined,
        ObligationCategory.insurance => Icons.shield_outlined,
        ObligationCategory.tax => Icons.receipt_long_outlined,
        ObligationCategory.other => Icons.more_horiz_outlined,
      };
}

extension RecurrenceFrequencyL10n on RecurrenceFrequency {
  String label(AppLocalizations l, {int interval = 1}) {
    if (interval <= 1) {
      return switch (this) {
        RecurrenceFrequency.none => l.recurrenceNone,
        RecurrenceFrequency.weekly => l.recurrenceWeekly,
        RecurrenceFrequency.monthly => l.recurrenceMonthly,
        RecurrenceFrequency.quarterly => l.recurrenceQuarterly,
        RecurrenceFrequency.yearly => l.recurrenceYearly,
        RecurrenceFrequency.custom => l.recurrenceCustom,
      };
    }
    return switch (this) {
      RecurrenceFrequency.none => l.recurrenceNone,
      RecurrenceFrequency.weekly =>
        l.recurrenceEveryN(interval, l.unitWeek),
      RecurrenceFrequency.monthly =>
        l.recurrenceEveryN(interval, l.unitMonth),
      RecurrenceFrequency.quarterly =>
        l.recurrenceEveryN(interval * 3, l.unitMonth),
      RecurrenceFrequency.yearly =>
        l.recurrenceEveryN(interval, l.unitYear),
      RecurrenceFrequency.custom =>
        l.recurrenceEveryN(interval, l.unitMonth),
    };
  }
}

extension ReminderLeadL10n on ReminderLead {
  String label(AppLocalizations l) => switch (this) {
        ReminderLead.none => l.leadNone,
        ReminderLead.onDueDate => l.leadOnDueDate,
        ReminderLead.oneDayBefore => l.leadOneDayBefore,
        ReminderLead.twoDaysBefore => l.leadTwoDaysBefore,
        ReminderLead.threeDaysBefore => l.leadThreeDaysBefore,
        ReminderLead.oneWeekBefore => l.leadOneWeekBefore,
        ReminderLead.twoWeeksBefore => l.leadTwoWeeksBefore,
      };
}

extension ReminderStatusL10n on ReminderStatus {
  String label(AppLocalizations l) => switch (this) {
        ReminderStatus.upcoming => l.statusUpcoming,
        ReminderStatus.today => l.statusDueToday,
        ReminderStatus.overdue => l.statusOverdue,
        ReminderStatus.completed => l.statusCompleted,
        ReminderStatus.dismissed => l.statusDismissed,
      };
}

extension ReminderBucketL10n on ReminderBucket {
  String label(AppLocalizations l) => switch (this) {
        ReminderBucket.today => l.remindersToday,
        ReminderBucket.tomorrow => l.remindersTomorrow,
        ReminderBucket.thisWeek => l.remindersThisWeek,
        ReminderBucket.later => l.remindersLater,
        ReminderBucket.overdue => l.remindersOverdue,
        ReminderBucket.completed => l.remindersCompleted,
      };
}

extension ActivityTypeL10n on ActivityType {
  String label(AppLocalizations l) => switch (this) {
        ActivityType.debtCreated => l.activityDebtCreated,
        ActivityType.debtUpdated => l.activityDebtUpdated,
        ActivityType.debtClosed => l.activityDebtClosed,
        ActivityType.debtReopened => l.activityDebtReopened,
        ActivityType.debtArchived => l.activityDebtArchived,
        ActivityType.debtDeleted => l.activityDebtDeleted,
        ActivityType.paymentRecorded => l.activityPaymentRecorded,
        ActivityType.paymentDeleted => l.activityPaymentDeleted,
        ActivityType.personCreated => l.activityPersonCreated,
        ActivityType.personUpdated => l.activityPersonUpdated,
        ActivityType.personDeleted => l.activityPersonDeleted,
        ActivityType.obligationCreated => l.activityObligationCreated,
        ActivityType.obligationPaid => l.activityObligationPaid,
        ActivityType.obligationSkipped => l.activityObligationSkipped,
        ActivityType.reminderCreated => l.activityReminderCreated,
        ActivityType.reminderCompleted => l.activityReminderCompleted,
        ActivityType.dataImported => l.activityImported,
        ActivityType.dataExported => l.activityExported,
        ActivityType.dataCleared => l.activityCleared,
        ActivityType.monthSummaryGenerated => l.activityMonthSummary,
      };

  /// One icon per event, from the same family as everything else.
  IconData get icon => switch (this) {
        ActivityType.debtCreated => Icons.add_circle_outline,
        ActivityType.debtUpdated => Icons.edit_outlined,
        ActivityType.debtClosed => Icons.check_circle_outline,
        ActivityType.debtReopened => Icons.refresh,
        ActivityType.debtArchived => Icons.inventory_2_outlined,
        ActivityType.debtDeleted => Icons.delete_outline,
        ActivityType.paymentRecorded => Icons.payments_outlined,
        ActivityType.paymentDeleted => Icons.money_off_outlined,
        ActivityType.personCreated => Icons.person_add_alt,
        ActivityType.personUpdated => Icons.person_outline,
        ActivityType.personDeleted => Icons.person_remove_outlined,
        ActivityType.obligationCreated => Icons.event_repeat_outlined,
        ActivityType.obligationPaid => Icons.task_alt,
        ActivityType.obligationSkipped => Icons.skip_next_outlined,
        ActivityType.reminderCreated => Icons.notifications_none,
        ActivityType.reminderCompleted => Icons.done_all,
        ActivityType.dataImported => Icons.file_download_outlined,
        ActivityType.dataExported => Icons.file_upload_outlined,
        ActivityType.dataCleared => Icons.delete_forever_outlined,
        ActivityType.monthSummaryGenerated => Icons.insights_outlined,
      };
}

extension AppLanguageL10n on AppLanguage {
  /// The language's name in the interface's language — «الإنجليزية», "Arabic".
  String label(AppLocalizations l) =>
      isArabic ? l.languageArabic : l.languageEnglish;

  /// The locale the interface, the dates and the statement are written in.
  Locale get locale => Locale(code);

  /// The language's own name for itself — «العربية», "English".
  ///
  /// What a language picker shows, because it is read by someone who may not
  /// understand the language the interface is currently in, and the name in its
  /// own script is the one they recognise. It is taken from that language's own
  /// strings rather than written down again, so it has no key of its own to
  /// drift out of step.
  String get endonym => label(lookupAppLocalizations(locale));
}

extension LanguagePreferenceL10n on LanguagePreference {
  /// The option as a picker lists it: the language by its own name, or the
  /// phone.
  String label(AppLocalizations l) => language?.endonym ?? l.languageDevice;
}

extension AppCurrencyL10n on AppCurrency {
  /// The currency's name, which is what tells ﷼ the Saudi riyal apart from ﷼
  /// the Yemeni one to a person rather than to a parser.
  String label(AppLocalizations l) => switch (this) {
        AppCurrency.inr => l.currencyNameInr,
        AppCurrency.usd => l.currencyNameUsd,
        AppCurrency.sar => l.currencyNameSar,
        AppCurrency.aed => l.currencyNameAed,
        AppCurrency.yer => l.currencyNameYer,
        AppCurrency.eur => l.currencyNameEur,
        AppCurrency.gbp => l.currencyNameGbp,
      };
}

extension AppThemeModeL10n on AppThemeMode {
  String label(AppLocalizations l) => switch (this) {
        AppThemeMode.system => l.themeSystem,
        AppThemeMode.light => l.themeLight,
        AppThemeMode.dark => l.themeDark,
      };

  IconData get icon => switch (this) {
        AppThemeMode.system => Icons.brightness_auto_outlined,
        AppThemeMode.light => Icons.light_mode_outlined,
        AppThemeMode.dark => Icons.dark_mode_outlined,
      };
}

extension NumeralsStyleL10n on NumeralsStyle {
  String label(AppLocalizations l) =>
      this == NumeralsStyle.latin ? l.numeralsLatin : l.numeralsArabicIndic;
}

extension MonthEndDayL10n on MonthEndDay {
  String label(AppLocalizations l) =>
      isLastDay ? l.monthEndLastDay : l.monthEndDayNumber(dayOfMonth);
}

extension RelatedEntityTypeL10n on RelatedEntityType {
  String subject(AppLocalizations l) => switch (this) {
        RelatedEntityType.debt => l.navIOwe,
        RelatedEntityType.obligation => l.navObligations,
        RelatedEntityType.person => l.navPeople,
        RelatedEntityType.reminder => l.navReminders,
        RelatedEntityType.payment => l.paymentTitle,
        RelatedEntityType.none => '',
      };
}
