// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get actionArchive => 'أرشفة';

  @override
  String get actionCancel => 'إلغاء';

  @override
  String get actionClear => 'مسح';

  @override
  String get actionClose => 'إغلاق';

  @override
  String get actionConfirm => 'تأكيد';

  @override
  String get actionCopy => 'نسخ';

  @override
  String get actionDelete => 'حذف';

  @override
  String get actionDisable => 'تعطيل';

  @override
  String get actionDone => 'تم';

  @override
  String get actionEdit => 'تعديل';

  @override
  String get actionEnable => 'تفعيل';

  @override
  String get actionOk => 'حسنًا';

  @override
  String get actionRetry => 'إعادة المحاولة';

  @override
  String get actionSave => 'حفظ';

  @override
  String get actionSelect => 'اختيار';

  @override
  String get actionShare => 'مشاركة';

  @override
  String get actionUnarchive => 'استعادة';

  @override
  String get actionUndo => 'تراجع';

  @override
  String get activityCleared => 'تم حذف كل البيانات';

  @override
  String get activityDebtArchived => 'تمت أرشفة دين';

  @override
  String get activityDebtClosed => 'تم إغلاق دين';

  @override
  String get activityDebtCreated => 'تم إنشاء دين';

  @override
  String get activityDebtDeleted => 'تم حذف دين';

  @override
  String get activityDebtReopened => 'تمت إعادة فتح دين';

  @override
  String get activityDebtUpdated => 'تم تعديل دين';

  @override
  String get activityExported => 'تم تصدير بيانات';

  @override
  String get activityImported => 'تم استيراد بيانات';

  @override
  String get activityMonthSummary => 'تم إنشاء الملخص الشهري';

  @override
  String get activityObligationCreated => 'تم إنشاء التزام';

  @override
  String get activityObligationPaid => 'تم دفع التزام';

  @override
  String get activityObligationSkipped => 'تم تخطي دورة';

  @override
  String get activityPaymentDeleted => 'تم حذف دفعة';

  @override
  String get activityPaymentRecorded => 'تم تسجيل دفعة';

  @override
  String get activityPersonCreated => 'تمت إضافة شخص';

  @override
  String get activityPersonDeleted => 'تم حذف شخص';

  @override
  String get activityPersonUpdated => 'تم تعديل بيانات شخص';

  @override
  String get activityReminderCompleted => 'تم إنجاز تذكير';

  @override
  String get activityReminderCreated => 'تم إنشاء تذكير';

  @override
  String get addDebtAction => 'إضافة دين';

  @override
  String get addDebtIOwe => 'دين عليّ';

  @override
  String get addDebtIOweHint => 'مبلغ يجب عليّ دفعه';

  @override
  String get addDebtOwedToMe => 'دين لي';

  @override
  String get addDebtOwedToMeHint => 'مبلغ مستحق لي';

  @override
  String get addObligation => 'التزام';

  @override
  String get addObligationHint => 'إيجار، فاتورة، اشتراك…';

  @override
  String get addPersonAction => 'إضافة شخص جديد';

  @override
  String get addReminder => 'تذكير';

  @override
  String get addReminderHint => 'موعد لا يجب نسيانه';

  @override
  String get addTitle => 'إضافة';

  @override
  String get allRecords => 'كل السجلات';

  @override
  String get appName => 'ذِمّة';

  @override
  String get appTagline => 'اعرف ما لك وما عليك';

  @override
  String get appTaglineShort => 'ذمّتك المالية، منظمة في مكان واحد.';

  @override
  String appVersion(String version, String build) {
    return 'الإصدار $version ($build)';
  }

  @override
  String get attentionDueSoon => 'قريب الاستحقاق';

  @override
  String get attentionDueToday => 'يستحق اليوم';

  @override
  String get attentionOverdue => 'متأخر';

  @override
  String get biometricNotEnrolled => 'لم تُسجَّل أي بصمة على هذا الجهاز بعد.';

  @override
  String get biometricUnavailable => 'البصمة غير متاحة على هذا الجهاز.';

  @override
  String get brandPromise =>
      'هذا المكان يحفظ كل شيء عليّ ولي، ويذكّرني بما يجب أن أدفعه وما يجب أن أستلمه.';

  @override
  String get categoryHousing => 'سكن';

  @override
  String get categoryInstallment => 'أقساط';

  @override
  String get categoryInsurance => 'تأمين';

  @override
  String get categoryLoan => 'قرض';

  @override
  String get categoryOther => 'أخرى';

  @override
  String get categorySalary => 'رواتب';

  @override
  String get categorySubscription => 'اشتراكات';

  @override
  String get categoryTax => 'ضرائب';

  @override
  String get categoryTelecom => 'اتصالات';

  @override
  String get categoryUtilities => 'فواتير';

  @override
  String get chooseOption => 'اختر';

  @override
  String get clearDataBody =>
      'سيتم حذف جميع الأشخاص والديون والدفعات والالتزامات والتذكيرات نهائيًا. لا يمكن التراجع.';

  @override
  String get clearDataTitle => 'حذف كل البيانات؟';

  @override
  String get collapse => 'طي';

  @override
  String get copiedToClipboard => 'تم النسخ';

  @override
  String currencySymbolWithCode(String code, String symbol) {
    return '$code $symbol';
  }

  @override
  String get dashboardAgainstYou => 'عليك';

  @override
  String get dashboardBalanced => 'متوازن';

  @override
  String get dashboardDueSoon => 'المستحق قريبًا';

  @override
  String dashboardDueSoonHint(int days) {
    return 'خلال $days أيام';
  }

  @override
  String get dashboardEmptyAddDebt => 'إضافة أول دين';

  @override
  String get dashboardEmptyAddObligation => 'إضافة التزام';

  @override
  String get dashboardEmptyBody =>
      'ابدأ بإضافة أول دين أو التزام، وسيتولى التطبيق التذكير والتنظيم.';

  @override
  String get dashboardEmptyTitle => 'ممتاز، لا توجد ديون مسجّلة حاليًا.';

  @override
  String get dashboardGreeting => 'مرحبًا';

  @override
  String get dashboardIOwe => 'عليّ';

  @override
  String get dashboardIOweHint => 'إجمالي ما يجب عليّ دفعه';

  @override
  String get dashboardInYourFavour => 'لك';

  @override
  String get dashboardNetPosition => 'الصافي';

  @override
  String get dashboardObligations => 'التزامات قادمة';

  @override
  String get dashboardOtherCurrencies => 'أرصدة بعملات أخرى';

  @override
  String get dashboardOverdue => 'المتأخر';

  @override
  String get dashboardOverdueHint => 'تجاوز موعد الاستحقاق';

  @override
  String get dashboardOwedToMe => 'لي';

  @override
  String get dashboardOwedToMeHint => 'إجمالي ما هو مستحق لي';

  @override
  String get dashboardRecentActivity => 'آخر العمليات';

  @override
  String get dashboardSubtitle => 'هذه نظرة سريعة على ذمتك المالية';

  @override
  String get dashboardUpcoming => 'الاستحقاقات القادمة';

  @override
  String get dashboardViewAll => 'عرض الكل';

  @override
  String dateDayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count يومًا',
      few: '$count أيام',
      two: 'يومان',
      one: 'يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'منذ $days يومًا',
      few: 'منذ $days أيام',
      two: 'منذ يومين',
      one: 'منذ يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String dateDueOn(String date) {
    return 'يستحق في $date';
  }

  @override
  String dateInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'خلال $days يومًا',
      few: 'خلال $days أيام',
      two: 'خلال يومين',
      one: 'خلال يوم واحد',
    );
    return '$_temp0';
  }

  @override
  String get dateNoDueDate => 'بدون استحقاق';

  @override
  String dateOverdueBy(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'متأخر $days يومًا',
      few: 'متأخر $days أيام',
      two: 'متأخر يومين',
      one: 'متأخر يومًا واحدًا',
    );
    return '$_temp0';
  }

  @override
  String get dateToday => 'اليوم';

  @override
  String get dateTomorrow => 'غدًا';

  @override
  String get dateYesterday => 'أمس';

  @override
  String get debtArchived => 'تمت الأرشفة';

  @override
  String get debtClosed => 'تم إغلاق الدين';

  @override
  String get debtCreated => 'تم إنشاء الدين';

  @override
  String get debtFormEdit => 'تعديل الدين';

  @override
  String get debtFormNewIOwe => 'دين عليّ';

  @override
  String get debtFormNewOwedToMe => 'دين لي';

  @override
  String get debtFormSubtitle => 'سجّل التفاصيل في ثوانٍ';

  @override
  String get debtRestored => 'تمت الاستعادة';

  @override
  String get debtSettled => 'تم سداد الدين بالكامل';

  @override
  String get debtUpdated => 'تم تحديث الدين';

  @override
  String get deleteConfirmBody => 'لا يمكن التراجع عن هذا الإجراء.';

  @override
  String get deleteConfirmTitle => 'تأكيد الحذف';

  @override
  String detailClosedOn(String date) {
    return 'أُغلق في $date';
  }

  @override
  String get detailDueOn => 'تاريخ الاستحقاق';

  @override
  String get detailIssuedOn => 'تاريخ الدين';

  @override
  String get detailNoPayments => 'لم تُسجَّل أي دفعة بعد.';

  @override
  String detailOverpaid(String amount) {
    return 'المبلغ المدفوع تجاوز أصل الدين بمقدار $amount.';
  }

  @override
  String get detailPaid => 'تم دفع';

  @override
  String detailProgress(int percent) {
    return '$percent% مدفوع';
  }

  @override
  String get detailRecordPayment => 'تسجيل دفعة';

  @override
  String get detailRemaining => 'المتبقي';

  @override
  String get detailTimeline => 'سجل العمليات';

  @override
  String get detailTotal => 'إجمالي الدين';

  @override
  String get expand => 'توسيع';

  @override
  String get exportCsv => 'CSV — جدول البيانات';

  @override
  String get exportCsvBody => 'افتحه في Excel أو Sheets';

  @override
  String get exportDone => 'تم التصدير';

  @override
  String get exportFailed => 'تعذّر التصدير. حاول مرة أخرى.';

  @override
  String get exportJson => 'JSON — نسخة كاملة';

  @override
  String get exportJsonBody => 'ملف يحتوي كل سجلاتك';

  @override
  String get exportPdf => 'PDF — تقرير';

  @override
  String get exportPdfBody => 'تقرير مرتب للمشاركة أو الطباعة';

  @override
  String get fieldAdvancedHint => 'الوصف، التذكير، التاريخ، الملاحظات';

  @override
  String get fieldAdvancedOptions => 'خيارات إضافية';

  @override
  String get fieldAdvancedSet => 'مضبوط';

  @override
  String get fieldAmount => 'المبلغ';

  @override
  String get fieldCategory => 'التصنيف';

  @override
  String get fieldCurrency => 'العملة';

  @override
  String get fieldDate => 'تاريخ الدين';

  @override
  String get fieldDayOfMonth => 'يوم الاستحقاق في الشهر';

  @override
  String get fieldDirection => 'نوع العملية';

  @override
  String get fieldDueDate => 'تاريخ الاستحقاق';

  @override
  String get fieldDueDateNone => 'بدون تاريخ استحقاق';

  @override
  String get fieldEndDate => 'تاريخ الانتهاء';

  @override
  String get fieldFrequency => 'التكرار';

  @override
  String get fieldNote => 'ملاحظات';

  @override
  String get fieldNoteHint => 'أي تفاصيل إضافية…';

  @override
  String get fieldObligationName => 'الاسم';

  @override
  String get fieldObligationNameHint => 'مثال: إيجار المنزل';

  @override
  String get fieldOptional => 'اختياري';

  @override
  String get fieldPerson => 'اسم الشخص';

  @override
  String get fieldPersonHint => 'اختر شخصًا أو أضف جديدًا';

  @override
  String get fieldPersonNone => 'بدون شخص';

  @override
  String get fieldRecurrence => 'تكرار الدين';

  @override
  String get fieldReminder => 'التذكير';

  @override
  String get fieldStartDate => 'تاريخ البداية';

  @override
  String get fieldTitle => 'الوصف';

  @override
  String get fieldTitleHint => 'مثال: سلفة، قرض سيارة';

  @override
  String get filterActive => 'نشط';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterApply => 'تطبيق';

  @override
  String get filterArchived => 'مؤرشف';

  @override
  String get filterDebts => 'ديون';

  @override
  String get filterDueSoon => 'قريب الاستحقاق';

  @override
  String get filterObligations => 'التزامات';

  @override
  String get filterPartiallyPaid => 'مدفوع جزئيًا';

  @override
  String get filterPeriod => 'الفترة';

  @override
  String get filterReset => 'إعادة تعيين';

  @override
  String get filterSort => 'الترتيب';

  @override
  String get filterStatus => 'الحالة';

  @override
  String get filterTitle => 'الفلاتر';

  @override
  String get filterType => 'النوع';

  @override
  String get filterUnpaid => 'غير مدفوع';

  @override
  String filtersApplied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فلاتر',
      one: 'فلتر واحد',
      zero: 'بدون فلاتر',
    );
    return '$_temp0';
  }

  @override
  String importDone(int count) {
    return 'تم استيراد $count سجلًا';
  }

  @override
  String get ioweEmptyBody => 'عندما تسجّل دينًا عليك سيظهر هنا مع موعده.';

  @override
  String get ioweEmptyTitle => 'لا توجد ديون عليك.';

  @override
  String get ioweSubtitle => 'الأموال التي يجب عليّ دفعها';

  @override
  String get ioweTitle => 'عليّ';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String leadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تذكيرًا',
      few: '$count تذكيرات',
      two: 'تذكيران',
      one: 'تذكير واحد',
      zero: 'بدون تذكير',
    );
    return '$_temp0';
  }

  @override
  String get leadNone => 'بدون تذكير';

  @override
  String get leadOnDueDate => 'في يوم الاستحقاق';

  @override
  String get leadOneDayBefore => 'قبل يوم';

  @override
  String get leadOneWeekBefore => 'قبل أسبوع';

  @override
  String leadSummary(String lead) {
    return 'التذكير: $lead';
  }

  @override
  String get leadThreeDaysBefore => 'قبل 3 أيام';

  @override
  String get leadTwoDaysBefore => 'قبل يومين';

  @override
  String get leadTwoWeeksBefore => 'قبل أسبوعين';

  @override
  String get ledgerAllPeople => 'الأشخاص';

  @override
  String get ledgerSwitchIOwe => 'عليّ';

  @override
  String get ledgerSwitchOwedToMe => 'لي';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String lockAttemptsLeft(int count) {
    return 'المحاولات المتبقية: $count';
  }

  @override
  String get lockBiometricReason => 'تأكيد هويتك لفتح ذِمّة';

  @override
  String get lockConfirmPin => 'أعد إدخال الرمز للتأكيد';

  @override
  String lockCreatePin(int length) {
    return 'أنشئ رمزًا مكونًا من $length أرقام';
  }

  @override
  String get lockCurrentPin => 'الرمز الحالي';

  @override
  String get lockDisabledForSession => 'القفل معطّل حتى إغلاق التطبيق.';

  @override
  String get lockEnterPin => 'أدخل الرمز للمتابعة';

  @override
  String get lockNewPin => 'الرمز الجديد';

  @override
  String get lockPinMismatch => 'الرمزان غير متطابقين.';

  @override
  String get lockPinUpdated => 'تم تحديث الرمز';

  @override
  String get lockTitle => 'قفل التطبيق';

  @override
  String get lockTooManyAttempts => 'محاولات كثيرة. حاول بعد قليل.';

  @override
  String get lockUseBiometric => 'استخدم البصمة';

  @override
  String get lockWrongPin => 'الرمز غير صحيح. حاول مرة أخرى.';

  @override
  String get longPressForOptions => 'اضغط مطولًا للمزيد';

  @override
  String monthEndDayNumber(int day) {
    return 'يوم $day';
  }

  @override
  String get monthEndLastDay => 'آخر يوم من الشهر';

  @override
  String get moreFollowUpSection => 'المتابعة';

  @override
  String get moreTitle => 'المزيد';

  @override
  String get navHome => 'الرئيسية';

  @override
  String get navIOwe => 'عليّ';

  @override
  String get navLedger => 'السجل';

  @override
  String get navMore => 'المزيد';

  @override
  String get navObligations => 'الالتزامات';

  @override
  String get navObligationsShort => 'التزامات';

  @override
  String get navOwedToMe => 'لي';

  @override
  String get navPeople => 'الأشخاص';

  @override
  String get navReminders => 'التذكيرات';

  @override
  String get navReports => 'التقارير';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get netLabel => 'الصافي';

  @override
  String get noInternetNeeded => 'يعمل بدون إنترنت';

  @override
  String get notifChannelDueBody => 'دفعة مستحقة اليوم أو متأخرة';

  @override
  String get notifChannelDueName => 'مستحق الآن';

  @override
  String get notifChannelRemindersBody =>
      'تنبيهات الديون والالتزامات قبل موعدها';

  @override
  String get notifChannelRemindersName => 'تذكيرات الاستحقاق';

  @override
  String get notifChannelSummaryBody => 'ملخص ذمتك في نهاية كل شهر';

  @override
  String get notifChannelSummaryName => 'الملخص الشهري';

  @override
  String get notifChannelUpcomingBody => 'دفعة تستحق خلال الأيام القادمة';

  @override
  String get notifChannelUpcomingName => 'استحقاقات قادمة';

  @override
  String notifDueSoonBody(String name, String amount, String when) {
    return '$name — $amount · $when';
  }

  @override
  String get notifDueSoonTitle => 'دفعة مستحقة قريبًا';

  @override
  String notifDueTodayBody(String name, String amount) {
    return '$name — $amount يستحق اليوم.';
  }

  @override
  String get notifDueTodayTitle => 'موعد سداد اليوم';

  @override
  String notifMonthEndBody(String iOwe, String owedToMe, String paid) {
    return 'عليّ $iOwe · لي $owedToMe · مدفوع $paid';
  }

  @override
  String notifMonthEndBodyWithOverdue(
    String iOwe,
    String owedToMe,
    String paid,
    String overdue,
  ) {
    return 'عليّ $iOwe · لي $owedToMe · مدفوع $paid · متأخر $overdue';
  }

  @override
  String get notifMonthEndTitle => 'ملخص ذمتك لهذا الشهر';

  @override
  String get notifObligationTitle => 'التزام مستحق';

  @override
  String notifOverdueBody(String name, String amount, String when) {
    return '$name — $amount · $when';
  }

  @override
  String get notifOverdueTitle => 'دفعة متأخرة';

  @override
  String get notifPermissionDenied => 'الإشعارات غير مفعّلة في إعدادات النظام.';

  @override
  String notifReminderBody(String title) {
    return '$title';
  }

  @override
  String get notifReminderTitle => 'تذكير';

  @override
  String notifWeeklyDigestTitle(int count) {
    return '$count التزامات قادمة هذا الأسبوع';
  }

  @override
  String get numeralsArabicIndic => 'أرقام عربية (١٢٣٤)';

  @override
  String get numeralsLatin => 'أرقام غربية (1234)';

  @override
  String get obligationArchived => 'التزام مؤرشف';

  @override
  String obligationEndedOn(String date) {
    return 'ينتهي في $date';
  }

  @override
  String get obligationFormEdit => 'تعديل الالتزام';

  @override
  String get obligationFormNew => 'التزام جديد';

  @override
  String get obligationHistory => 'السجل';

  @override
  String get obligationMarkPaid => 'تسجيل الدفع';

  @override
  String get obligationMarkedPaid => 'تم تسجيل الدفع';

  @override
  String get obligationMarkedSkipped => 'تم تخطي هذه الدورة';

  @override
  String get obligationMonthlyAmount => 'المبلغ';

  @override
  String obligationNextDue(String date) {
    return 'الاستحقاق القادم $date';
  }

  @override
  String get obligationSkip => 'تخطي هذه الدورة';

  @override
  String get obligationUndoPayment => 'إلغاء الدفع';

  @override
  String get obligationsEmptyBody =>
      'أضف الإيجار أو الفواتير أو الاشتراكات ليتابعها التطبيق تلقائيًا.';

  @override
  String get obligationsEmptyTitle => 'لا توجد التزامات قادمة.';

  @override
  String get obligationsSubtitle => 'كل ما يجب دفعه بشكل متكرر';

  @override
  String get obligationsTitle => 'الالتزامات';

  @override
  String get onboardingBack => 'السابق';

  @override
  String get onboardingCurrencyBody =>
      'ستُستخدم في السجلات الجديدة. كل سجل يمكن أن يكون بعملة مختلفة.';

  @override
  String get onboardingCurrencyTitle => 'عملتك الافتراضية';

  @override
  String get onboardingEnableNotifications => 'تفعيل التنبيهات';

  @override
  String get onboardingLanguageBody => 'يمكنك تغييرها لاحقًا من الإعدادات.';

  @override
  String get onboardingLanguageTitle => 'اختر لغتك';

  @override
  String get onboardingMaybeLater => 'لاحقًا';

  @override
  String get onboardingNext => 'التالي';

  @override
  String get onboardingNotificationsBody =>
      'نحتاج إذنك لإرسال تنبيهات الاستحقاق. الإشعارات محلية ولا تغادر جهازك.';

  @override
  String get onboardingNotificationsDenied =>
      'لم يتم منح الإذن. يمكنك تفعيله من الإعدادات.';

  @override
  String get onboardingNotificationsTitle => 'التذكيرات';

  @override
  String get onboardingReadyTitle => 'كل شيء جاهز.';

  @override
  String get onboardingSkip => 'تخطي';

  @override
  String get onboardingSlide1Body =>
      'سجّل ما عليك وما لك، واعرف مركزك المالي فورًا عند فتح التطبيق.';

  @override
  String get onboardingSlide1Title => 'ذمّتك المالية، منظمة في مكان واحد.';

  @override
  String get onboardingSlide2Body =>
      'ديون، دفعات جزئية، والتزامات متكررة — ويُحسب المتبقي تلقائيًا.';

  @override
  String get onboardingSlide2Title => 'سجّل ما عليك وما لك.';

  @override
  String get onboardingSlide3Body =>
      'تذكيرات محلية تعمل بدون إنترنت، وملخص لذمتك في نهاية كل شهر.';

  @override
  String get onboardingSlide3Title => 'لا تنسَ أي موعد.';

  @override
  String get onboardingStart => 'ابدأ الآن';

  @override
  String get owedToMeEmptyBody => 'سجّل ما لك عند الآخرين لتتابعه.';

  @override
  String get owedToMeEmptyTitle => 'لا توجد أموال مستحقة لك.';

  @override
  String get owedToMeSubtitle => 'الأموال المستحقة لي';

  @override
  String get owedToMeTitle => 'لي';

  @override
  String get paymentAmount => 'المبلغ';

  @override
  String get paymentDate => 'التاريخ';

  @override
  String get paymentDeleteBody => 'سيعود الرصيد إلى ما كان عليه قبل تسجيلها.';

  @override
  String get paymentDeleteTitle => 'حذف الدفعة؟';

  @override
  String get paymentDeleted => 'تم حذف الدفعة';

  @override
  String get paymentEditTitle => 'تعديل الدفعة';

  @override
  String paymentExceedsRemaining(String amount) {
    return 'المبلغ أكبر من المتبقي ($amount). سيُسدَّد الدين بالكامل.';
  }

  @override
  String get paymentNote => 'ملاحظة';

  @override
  String get paymentPayFull => 'سداد كامل المتبقي';

  @override
  String paymentRemainingAfter(String amount) {
    return 'المتبقي بعد الدفعة: $amount';
  }

  @override
  String get paymentSave => 'حفظ الدفعة';

  @override
  String get paymentSaved => 'تم تسجيل الدفعة';

  @override
  String get paymentTitle => 'تسجيل دفعة';

  @override
  String get paymentWillSettle => 'هذه الدفعة ستُغلق الدين بالكامل.';

  @override
  String get peopleEmptyBody => 'أضف شخصًا لتربط به الديون وتتابع الرصيد.';

  @override
  String get peopleEmptyTitle => 'لا يوجد أشخاص بعد.';

  @override
  String get peopleTitle => 'الأشخاص';

  @override
  String get periodAny => 'أي وقت';

  @override
  String get periodCustom => 'مخصص';

  @override
  String periodFrom(String date) {
    return 'من $date';
  }

  @override
  String get periodFromLabel => 'من تاريخ';

  @override
  String get periodThisMonth => 'هذا الشهر';

  @override
  String get periodThisWeek => 'هذا الأسبوع';

  @override
  String periodTo(String date) {
    return 'إلى $date';
  }

  @override
  String get periodToLabel => 'إلى تاريخ';

  @override
  String get periodToday => 'اليوم';

  @override
  String get personAddDebt => 'إضافة دين لهذا الشخص';

  @override
  String get personArchived => 'شخص مؤرشف';

  @override
  String get personAvatarColor => 'لون الصورة الرمزية';

  @override
  String get personBalance => 'الرصيد';

  @override
  String personDebtCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دينًا',
      few: '$count ديون',
      two: 'دينان',
      one: 'دين واحد',
      zero: 'لا توجد ديون',
    );
    return '$_temp0';
  }

  @override
  String get personDebtsSection => 'الديون';

  @override
  String get personDeleteBody =>
      'ستبقى الديون محفوظة لكن بدون ارتباط بهذا الشخص.';

  @override
  String get personDeleteTitle => 'حذف الشخص؟';

  @override
  String get personDeleted => 'تم حذف الشخص';

  @override
  String get personFormEdit => 'تعديل الشخص';

  @override
  String get personNameLabel => 'اسم الشخص';

  @override
  String get personNew => 'شخص جديد';

  @override
  String get personNoDebts => 'لا توجد ديون مرتبطة بهذا الشخص.';

  @override
  String get personPhoneLabel => 'رقم الهاتف';

  @override
  String get progressLabel => 'نسبة السداد';

  @override
  String get recordDeleted => 'تم الحذف';

  @override
  String get recordSaved => 'تم الحفظ';

  @override
  String recordsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count سجلًا',
      few: '$count سجلات',
      two: 'سجلان',
      one: 'سجل واحد',
      zero: 'لا توجد سجلات',
    );
    return '$_temp0';
  }

  @override
  String get recurrenceCustom => 'مخصص';

  @override
  String recurrenceEveryN(int count, String unit) {
    return 'كل $count $unit';
  }

  @override
  String get recurrenceMonthly => 'شهري';

  @override
  String get recurrenceNone => 'لا يتكرر';

  @override
  String get recurrenceQuarterly => 'كل 3 أشهر';

  @override
  String get recurrenceWeekly => 'أسبوعي';

  @override
  String get recurrenceYearly => 'سنوي';

  @override
  String get reminderCompletedMessage => 'تم إنجاز التذكير';

  @override
  String get reminderCreated => 'تم إنشاء التذكير';

  @override
  String get reminderFormEdit => 'تعديل التذكير';

  @override
  String get reminderMarkDone => 'تم';

  @override
  String get reminderNew => 'تذكير جديد';

  @override
  String get reminderReopen => 'إعادة فتح';

  @override
  String get reminderTitleHint => 'مثال: تجديد التأمين';

  @override
  String get reminderTitleLabel => 'العنوان';

  @override
  String get remindersCompleted => 'مكتملة';

  @override
  String get remindersEmptyBody => 'أنشئ تذكيرًا لأي موعد لا تريد نسيانه.';

  @override
  String get remindersEmptyTitle => 'لا توجد تذكيرات.';

  @override
  String get remindersLater => 'لاحقًا';

  @override
  String get remindersOverdue => 'متأخر';

  @override
  String get remindersSubtitle => 'كل ما لا يجب نسيانه';

  @override
  String get remindersThisWeek => 'هذا الأسبوع';

  @override
  String get remindersTitle => 'التذكيرات';

  @override
  String get remindersToday => 'اليوم';

  @override
  String get remindersTomorrow => 'غدًا';

  @override
  String get reportAccountSummary => 'ملخص الحساب';

  @override
  String get reportActiveDebts => 'ديون نشطة';

  @override
  String get reportChartPaidVsNew => 'المدفوع مقابل الديون الجديدة';

  @override
  String get reportClosedDebts => 'ديون مغلقة';

  @override
  String get reportColumnAmount => 'المبلغ';

  @override
  String get reportColumnBalance => 'الرصيد';

  @override
  String get reportColumnDate => 'التاريخ';

  @override
  String get reportColumnDebt => 'الدين';

  @override
  String get reportColumnDirection => 'النوع';

  @override
  String get reportColumnDue => 'الاستحقاق';

  @override
  String get reportColumnOperation => 'العملية';

  @override
  String get reportColumnPaid => 'المدفوع';

  @override
  String get reportColumnRemaining => 'المتبقي';

  @override
  String get reportColumnTotal => 'الإجمالي';

  @override
  String get reportCurrentPosition => 'المركز الحالي';

  @override
  String get reportDebtsBreakdown => 'تفصيل الديون';

  @override
  String get reportDeclaration =>
      'هذا المستند صادر من تطبيق ذِمّة بناءً على السجلات التي أدخلها صاحبه، ويُعرض للمراجعة والتذكير فقط.';

  @override
  String get reportDocumentId => 'معرّف المستند';

  @override
  String get reportDocumentNumber => 'رقم المستند';

  @override
  String get reportEmptyBody => 'جرّب اختيار شهر آخر، أو أضف عملية جديدة.';

  @override
  String get reportEmptyTitle => 'لا توجد بيانات لهذا الشهر.';

  @override
  String get reportExportPdf => 'تصدير PDF';

  @override
  String get reportFutureMonth => 'هذا الشهر لم يبدأ بعد.';

  @override
  String get reportGeneratedBy => 'تم إنشاء هذا المستند بواسطة تطبيق ذِمّة';

  @override
  String get reportInsightAllClear => 'لا توجد متأخرات، وكل شيء تحت السيطرة.';

  @override
  String reportInsightClosed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم إغلاق $count دينًا هذا الشهر.',
      few: 'تم إغلاق $count ديون هذا الشهر.',
      two: 'تم إغلاق ديان هذا الشهر.',
      one: 'تم إغلاق دين واحد هذا الشهر.',
      zero: 'لم تُغلق أي ديون هذا الشهر.',
    );
    return '$_temp0';
  }

  @override
  String reportInsightOverdue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count دينًا متأخرًا يحتاج متابعة.',
      few: '$count ديون متأخرة تحتاج متابعة.',
      two: 'ديان متأخران يحتاجان متابعة.',
      one: 'دين واحد متأخر يحتاج متابعة.',
      zero: 'لا ديون متأخرة.',
    );
    return '$_temp0';
  }

  @override
  String get reportInsightQuiet => 'لم تُسجَّل عمليات هذا الشهر بعد.';

  @override
  String reportInsightUpcoming(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'لديك $count التزامًا يستحق خلال الأيام القادمة.',
      few: 'لديك $count التزامات تستحق خلال الأيام القادمة.',
      two: 'لديك التزامان يستحقان خلال الأيام القادمة.',
      one: 'لديك التزام واحد يستحق خلال الأيام القادمة.',
      zero: 'لا التزامات مستحقة خلال الأيام القادمة.',
    );
    return '$_temp0';
  }

  @override
  String get reportIssuedOn => 'تاريخ الإصدار';

  @override
  String get reportMonthlyTitle => 'التقرير الشهري';

  @override
  String get reportNeedsAttention => 'يحتاج انتباهك';

  @override
  String get reportNeedsAttentionEmpty => 'لا شيء متأخر ولا مستحق اليوم.';

  @override
  String get reportNewDebts => 'ديون جديدة';

  @override
  String get reportObligations => 'إجمالي الالتزامات';

  @override
  String get reportOpenPdf => 'فتح الملف';

  @override
  String get reportOptionBreakdown => 'تفصيل كل دين';

  @override
  String get reportOptionNotes => 'الملاحظات';

  @override
  String get reportOptionPayments => 'تفاصيل الدفعات';

  @override
  String get reportOptionPhone => 'رقم الهاتف';

  @override
  String get reportOptionsTitle => 'خيارات الكشف';

  @override
  String get reportOverdue => 'المتأخرات';

  @override
  String reportPageOf(int page, int total) {
    return 'صفحة $page من $total';
  }

  @override
  String get reportPaidOut => 'ما تم دفعه';

  @override
  String get reportPaymentHistory => 'سجل الدفعات';

  @override
  String get reportPeopleCount => 'عدد الأشخاص';

  @override
  String get reportPickMonth => 'اختر الشهر';

  @override
  String get reportReceived => 'ما تم استلامه';

  @override
  String get reportSavePdf => 'طباعة أو حفظ';

  @override
  String get reportSettled => 'إجمالي ما تم سداده';

  @override
  String get reportSharePdf => 'مشاركة PDF';

  @override
  String get reportShareStatement => 'مشاركة كشف';

  @override
  String get reportStatementFor => 'كشف حساب';

  @override
  String get reportStatementReady => 'تم إنشاء كشف الحساب';

  @override
  String get reportStatementReadyBody => 'يمكنك مراجعته قبل الإرسال.';

  @override
  String get reportStatementTitle => 'كشف حساب';

  @override
  String reportTrend(int months) {
    return 'آخر $months أشهر';
  }

  @override
  String get reportTrendNewDebt => 'ديون جديدة';

  @override
  String get reportTrendSettled => 'المدفوع';

  @override
  String get reportsSubtitle => 'ملخص شهري بسيط وواضح';

  @override
  String get reportsTitle => 'التقارير';

  @override
  String get requiredMark => 'مطلوب';

  @override
  String get saveChanges => 'حفظ التعديلات';

  @override
  String get saveDebt => 'حفظ الدين';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get searchAction => 'بحث';

  @override
  String get searchEmptyBody => 'جرّب كلمة أخرى أو أزل الفلاتر.';

  @override
  String get searchEmptyTitle => 'لا توجد نتائج مطابقة.';

  @override
  String get searchHint => 'ابحث في الأسماء والالتزامات والملاحظات';

  @override
  String get searchRecent => 'آخر ما بحثت عنه';

  @override
  String get searchTitle => 'البحث';

  @override
  String get seeAll => 'الكل';

  @override
  String get settingsAbout => 'حول التطبيق';

  @override
  String get settingsAboutBody =>
      'ذِمّة تطبيق شخصي لإدارة ما لك وما عليك. يعمل بالكامل بدون إنترنت، وبياناتك محفوظة على جهازك فقط.';

  @override
  String get settingsAppLock => 'قفل التطبيق';

  @override
  String get settingsAppLockBody => 'اطلب رمزًا عند فتح التطبيق';

  @override
  String get settingsAppearance => 'المظهر';

  @override
  String get settingsBiometric => 'فتح بالبصمة';

  @override
  String get settingsBiometricBody => 'استخدم بصمة الإصبع أو الوجه';

  @override
  String get settingsChangePin => 'تغيير الرمز';

  @override
  String get settingsClearData => 'حذف جميع البيانات';

  @override
  String get settingsCurrenciesInUse => 'العملات المستخدمة';

  @override
  String get settingsCurrency => 'العملة الافتراضية';

  @override
  String get settingsDangerZone => 'منطقة الخطر';

  @override
  String get settingsData => 'البيانات';

  @override
  String get settingsDueSoonWindow => 'نافذة «قريب الاستحقاق»';

  @override
  String get settingsExport => 'تصدير البيانات';

  @override
  String get settingsExportBody => 'احتفظ بنسخة من بياناتك';

  @override
  String get settingsImport => 'استيراد البيانات';

  @override
  String get settingsLanguage => 'اللغة';

  @override
  String get settingsLicenses => 'التراخيص';

  @override
  String get settingsMonthEnd => 'ملخص نهاية الشهر';

  @override
  String get settingsMonthEndBody => 'ملخص تلقائي لذمتك في نهاية كل شهر';

  @override
  String get settingsMonthEndDay => 'يوم الإشعار';

  @override
  String get settingsMonthEndTime => 'وقت الإشعار';

  @override
  String get settingsNotificationTime => 'وقت الإشعار';

  @override
  String get settingsNotifications => 'التنبيهات';

  @override
  String get settingsNumerals => 'شكل الأرقام';

  @override
  String get settingsPrivacyNote => 'بياناتك على جهازك فقط';

  @override
  String get settingsRateApp => 'قيّم التطبيق';

  @override
  String get settingsReminderLead => 'التذكير قبل الاستحقاق';

  @override
  String get settingsRemindersEnabled => 'التذكيرات';

  @override
  String get settingsRemindersEnabledBody => 'إشعارات محلية تعمل بدون إنترنت';

  @override
  String get settingsSecurity => 'الأمان';

  @override
  String get settingsSendFeedback => 'أرسل ملاحظاتك';

  @override
  String get settingsTheme => 'الوضع';

  @override
  String get settingsTitle => 'الإعدادات';

  @override
  String get shareFooter => 'أُرسلت من تطبيق ذِمّة';

  @override
  String get shareLineDirectionIOwe => 'عليّ';

  @override
  String get shareLineDirectionOwedToMe => 'لي';

  @override
  String shareLineDue(String date) {
    return 'موعد الاستحقاق: $date';
  }

  @override
  String shareLinePaid(String amount) {
    return 'المدفوع: $amount';
  }

  @override
  String shareLinePaidOn(String date) {
    return 'تاريخ الدفع: $date';
  }

  @override
  String shareLineRemaining(String amount) {
    return 'المتبقي: $amount';
  }

  @override
  String shareLineTotal(String amount) {
    return 'إجمالي الدين: $amount';
  }

  @override
  String sharePaymentBody(String person, String amount, String date) {
    return '$person · $amount · $date';
  }

  @override
  String get sharePaymentTitle => 'إيصال دفعة';

  @override
  String get shareSubject => 'تفاصيل الدين';

  @override
  String get somethingWentWrong => 'حدث خطأ غير متوقع.';

  @override
  String get sortAmountHighest => 'الأعلى مبلغًا';

  @override
  String get sortAmountLowest => 'الأقل مبلغًا';

  @override
  String get sortDueLatest => 'الأبعد استحقاقًا';

  @override
  String get sortDueSoonest => 'الأقرب استحقاقًا';

  @override
  String get sortNameAscending => 'الاسم (أ–ي)';

  @override
  String get sortOldestAdded => 'الأقدم إضافة';

  @override
  String get sortRecentlyAdded => 'الأحدث إضافة';

  @override
  String get startupFailedBody => 'حدث خطأ أثناء فتح البيانات على جهازك.';

  @override
  String get startupFailedRetry => 'إعادة المحاولة';

  @override
  String get startupFailedSafe => 'لم يُغيَّر أي شيء في سجلاتك.';

  @override
  String get startupFailedTitle => 'تعذّر فتح دفاترك';

  @override
  String get startupFailedTooNew =>
      'هذه البيانات كُتبت بنسخة أحدث من ذِمّة. حدِّث التطبيق ثم أعد المحاولة.';

  @override
  String get statusActive => 'جاري';

  @override
  String get statusArchived => 'مؤرشف';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get statusCompleted => 'مكتمل';

  @override
  String get statusDismissed => 'متجاهَل';

  @override
  String get statusDueSoon => 'قريب الاستحقاق';

  @override
  String get statusDueToday => 'مستحق اليوم';

  @override
  String get statusOverdue => 'متأخر';

  @override
  String get statusPaid => 'مدفوع بالكامل';

  @override
  String get statusPartiallyPaid => 'مدفوع جزئيًا';

  @override
  String get statusSkipped => 'متجاوز';

  @override
  String get statusUnpaid => 'غير مدفوع';

  @override
  String get statusUpcoming => 'قادم';

  @override
  String get swipeToDelete => 'اسحب للحذف';

  @override
  String get themeDark => 'ليلي';

  @override
  String get themeLight => 'نهاري';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get todayLabel => 'اليوم';

  @override
  String get totalLabel => 'الإجمالي';

  @override
  String get unitDay => 'يوم';

  @override
  String get unitMonth => 'شهر';

  @override
  String get unitWeek => 'أسبوع';

  @override
  String get unitYear => 'سنة';

  @override
  String get unknownPerson => 'بدون اسم';

  @override
  String get updateAvailableBody =>
      'يوجد إصدار أحدث من ذِمّة جاهز على Google Play.';

  @override
  String get updateAvailableTitle => 'تحديث جديد متوفر';

  @override
  String get updateDownloadingBody =>
      'يمكنك متابعة عملك في ذِمّة أثناء التنزيل.';

  @override
  String get updateDownloadingTitle => 'جارٍ تنزيل التحديث';

  @override
  String get updateLater => 'لاحقًا';

  @override
  String get updateNow => 'تحديث الآن';

  @override
  String updatePercent(int percent) {
    return '$percent%';
  }

  @override
  String get updateReadyBody =>
      'أُكمل التنزيل. سيتولّى Google Play التثبيت ويعيد تشغيل ذِمّة.';

  @override
  String get updateReadyTitle => 'التحديث جاهز للتثبيت';

  @override
  String get updateRestartAndInstall => 'إعادة التشغيل والتحديث';

  @override
  String get validationAmountTooLarge => 'المبلغ كبير جدًا.';

  @override
  String get validationDayOfMonth => 'اختر يومًا بين 1 و 31.';

  @override
  String get validationDueBeforeIssue => 'تاريخ الاستحقاق قبل تاريخ الدين.';

  @override
  String get validationEndBeforeStart => 'تاريخ الانتهاء قبل تاريخ البداية.';

  @override
  String get validationInvalidAmount => 'أدخل مبلغًا صحيحًا أكبر من صفر.';

  @override
  String get validationNameExists => 'يوجد شخص بهذا الاسم بالفعل.';

  @override
  String get validationNameTooLong => 'الاسم طويل جدًا.';

  @override
  String get validationNameTooShort => 'الاسم قصير جدًا.';

  @override
  String get validationNegative => 'لا يمكن إدخال قيمة سالبة.';

  @override
  String get validationNoteTooLong => 'الملاحظات طويلة جدًا.';

  @override
  String validationOverPayment(String amount) {
    return 'المبلغ أكبر من المتبقي ($amount).';
  }

  @override
  String get validationPhoneInvalid => 'أدخل رقم هاتف صحيحًا.';

  @override
  String get validationRequired => 'هذا الحقل مطلوب.';

  @override
  String get validationTitleTooLong => 'الوصف طويل جدًا.';
}
