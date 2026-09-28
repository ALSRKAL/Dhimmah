// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get actionArchive => 'Archive';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionClose => 'Close';

  @override
  String get actionConfirm => 'Confirm';

  @override
  String get actionCopy => 'Copy';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionDisable => 'Turn off';

  @override
  String get actionDone => 'Done';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionEnable => 'Enable';

  @override
  String get actionOk => 'OK';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionSave => 'Save';

  @override
  String get actionSelect => 'Select';

  @override
  String get actionShare => 'Share';

  @override
  String get actionUnarchive => 'Restore';

  @override
  String get actionUndo => 'Undo';

  @override
  String get activityCleared => 'All data deleted';

  @override
  String get activityDebtArchived => 'Debt archived';

  @override
  String get activityDebtClosed => 'Debt closed';

  @override
  String get activityDebtCreated => 'Debt created';

  @override
  String get activityDebtDeleted => 'Debt deleted';

  @override
  String get activityDebtReopened => 'Debt reopened';

  @override
  String get activityDebtUpdated => 'Debt updated';

  @override
  String get activityExported => 'Data exported';

  @override
  String get activityImported => 'Data imported';

  @override
  String get activityMonthSummary => 'Monthly summary generated';

  @override
  String get activityObligationCreated => 'Obligation created';

  @override
  String get activityObligationPaid => 'Obligation paid';

  @override
  String get activityObligationSkipped => 'Period skipped';

  @override
  String get activityPaymentDeleted => 'Payment deleted';

  @override
  String get activityPaymentRecorded => 'Payment recorded';

  @override
  String get activityPersonCreated => 'Person added';

  @override
  String get activityPersonDeleted => 'Person deleted';

  @override
  String get activityPersonUpdated => 'Person updated';

  @override
  String get activityReminderCompleted => 'Reminder completed';

  @override
  String get activityReminderCreated => 'Reminder created';

  @override
  String get addDebtAction => 'Add a debt';

  @override
  String get addDebtIOwe => 'Debt I owe';

  @override
  String get addDebtIOweHint => 'Money you have to pay';

  @override
  String get addDebtOwedToMe => 'Debt owed to me';

  @override
  String get addDebtOwedToMeHint => 'Money owed to you';

  @override
  String get addObligation => 'Obligation';

  @override
  String get addObligationHint => 'Rent, bill, subscription…';

  @override
  String get addPersonAction => 'Add a new person';

  @override
  String get addReminder => 'Reminder';

  @override
  String get addReminderHint => 'Something not to forget';

  @override
  String get addTitle => 'Add';

  @override
  String get allRecords => 'All records';

  @override
  String get appName => 'Dhimmah';

  @override
  String get appTagline => 'Know what you owe. Know what you\'re owed.';

  @override
  String get appTaglineShort =>
      'Your financial ledger, organised in one place.';

  @override
  String appVersion(String version, String build) {
    return 'Version $version ($build)';
  }

  @override
  String get attentionDueSoon => 'Due soon';

  @override
  String get attentionDueToday => 'Due today';

  @override
  String get attentionOverdue => 'Overdue';

  @override
  String get biometricNotEnrolled =>
      'No fingerprint or face is enrolled on this device yet.';

  @override
  String get biometricUnavailable =>
      'Biometrics are not available on this device.';

  @override
  String get brandPromise =>
      'Everything you owe and everything you\'re owed, remembered for you.';

  @override
  String get categoryHousing => 'Housing';

  @override
  String get categoryInstallment => 'Instalments';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categoryLoan => 'Loan';

  @override
  String get categoryOther => 'Other';

  @override
  String get categorySalary => 'Salaries';

  @override
  String get categorySubscription => 'Subscriptions';

  @override
  String get categoryTax => 'Tax';

  @override
  String get categoryTelecom => 'Telecom';

  @override
  String get categoryUtilities => 'Utilities';

  @override
  String get chooseOption => 'Choose';

  @override
  String get clearDataBody =>
      'Every person, debt, payment, obligation and reminder will be permanently removed. This cannot be undone.';

  @override
  String get clearDataTitle => 'Delete everything?';

  @override
  String get collapse => 'Collapse';

  @override
  String get copiedToClipboard => 'Copied';

  @override
  String currencySymbolWithCode(String code, String symbol) {
    return '$code $symbol';
  }

  @override
  String get dashboardAgainstYou => 'Against you';

  @override
  String get dashboardBalanced => 'Even';

  @override
  String get dashboardDueSoon => 'Due Soon';

  @override
  String dashboardDueSoonHint(int days) {
    return 'Within $days days';
  }

  @override
  String get dashboardEmptyAddDebt => 'Add your first debt';

  @override
  String get dashboardEmptyAddObligation => 'Add an obligation';

  @override
  String get dashboardEmptyBody =>
      'Add your first debt or commitment and Dhimmah will handle the reminders.';

  @override
  String get dashboardEmptyTitle => 'Nothing recorded yet.';

  @override
  String get dashboardGreeting => 'Hello';

  @override
  String get dashboardIOwe => 'I Owe';

  @override
  String get dashboardIOweHint => 'Total you have to pay';

  @override
  String get dashboardInYourFavour => 'In your favour';

  @override
  String get dashboardNetPosition => 'Net';

  @override
  String get dashboardObligations => 'Upcoming obligations';

  @override
  String get dashboardOtherCurrencies => 'Other currency balances';

  @override
  String get dashboardOverdue => 'Overdue';

  @override
  String get dashboardOverdueHint => 'Past the due date';

  @override
  String get dashboardOwedToMe => 'Owed to Me';

  @override
  String get dashboardOwedToMeHint => 'Total owed to you';

  @override
  String get dashboardRecentActivity => 'Recent activity';

  @override
  String get dashboardSubtitle => 'A quick look at your financial ledger';

  @override
  String get dashboardUpcoming => 'Upcoming';

  @override
  String get dashboardViewAll => 'View all';

  @override
  String dateDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String dateDueOn(String date) {
    return 'Due $date';
  }

  @override
  String dateInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'In $days days',
      one: 'In 1 day',
    );
    return '$_temp0';
  }

  @override
  String get dateNoDueDate => 'No due date';

  @override
  String dateOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String get dateToday => 'Today';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String get debtArchived => 'Archived';

  @override
  String get debtClosed => 'Debt closed';

  @override
  String get debtCreated => 'Debt created';

  @override
  String get debtFormEdit => 'Edit debt';

  @override
  String get debtFormNewIOwe => 'Debt I owe';

  @override
  String get debtFormNewOwedToMe => 'Debt owed to me';

  @override
  String get debtFormSubtitle => 'Record the details in seconds';

  @override
  String get debtRestored => 'Restored';

  @override
  String get debtSettled => 'Debt settled in full';

  @override
  String get debtUpdated => 'Debt updated';

  @override
  String get deleteConfirmBody => 'This cannot be undone.';

  @override
  String get deleteUndoableBody =>
      'The debt will be deleted. You can undo this for a few seconds.';

  @override
  String get recordGone => 'This record no longer exists.';

  @override
  String get deleteConfirmTitle => 'Delete this record?';

  @override
  String detailClosedOn(String date) {
    return 'Settled on $date';
  }

  @override
  String get detailDueOn => 'Due on';

  @override
  String get detailIssuedOn => 'Recorded on';

  @override
  String get detailNoPayments => 'No payments recorded yet.';

  @override
  String detailOverpaid(String amount) {
    return 'Payments exceed the original amount by $amount.';
  }

  @override
  String get detailPaid => 'Paid';

  @override
  String detailProgress(int percent) {
    return '$percent% paid';
  }

  @override
  String get detailRecordPayment => 'Record a payment';

  @override
  String get detailRemaining => 'Remaining';

  @override
  String get detailTimeline => 'Timeline';

  @override
  String get detailTotal => 'Total';

  @override
  String get expand => 'Expand';

  @override
  String get exportCsv => 'CSV — spreadsheet';

  @override
  String get exportCsvBody => 'Open it in Excel or Sheets';

  @override
  String get exportDone => 'Export ready';

  @override
  String get exportFailed => 'Export failed. Please try again.';

  @override
  String get exportJson => 'JSON — full backup';

  @override
  String get exportJsonBody => 'A file with all your records';

  @override
  String get exportPdf => 'PDF — report';

  @override
  String get exportPdfBody => 'A tidy report to share or print';

  @override
  String get fieldAdvancedHint => 'Description, reminder, date, notes';

  @override
  String get fieldAdvancedOptions => 'More options';

  @override
  String get fieldAdvancedSet => 'Set';

  @override
  String get fieldAmount => 'Amount';

  @override
  String get fieldCategory => 'Category';

  @override
  String get fieldCurrency => 'Currency';

  @override
  String get fieldDate => 'Date';

  @override
  String get fieldDayOfMonth => 'Day of the month';

  @override
  String get fieldDirection => 'Record type';

  @override
  String get fieldDueDate => 'Due date';

  @override
  String get fieldDueDateNone => 'No due date';

  @override
  String get fieldEndDate => 'Ends on';

  @override
  String get fieldFrequency => 'Frequency';

  @override
  String get fieldNote => 'Notes';

  @override
  String get fieldNoteHint => 'Any extra detail…';

  @override
  String get fieldObligationName => 'Name';

  @override
  String get fieldObligationNameHint => 'e.g. Home rent';

  @override
  String get fieldOptional => 'Optional';

  @override
  String get fieldPerson => 'Person';

  @override
  String get fieldPersonHint => 'Pick someone or add someone new';

  @override
  String get fieldPersonNone => 'No person';

  @override
  String get fieldRecurrence => 'Repeat';

  @override
  String get fieldReminder => 'Reminder';

  @override
  String get fieldStartDate => 'Starts on';

  @override
  String get fieldTitle => 'Description';

  @override
  String get fieldTitleHint => 'e.g. Loan, car finance';

  @override
  String get filterActive => 'Active';

  @override
  String get filterAll => 'All';

  @override
  String get filterApply => 'Apply';

  @override
  String get filterArchived => 'Archived';

  @override
  String get filterDebts => 'Debts';

  @override
  String get filterDueSoon => 'Due soon';

  @override
  String get filterObligations => 'Obligations';

  @override
  String get filterPartiallyPaid => 'Partially paid';

  @override
  String get filterPeriod => 'Period';

  @override
  String get filterReset => 'Reset';

  @override
  String get filterSort => 'Sort by';

  @override
  String get filterStatus => 'Status';

  @override
  String get filterTitle => 'Filters';

  @override
  String get filterType => 'Type';

  @override
  String get filterUnpaid => 'Unpaid';

  @override
  String filtersApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters',
      one: '1 filter',
      zero: 'No filters',
    );
    return '$_temp0';
  }

  @override
  String importDone(int count) {
    return 'Imported $count records';
  }

  @override
  String get ioweEmptyBody =>
      'Debts you record will appear here with their due dates.';

  @override
  String get ioweEmptyTitle => 'You owe nothing.';

  @override
  String get ioweSubtitle => 'Money you have to pay';

  @override
  String get ioweTitle => 'I Owe';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageEnglish => 'English';

  @override
  String leadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count reminders',
      one: '1 reminder',
      zero: 'No reminder',
    );
    return '$_temp0';
  }

  @override
  String get leadNone => 'No reminder';

  @override
  String get leadOnDueDate => 'On the due date';

  @override
  String get leadOneDayBefore => '1 day before';

  @override
  String get leadOneWeekBefore => '1 week before';

  @override
  String leadSummary(String lead) {
    return 'Reminder: $lead';
  }

  @override
  String get leadThreeDaysBefore => '3 days before';

  @override
  String get leadTwoDaysBefore => '2 days before';

  @override
  String get leadTwoWeeksBefore => '2 weeks before';

  @override
  String get ledgerAllPeople => 'People';

  @override
  String get ledgerSwitchIOwe => 'I Owe';

  @override
  String get ledgerSwitchOwedToMe => 'Owed to Me';

  @override
  String get loading => 'Loading…';

  @override
  String lockAttemptsLeft(int count) {
    return '$count attempts left';
  }

  @override
  String get lockBiometricReason => 'Confirm it\'s you to open Dhimmah';

  @override
  String get lockConfirmPin => 'Enter the PIN again to confirm';

  @override
  String lockCreatePin(int length) {
    return 'Create a $length-digit PIN';
  }

  @override
  String get lockCurrentPin => 'Current PIN';

  @override
  String get lockDisabledForSession => 'Lock is off until you close the app.';

  @override
  String get lockEnterPin => 'Enter your PIN to continue';

  @override
  String get lockNewPin => 'New PIN';

  @override
  String get lockPinMismatch => 'The two PINs do not match.';

  @override
  String get lockPinUpdated => 'PIN updated';

  @override
  String get lockTitle => 'App lock';

  @override
  String get lockTooManyAttempts => 'Too many attempts. Try again shortly.';

  @override
  String get lockUseBiometric => 'Use biometrics';

  @override
  String get lockWrongPin => 'Wrong PIN. Try again.';

  @override
  String get longPressForOptions => 'Long press for options';

  @override
  String monthEndDayNumber(int day) {
    return 'Day $day';
  }

  @override
  String get monthEndLastDay => 'Last day of the month';

  @override
  String get moreFollowUpSection => 'Follow-up';

  @override
  String get moreTitle => 'More';

  @override
  String get navHome => 'Home';

  @override
  String get navIOwe => 'I Owe';

  @override
  String get navLedger => 'Ledger';

  @override
  String get navMore => 'More';

  @override
  String get navObligations => 'Obligations';

  @override
  String get navObligationsShort => 'Obligations';

  @override
  String get navOwedToMe => 'Owed to Me';

  @override
  String get navPeople => 'People';

  @override
  String get navReminders => 'Reminders';

  @override
  String get navReports => 'Reports';

  @override
  String get navSettings => 'Settings';

  @override
  String get netLabel => 'Net';

  @override
  String get noInternetNeeded => 'Works offline';

  @override
  String get notifChannelDueBody => 'A payment is due today or already late';

  @override
  String get notifChannelDueName => 'Due now';

  @override
  String get notifChannelBackupName => 'Backup problem';

  @override
  String get notifChannelBackupBody =>
      'An alert when Dhimmah cannot save a copy of your data';

  @override
  String get backupAlertTitle => 'Backups need your attention';

  @override
  String get backupAlertBody =>
      'Dhimmah could not save a copy of your changes. Your data is saved inside the app, and it will try again on its own.';

  @override
  String get notifChannelSummaryBody =>
      'A summary of your ledger at the end of each month';

  @override
  String get notifChannelSummaryName => 'Monthly summary';

  @override
  String get notifChannelUpcomingBody =>
      'A payment falls due in the next few days';

  @override
  String get notifChannelUpcomingName => 'Coming up';

  @override
  String notifDueSoonBody(String name, String amount, String when) {
    return '$name — $amount · $when';
  }

  @override
  String get notifDueSoonTitle => 'A payment is coming up';

  @override
  String notifDueTodayBody(String name, String amount) {
    return '$name — $amount is due today.';
  }

  @override
  String get notifDueTodayTitle => 'Due today';

  @override
  String notifMonthEndBody(String iOwe, String owedToMe, String paid) {
    return 'You owe $iOwe · Owed to you $owedToMe · Paid $paid';
  }

  @override
  String notifMonthEndBodyWithOverdue(
    String iOwe,
    String owedToMe,
    String paid,
    String overdue,
  ) {
    return 'You owe $iOwe · Owed to you $owedToMe · Paid $paid · Overdue $overdue';
  }

  @override
  String get notifMonthEndTitle => 'Your month in review';

  @override
  String get notifObligationTitle => 'An obligation is due';

  @override
  String notifOverdueBody(String name, String amount, String when) {
    return '$name — $amount · $when';
  }

  @override
  String get notifOverdueTitle => 'An overdue payment';

  @override
  String get notifPermissionDenied =>
      'Notifications are turned off in system settings.';

  @override
  String notifReminderBody(String title) {
    return '$title';
  }

  @override
  String get notifReminderTitle => 'Reminder';

  @override
  String notifWeeklyDigestTitle(int count) {
    return '$count commitments due this week';
  }

  @override
  String get numeralsArabicIndic => 'Arabic-Indic (١٢٣٤)';

  @override
  String get numeralsLatin => 'Western (1234)';

  @override
  String get obligationArchived => 'Archived obligation';

  @override
  String obligationEndedOn(String date) {
    return 'Ends $date';
  }

  @override
  String get obligationFormEdit => 'Edit obligation';

  @override
  String get obligationFormNew => 'New obligation';

  @override
  String get obligationHistory => 'History';

  @override
  String get obligationMarkPaid => 'Mark as paid';

  @override
  String get obligationMarkedPaid => 'Marked as paid';

  @override
  String get obligationMarkedSkipped => 'Period skipped';

  @override
  String get obligationMonthlyAmount => 'Amount';

  @override
  String obligationNextDue(String date) {
    return 'Next due $date';
  }

  @override
  String get obligationSkip => 'Skip this period';

  @override
  String get obligationUndoPayment => 'Undo payment';

  @override
  String get obligationsEmptyBody =>
      'Add rent, bills or subscriptions and Dhimmah will track them for you.';

  @override
  String get obligationsEmptyTitle => 'No obligations yet.';

  @override
  String get obligationsSubtitle => 'Everything you pay on a schedule';

  @override
  String get obligationsTitle => 'Obligations';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingCurrencyBody =>
      'Used for new records. Each record can still use its own currency.';

  @override
  String get onboardingCurrencyTitle => 'Your default currency';

  @override
  String get onboardingEnableNotifications => 'Enable reminders';

  @override
  String get onboardingLanguageBody => 'You can change this later in Settings.';

  @override
  String get onboardingLanguageTitle => 'Choose your language';

  @override
  String get onboardingMaybeLater => 'Maybe later';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingNotificationsBody =>
      'Dhimmah needs permission to send due-date reminders. They are scheduled locally and never leave your device.';

  @override
  String get onboardingNotificationsDenied =>
      'Permission was not granted. You can enable it in Settings.';

  @override
  String get onboardingNotificationsTitle => 'Reminders';

  @override
  String get onboardingReadyTitle => 'You\'re all set.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingSlide1Body =>
      'Record what you owe and what you\'re owed, and see where you stand the moment you open the app.';

  @override
  String get onboardingSlide1Title => 'Your financial ledger, in one place.';

  @override
  String get onboardingSlide2Body =>
      'Debts, part payments and recurring commitments — with the balance worked out for you.';

  @override
  String get onboardingSlide2Title => 'Record both sides.';

  @override
  String get onboardingSlide3Body =>
      'Offline reminders, plus a summary of your ledger at the end of every month.';

  @override
  String get onboardingSlide3Title => 'Never miss a due date.';

  @override
  String get onboardingStart => 'Get started';

  @override
  String get owedToMeEmptyBody =>
      'Record what others owe you and follow it here.';

  @override
  String get owedToMeEmptyTitle => 'Nothing owed to you yet.';

  @override
  String get owedToMeSubtitle => 'Money owed to you';

  @override
  String get owedToMeTitle => 'Owed to Me';

  @override
  String get paymentAmount => 'Amount';

  @override
  String get paymentDate => 'Date';

  @override
  String get paymentDeleteBody =>
      'The balance will go back to what it was before.';

  @override
  String get paymentDeleteTitle => 'Delete this payment?';

  @override
  String get paymentDeleted => 'Payment deleted';

  @override
  String get paymentEditTitle => 'Edit payment';

  @override
  String paymentExceedsRemaining(String amount) {
    return 'That is more than the remaining $amount; the debt will be settled in full.';
  }

  @override
  String get paymentNote => 'Note';

  @override
  String get paymentPayFull => 'Pay the full remaining amount';

  @override
  String paymentRemainingAfter(String amount) {
    return 'Remaining after this payment: $amount';
  }

  @override
  String get paymentSave => 'Save payment';

  @override
  String get paymentSaved => 'Payment recorded';

  @override
  String get paymentTitle => 'Record a payment';

  @override
  String get paymentWillSettle => 'This payment settles the debt in full.';

  @override
  String get peopleEmptyBody =>
      'Add someone to link debts and follow the balance.';

  @override
  String get peopleEmptyTitle => 'No people yet.';

  @override
  String get peopleTitle => 'People';

  @override
  String get periodAny => 'Any time';

  @override
  String get periodCustom => 'Custom';

  @override
  String periodFrom(String date) {
    return 'From $date';
  }

  @override
  String get periodFromLabel => 'From date';

  @override
  String get periodThisMonth => 'This month';

  @override
  String get periodThisWeek => 'This week';

  @override
  String periodTo(String date) {
    return 'To $date';
  }

  @override
  String get periodToLabel => 'To date';

  @override
  String get periodToday => 'Today';

  @override
  String get personAddDebt => 'Add a debt for this person';

  @override
  String get personArchived => 'Archived';

  @override
  String get personAvatarColor => 'Avatar colour';

  @override
  String get personBalance => 'Balance';

  @override
  String personDebtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count debts',
      one: '1 debt',
      zero: 'No debts',
    );
    return '$_temp0';
  }

  @override
  String get personDebtsSection => 'Debts';

  @override
  String get personDeleteBody =>
      'Their debts are kept, but will no longer be linked to them.';

  @override
  String get personDeleteTitle => 'Delete this person?';

  @override
  String get personDeleted => 'Person deleted';

  @override
  String get personFormEdit => 'Edit person';

  @override
  String get personNameLabel => 'Person\'s name';

  @override
  String get personNew => 'New person';

  @override
  String get personNoDebts => 'No debts linked to this person.';

  @override
  String get personPhoneLabel => 'Phone number';

  @override
  String get progressLabel => 'Progress';

  @override
  String get recordDeleted => 'Deleted';

  @override
  String get recordSaved => 'Saved';

  @override
  String recordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: '1 record',
      zero: 'No records',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceCustom => 'Custom';

  @override
  String recurrenceEveryN(int count, String unit) {
    return 'Every $count $unit';
  }

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get recurrenceNone => 'Does not repeat';

  @override
  String get recurrenceQuarterly => 'Every 3 months';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceYearly => 'Yearly';

  @override
  String get reminderCompletedMessage => 'Reminder completed';

  @override
  String get reminderCreated => 'Reminder created';

  @override
  String get reminderFormEdit => 'Edit reminder';

  @override
  String get reminderMarkDone => 'Done';

  @override
  String get reminderNew => 'New reminder';

  @override
  String get reminderReopen => 'Reopen';

  @override
  String get reminderTitleHint => 'e.g. Renew the insurance';

  @override
  String get reminderTitleLabel => 'Title';

  @override
  String get remindersCompleted => 'Completed';

  @override
  String get remindersEmptyBody =>
      'Create a reminder for anything you don\'t want to forget.';

  @override
  String get remindersEmptyTitle => 'No reminders yet.';

  @override
  String get remindersLater => 'Later';

  @override
  String get remindersOverdue => 'Overdue';

  @override
  String get remindersSubtitle => 'Everything not to forget';

  @override
  String get remindersThisWeek => 'This week';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersToday => 'Today';

  @override
  String get remindersTomorrow => 'Tomorrow';

  @override
  String get reportAccountSummary => 'Account summary';

  @override
  String get reportActiveDebts => 'Active debts';

  @override
  String get reportChartPaidVsNew => 'Paid vs new debts';

  @override
  String get reportClosedDebts => 'Closed debts';

  @override
  String get reportColumnAmount => 'Amount';

  @override
  String get reportColumnBalance => 'Balance';

  @override
  String get reportColumnDate => 'Date';

  @override
  String get reportColumnDebt => 'Debt';

  @override
  String get reportColumnDirection => 'Type';

  @override
  String get reportColumnDue => 'Due';

  @override
  String get reportColumnOperation => 'Operation';

  @override
  String get reportColumnPaid => 'Paid';

  @override
  String get reportColumnRemaining => 'Remaining';

  @override
  String get reportColumnTotal => 'Total';

  @override
  String get reportCurrentPosition => 'Current position';

  @override
  String get reportDebtsBreakdown => 'Debts';

  @override
  String get reportDeclaration =>
      'This statement was produced by Dhimmah from records entered by its owner, and is provided for reference and reminder only.';

  @override
  String get reportDocumentId => 'Document ID';

  @override
  String get reportDocumentNumber => 'Document no.';

  @override
  String get reportEmptyBody => 'Try another month, or add a new record.';

  @override
  String get reportEmptyTitle => 'Nothing recorded for this month.';

  @override
  String get reportExportPdf => 'Export PDF';

  @override
  String get reportFutureMonth => 'That month has not started yet.';

  @override
  String get reportGeneratedBy => 'Generated by Dhimmah';

  @override
  String get reportInsightAllClear =>
      'Nothing is overdue — everything is on track.';

  @override
  String reportInsightClosed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count debts were closed this month.',
      one: 'One debt was closed this month.',
      zero: 'No debts were closed this month.',
    );
    return '$_temp0';
  }

  @override
  String reportInsightOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count debts are overdue and need chasing.',
      one: 'One debt is overdue and needs chasing.',
      zero: 'No debts are overdue.',
    );
    return '$_temp0';
  }

  @override
  String get reportInsightQuiet => 'Nothing has been recorded this month yet.';

  @override
  String reportInsightUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commitments fall due in the coming days.',
      one: 'One commitment falls due in the coming days.',
      zero: 'No commitments fall due in the coming days.',
    );
    return '$_temp0';
  }

  @override
  String get reportIssuedOn => 'Issued';

  @override
  String get reportMonthlyTitle => 'Monthly report';

  @override
  String get reportNeedsAttention => 'Needs your attention';

  @override
  String get reportNeedsAttentionEmpty => 'Nothing is late or due today.';

  @override
  String get reportNewDebts => 'New debts';

  @override
  String get reportObligations => 'Obligations';

  @override
  String get reportOpenPdf => 'Open file';

  @override
  String get reportOptionBreakdown => 'Break down each debt';

  @override
  String get reportOptionNotes => 'Notes';

  @override
  String get reportOptionPayments => 'Payment details';

  @override
  String get reportOptionPhone => 'Phone number';

  @override
  String get reportOptionsTitle => 'Statement options';

  @override
  String get reportOverdue => 'Overdue';

  @override
  String reportPageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String get reportPaidOut => 'Paid out';

  @override
  String get reportPaymentHistory => 'Payment history';

  @override
  String get reportPeopleCount => 'People';

  @override
  String get reportPickMonth => 'Choose a month';

  @override
  String get reportReceived => 'Received';

  @override
  String get reportSavePdf => 'Print or save';

  @override
  String get reportSettled => 'Total paid';

  @override
  String get reportSharePdf => 'Share PDF';

  @override
  String get reportShareStatement => 'Share statement';

  @override
  String get reportStatementFor => 'Statement for';

  @override
  String get reportStatementReady => 'Statement ready';

  @override
  String get reportStatementReadyBody => 'You can review it before sending.';

  @override
  String get reportStatementTitle => 'Debt Statement';

  @override
  String reportTrend(int months) {
    return 'Last $months months';
  }

  @override
  String get reportTrendNewDebt => 'New debts';

  @override
  String get reportTrendSettled => 'Paid';

  @override
  String get reportsSubtitle => 'A clear monthly summary';

  @override
  String get reportsTitle => 'Reports';

  @override
  String get requiredMark => 'Required';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get saveDebt => 'Save debt';

  @override
  String get saving => 'Saving…';

  @override
  String get searchAction => 'Search';

  @override
  String get searchEmptyBody => 'Try another word or clear the filters.';

  @override
  String get searchEmptyTitle => 'No matching results.';

  @override
  String get searchHint => 'Search names, obligations and notes';

  @override
  String get searchRecent => 'Recent searches';

  @override
  String get searchTitle => 'Search';

  @override
  String get seeAll => 'See all';

  @override
  String get settingsAbout => 'About';

  @override
  String get settingsAboutBody =>
      'Dhimmah is a personal ledger for what you owe and what you are owed. It works entirely offline, and your data never leaves your device.';

  @override
  String get settingsAppLock => 'App lock';

  @override
  String get settingsAppLockBody => 'Ask for a PIN when the app opens';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsBiometric => 'Unlock with biometrics';

  @override
  String get settingsBiometricBody => 'Use your fingerprint or face';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsClearData => 'Delete all data';

  @override
  String get settingsCurrenciesInUse => 'Currencies in use';

  @override
  String get settingsCurrency => 'Default currency';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsDueSoonWindow => '\"Due soon\" window';

  @override
  String get settingsExport => 'Export data';

  @override
  String get settingsExportBody => 'Keep a copy of your data';

  @override
  String get settingsImport => 'Import data';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLicenses => 'Licences';

  @override
  String get settingsMonthEnd => 'Month-end summary';

  @override
  String get settingsMonthEndBody =>
      'An automatic summary of your ledger each month';

  @override
  String get settingsMonthEndDay => 'Send on';

  @override
  String get settingsMonthEndTime => 'Send at';

  @override
  String get settingsNotificationTime => 'Notification time';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsNumerals => 'Number style';

  @override
  String get settingsPrivacyNote => 'Your data stays on your device';

  @override
  String get settingsRateApp => 'Rate Dhimmah';

  @override
  String get settingsReminderLead => 'Remind me before it is due';

  @override
  String get settingsRemindersEnabled => 'Reminders';

  @override
  String get settingsRemindersEnabledBody =>
      'Local notifications that work offline';

  @override
  String get settingsSecurity => 'Security';

  @override
  String get settingsSendFeedback => 'Send feedback';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get shareFooter => 'Shared from Dhimmah';

  @override
  String get shareLineDirectionIOwe => 'I owe this';

  @override
  String get shareLineDirectionOwedToMe => 'Owed to me';

  @override
  String shareLineDue(String date) {
    return 'Due: $date';
  }

  @override
  String shareLinePaid(String amount) {
    return 'Paid: $amount';
  }

  @override
  String shareLinePaidOn(String date) {
    return 'Paid on: $date';
  }

  @override
  String shareLineRemaining(String amount) {
    return 'Remaining: $amount';
  }

  @override
  String shareLineTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String sharePaymentBody(String person, String amount, String date) {
    return '$person · $amount · $date';
  }

  @override
  String get sharePaymentTitle => 'Payment receipt';

  @override
  String get shareSubject => 'Debt details';

  @override
  String get somethingWentWrong => 'Something went wrong.';

  @override
  String get sortAmountHighest => 'Highest amount';

  @override
  String get sortAmountLowest => 'Lowest amount';

  @override
  String get sortDueLatest => 'Due latest';

  @override
  String get sortDueSoonest => 'Due soonest';

  @override
  String get sortNameAscending => 'Name (A–Z)';

  @override
  String get sortOldestAdded => 'Oldest first';

  @override
  String get sortRecentlyAdded => 'Recently added';

  @override
  String get startupFailedBody =>
      'Something went wrong opening the data on your device.';

  @override
  String get startupFailedRetry => 'Try again';

  @override
  String get startupFailedSafe => 'Nothing in your ledger was changed.';

  @override
  String get startupFailedTitle => 'Could not open your ledger';

  @override
  String get startupFailedTooNew =>
      'This data was written by a newer version of Dhimmah. Update the app, then try again.';

  @override
  String get statusActive => 'Ongoing';

  @override
  String get statusArchived => 'Archived';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get statusDismissed => 'Dismissed';

  @override
  String get statusDueSoon => 'Due soon';

  @override
  String get statusDueToday => 'Due today';

  @override
  String get statusOverdue => 'Overdue';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusPartiallyPaid => 'Partially paid';

  @override
  String get statusSkipped => 'Skipped';

  @override
  String get statusUnpaid => 'Unpaid';

  @override
  String get statusUpcoming => 'Upcoming';

  @override
  String get swipeToDelete => 'Swipe to delete';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

  @override
  String get todayLabel => 'Today';

  @override
  String get totalLabel => 'Total';

  @override
  String get unitDay => 'day';

  @override
  String get unitMonth => 'month';

  @override
  String get unitWeek => 'week';

  @override
  String get unitYear => 'year';

  @override
  String get unknownPerson => 'Untitled';

  @override
  String get updateAvailableBody =>
      'A newer version of Dhimmah is ready on Google Play.';

  @override
  String get updateAvailableTitle => 'A new update is available';

  @override
  String get updateDownloadingBody =>
      'You can keep using Dhimmah while it downloads.';

  @override
  String get updateDownloadingTitle => 'Downloading the update';

  @override
  String get updateLater => 'Later';

  @override
  String get updateNow => 'Update now';

  @override
  String updatePercent(int percent) {
    return '$percent%';
  }

  @override
  String get updateReadyBody =>
      'The download finished. Google Play will install it and restart Dhimmah.';

  @override
  String get updateReadyTitle => 'The update is ready to install';

  @override
  String get updateRestartAndInstall => 'Restart and update';

  @override
  String get validationAmountTooLarge => 'That amount is too large.';

  @override
  String get validationDayOfMonth => 'Choose a day between 1 and 31.';

  @override
  String get validationDueBeforeIssue =>
      'The due date is before the record date.';

  @override
  String get validationEndBeforeStart =>
      'The end date is before the start date.';

  @override
  String get validationInvalidAmount => 'Enter an amount greater than zero.';

  @override
  String get validationNameExists => 'Someone with that name already exists.';

  @override
  String get validationNameTooLong => 'That name is too long.';

  @override
  String get validationNameTooShort => 'That name is too short.';

  @override
  String get validationNegative => 'Negative values are not allowed.';

  @override
  String get validationNoteTooLong => 'That note is too long.';

  @override
  String validationOverPayment(String amount) {
    return 'That is more than the remaining $amount.';
  }

  @override
  String get validationPhoneInvalid => 'Enter a valid phone number.';

  @override
  String get validationRequired => 'This field is required.';

  @override
  String get validationTitleTooLong => 'That description is too long.';

  @override
  String debtFormWithPerson(String name) {
    return 'Debt with $name';
  }

  @override
  String debtSavedMoved(String side) {
    return 'Saved. The debt moved to “$side”.';
  }

  @override
  String debtSavedParticipantRemoved(String name) {
    return 'Saved. No longer linked to $name.';
  }

  @override
  String get fieldPeople => 'People';

  @override
  String get fieldPersonPlaceholder => 'Choose one or more people';

  @override
  String get participantsAdd => 'Add a person';

  @override
  String get participantsAddMore => 'Add more people';

  @override
  String get participantsSearchHint => 'Search for a person';

  @override
  String get participantsSelected => 'Selected';

  @override
  String requiredFieldsMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count required fields are still missing.',
      one: 'One required field is still missing.',
    );
    return '$_temp0';
  }

  @override
  String get unsavedChangesBody => 'Your changes are not saved. Leave anyway?';

  @override
  String get unsavedChangesLeave => 'Leave without saving';

  @override
  String get unsavedChangesStay => 'Keep editing';

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get validationSelectDirection =>
      'Choose the debt type: I owe, or owed to me.';

  @override
  String get validationSelectParticipant => 'Choose at least one person.';

  @override
  String get reminderNotArmedOff =>
      'Reminders are switched off in Settings, so this record will not notify you.';

  @override
  String get reminderNotArmedDenied =>
      'Notifications are blocked by the system, so this record will not notify you.';

  @override
  String get settingsBackup => 'Backup and restore';

  @override
  String get backupSectionHint =>
      'A copy of everything, in one file you can keep.';

  @override
  String get backupAutoTitle => 'Automatic backup';

  @override
  String get backupAutoStateOn => 'On';

  @override
  String get backupAutoStateOff => 'Off';

  @override
  String get backupAutoOnBody =>
      'Dhimmah saves your changes on its own after every important change, and when you leave the app.';

  @override
  String get backupAutoOffBody =>
      'Your current data is saved inside the app. No new copies will be made on their own until you turn it back on.';

  @override
  String get backupDetailAutomatic => 'Automatic saving';

  @override
  String get backupDetailLastCopy => 'Last copy';

  @override
  String get backupDetailRestorable => 'Copies to restore';

  @override
  String get backupDetailPending => 'Unsaved changes';

  @override
  String get backupDetailFolder => 'Backup folder';

  @override
  String get backupDetailAttempts => 'Failed attempts';

  @override
  String get backupHistoryLatest => 'Latest copy';

  @override
  String get backupHistoryVerified => 'Verified';

  @override
  String get backupFolderTitle => 'Backup folder';

  @override
  String get backupFolderSetupTitle => 'Set up a place for your backups';

  @override
  String get backupFolderSetupBody =>
      'Dhimmah will use this folder to save backups, and to open them directly when restoring.';

  @override
  String get backupFolderChoose => 'Choose the backup folder';

  @override
  String get backupFolderChange => 'Change folder';

  @override
  String get backupFolderCheck => 'Check now';

  @override
  String get backupFolderLater => 'Later';

  @override
  String get backupFolderAvailable => 'Available';

  @override
  String get backupFolderMissing => 'The backup folder is not available';

  @override
  String get backupFolderLostAccess =>
      'The app can no longer reach this folder: access was removed, or the folder was moved or deleted.';

  @override
  String get backupFolderReauthorize => 'Allow access again';

  @override
  String backupFolderBackupsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valid backups',
      one: 'One valid backup',
      zero: 'No valid backups',
    );
    return '$_temp0';
  }

  @override
  String get backupFolderEmpty => 'No backups in this folder';

  @override
  String get backupFolderConfirmTitle => 'Use this folder?';

  @override
  String get backupFolderConfirmBody =>
      'A “Dhimmah Backups” folder cannot be created here. Save the backups in the folder you picked?';

  @override
  String get backupFolderUseIt => 'Use this folder';

  @override
  String get backupFolderDecline => 'Choose another folder';

  @override
  String backupFolderInvalidNote(int count) {
    return 'Files that look like backups but are not valid: $count';
  }

  @override
  String get backupFolderNotWritable => 'The folder is read-only';

  @override
  String get backupFolderError => 'The folder could not be reached';

  @override
  String get backupFolderVerifying => 'Checking the folder';

  @override
  String get backupHistoryInternal => 'Inside the app';

  @override
  String get backupHistoryFolder => 'In the backup folder';

  @override
  String get backupExternalDeleted => 'Deleted from the folder';

  @override
  String get backupExternalDeleteFailed =>
      'Could not delete it from the folder';

  @override
  String get backupNowAction => 'Save an external copy';

  @override
  String get backupSaveExternalBody =>
      'A file you keep, in a place you choose.';

  @override
  String get backupShareTile => 'Share the copy';

  @override
  String get backupShareTileBody => 'Send a copy to another app.';

  @override
  String get backupExternalSaved => 'The copy was saved and verified';

  @override
  String backupExternalSavedBody(String name, String size) {
    return 'File: $name · $size';
  }

  @override
  String get backupExternalFailedWrite =>
      'The file could not be written to the place you chose';

  @override
  String get backupExternalFailedReadBack =>
      'The file was written but could not be verified afterwards';

  @override
  String get backupExternalFailedIncomplete =>
      'The saved file is empty or incomplete';

  @override
  String get backupExternalFailedInvalid =>
      'The saved file did not pass the content check';

  @override
  String get backupExternalFailedUnavailable =>
      'This device offers no way to choose where to save';

  @override
  String get backupRestoreAction => 'Restore from a file';

  @override
  String get backupPreviousAction => 'Previous backups';

  @override
  String backupCopiesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies',
      one: 'One copy',
      zero: 'No copies',
    );
    return '$_temp0';
  }

  @override
  String get backupPreviousTitle => 'Previous backups';

  @override
  String get backupPreviousEmpty => 'No backups are stored on this device.';

  @override
  String get backupProtectionProtected => 'Your data is protected';

  @override
  String get backupProtectionPending => 'Some changes are waiting to be saved';

  @override
  String get backupProtectionBackingUp => 'Saving your changes';

  @override
  String get backupProtectionNever => 'Your data is not protected yet';

  @override
  String get backupProtectionRecoverable => 'A copy can be restored';

  @override
  String get backupProtectionAttention => 'Backups need your attention';

  @override
  String get backupProtectionStorage =>
      'Could not write to the backup location';

  @override
  String get backupProtectionNoLocation => 'No permanent backup location yet';

  @override
  String backupProtectionLastSuccess(String when) {
    return 'Last successful copy · $when';
  }

  @override
  String get backupProtectionNeverWorked => 'No copy has been saved yet';

  @override
  String get backupProtectionDetails => 'Protection details';

  @override
  String get backupProtectionHideDetails => 'Hide details';

  @override
  String backupProtectionCopiesInside(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count copies inside the app',
      one: 'One copy inside the app',
      zero: 'Nothing inside the app',
    );
    return '$_temp0';
  }

  @override
  String backupProtectionCopiesOutside(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in your folder',
      one: 'one in your folder',
      zero: 'none in your folder',
    );
    return '$_temp0';
  }

  @override
  String backupProtectionWaiting(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count records',
      one: 'One record',
      zero: 'No records',
    );
    return '$_temp0';
  }

  @override
  String get backupProtectionFolderNone => 'Not chosen yet';

  @override
  String get backupProtectionAutoOff => 'Automatic saving is off';

  @override
  String backupProtectionFailedTimes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: 'once',
    );
    return '$_temp0';
  }

  @override
  String get backupProtectionDataSafe =>
      'Your current data is saved inside the app and is unaffected.';

  @override
  String get backupProtectionHowTitle => 'How Dhimmah protects your data';

  @override
  String get backupProtectionHowBody =>
      'Dhimmah saves a copy of your changes on its own, and verifies every copy by reading it back after it is written. It keeps enough recovery points to step back, and never deletes a copy you made by hand. A restore never starts without your confirmation, and a safety copy of your current data is taken first. If saving fails, the data inside the app is left exactly as it is.';

  @override
  String get backupEntryAuto => 'Automatic';

  @override
  String get backupEntryManual => 'Manual';

  @override
  String get backupEntrySafety => 'Taken before a restore';

  @override
  String get backupShareAction => 'Share';

  @override
  String get backupDeleteAction => 'Delete';

  @override
  String get backupDeleted => 'Backup deleted';

  @override
  String get backupDeleteFailed =>
      'The backup could not be deleted, and is still listed';

  @override
  String get backupCreated => 'Backup created';

  @override
  String get backupStepReading => 'Reading the records';

  @override
  String get backupStepBuilding => 'Preparing the copy';

  @override
  String get backupStepHashing => 'Computing its fingerprint';

  @override
  String get backupStepWriting => 'Writing the file';

  @override
  String get backupStepVerifying => 'Reading it back to verify it';

  @override
  String get backupStepRetaining => 'Tidying older copies';

  @override
  String get restoreStepReading => 'Reading the file';

  @override
  String get restoreStepDecoding => 'Decoding the file';

  @override
  String get restoreStepChecking => 'Checking the file’s integrity';

  @override
  String get restoreStepValidating => 'Checking the data';

  @override
  String get restoreStepPlanning => 'Working out what will be written';

  @override
  String get restoreStepSnapshot => 'Taking a safety copy of your current data';

  @override
  String get restoreStepWriting => 'Writing the data';

  @override
  String get restoreStepVerifying => 'Verifying the result';

  @override
  String get restoreStepRebuilding => 'Rebuilding the schedule and reminders';

  @override
  String get backupCreateFailed => 'The backup could not be created';

  @override
  String get backupRestoreTitle => 'Restore a backup';

  @override
  String get backupRestoreQuestion => 'Restore this data?';

  @override
  String get backupRestoreFrom => 'A backup from';

  @override
  String backupRestoreCounts(int people, int debts, int payments) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: 'One person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      debts,
      locale: localeName,
      other: '$debts debts',
      one: 'One debt',
    );
    String _temp2 = intl.Intl.pluralLogic(
      payments,
      locale: localeName,
      other: '$payments payments',
      one: 'One payment',
    );
    return '$_temp0 · $_temp1 · $_temp2';
  }

  @override
  String backupRestoreMore(int obligations, int reminders, int links) {
    String _temp0 = intl.Intl.pluralLogic(
      obligations,
      locale: localeName,
      other: '$obligations obligations',
      one: 'One obligation',
    );
    String _temp1 = intl.Intl.pluralLogic(
      reminders,
      locale: localeName,
      other: '$reminders reminders',
      one: 'One reminder',
    );
    String _temp2 = intl.Intl.pluralLogic(
      links,
      locale: localeName,
      other: '$links links',
      one: 'One link',
    );
    return '$_temp0 · $_temp1 · $_temp2';
  }

  @override
  String backupRestoreLastChange(String when) {
    return 'Last change in the file: $when';
  }

  @override
  String backupRestoreCurrencies(String codes, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Currencies: $codes',
      one: 'Currency: $codes',
    );
    return '$_temp0';
  }

  @override
  String get backupRestoreUnencrypted =>
      'This file is not encrypted: anyone who opens it can read your data.';

  @override
  String get backupRestoreSafetyNote =>
      'Dhimmah will back up your current data before restoring, so you can go back.';

  @override
  String get backupRestoreMode => 'How to restore';

  @override
  String get backupModeReplace => 'Replace';

  @override
  String get backupModeReplaceBody =>
      'The file becomes your data; what is on this device is replaced.';

  @override
  String get backupModeMerge => 'Merge';

  @override
  String get backupModeMergeBody =>
      'New records are added, newer ones update, and anything ambiguous is reported instead of guessed.';

  @override
  String get backupRestoreConfirm => 'Restore';

  @override
  String get backupRestoreDone => 'Restored successfully';

  @override
  String backupRestoreSummary(int people, int debts, int payments) {
    String _temp0 = intl.Intl.pluralLogic(
      people,
      locale: localeName,
      other: '$people people',
      one: 'One person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      debts,
      locale: localeName,
      other: '$debts debts',
      one: 'One debt',
    );
    String _temp2 = intl.Intl.pluralLogic(
      payments,
      locale: localeName,
      other: '$payments payments',
      one: 'One payment',
    );
    return '$_temp0 · $_temp1 · $_temp2';
  }

  @override
  String backupRestoreSkipped(int count) {
    return 'Already present: $count';
  }

  @override
  String get backupRestoreConflictsTitle => 'Records that need a look';

  @override
  String backupRestoreConflictsBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count records differ in the backup and were not newer; the ones you have were kept.',
      one:
          'One record differs in the backup and was not newer; the one you have was kept.',
    );
    return '$_temp0';
  }

  @override
  String get backupRestoreFailed =>
      'The restore failed, and your data is unchanged.';

  @override
  String get backupRestoreInvalid =>
      'This backup could not be restored because the file is invalid or damaged.';

  @override
  String get backupRestoreNotOurs => 'This file is not a valid Dhimmah backup.';

  @override
  String get backupRestoreTooNew =>
      'This backup comes from a newer version of the app. Update Dhimmah and try again.';

  @override
  String get backupRestoreContinue => 'Continue to Dhimmah';

  @override
  String get backupFoundTitle => 'We found a backup';

  @override
  String get backupFoundBody =>
      'There is no data on this device, and a saved copy can be restored.';

  @override
  String get backupPrivacyTitle => 'Where are backups kept?';

  @override
  String get backupPrivacyBody =>
      'Automatic copies live inside the app and nothing else can read them. When you share one, you choose the place — Files, Drive or another — and the file is not encrypted. Deleting the app deletes the copies inside it, so keep a copy off the device if the data matters.';

  @override
  String get backupSeparateFromExport =>
      'Export (CSV and JSON) is for reading and analysis, and is not used for restoring. The backup is what comes back.';
}
