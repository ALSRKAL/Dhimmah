import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// No description provided for @actionArchive.
  ///
  /// In ar, this message translates to:
  /// **'أرشفة'**
  String get actionArchive;

  /// No description provided for @actionCancel.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء'**
  String get actionCancel;

  /// No description provided for @actionClear.
  ///
  /// In ar, this message translates to:
  /// **'مسح'**
  String get actionClear;

  /// No description provided for @actionClose.
  ///
  /// In ar, this message translates to:
  /// **'إغلاق'**
  String get actionClose;

  /// No description provided for @actionConfirm.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد'**
  String get actionConfirm;

  /// No description provided for @actionCopy.
  ///
  /// In ar, this message translates to:
  /// **'نسخ'**
  String get actionCopy;

  /// No description provided for @actionDelete.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get actionDelete;

  /// No description provided for @actionDisable.
  ///
  /// In ar, this message translates to:
  /// **'تعطيل'**
  String get actionDisable;

  /// No description provided for @actionDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get actionDone;

  /// No description provided for @actionEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل'**
  String get actionEdit;

  /// No description provided for @actionEnable.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل'**
  String get actionEnable;

  /// No description provided for @actionOk.
  ///
  /// In ar, this message translates to:
  /// **'حسنًا'**
  String get actionOk;

  /// No description provided for @actionRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get actionRetry;

  /// No description provided for @actionSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ'**
  String get actionSave;

  /// No description provided for @actionSelect.
  ///
  /// In ar, this message translates to:
  /// **'اختيار'**
  String get actionSelect;

  /// No description provided for @actionShare.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get actionShare;

  /// No description provided for @actionUnarchive.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get actionUnarchive;

  /// No description provided for @actionUndo.
  ///
  /// In ar, this message translates to:
  /// **'تراجع'**
  String get actionUndo;

  /// No description provided for @activityCleared.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف كل البيانات'**
  String get activityCleared;

  /// No description provided for @activityDebtArchived.
  ///
  /// In ar, this message translates to:
  /// **'تمت أرشفة دين'**
  String get activityDebtArchived;

  /// No description provided for @activityDebtClosed.
  ///
  /// In ar, this message translates to:
  /// **'تم إغلاق دين'**
  String get activityDebtClosed;

  /// No description provided for @activityDebtCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء دين'**
  String get activityDebtCreated;

  /// No description provided for @activityDebtDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف دين'**
  String get activityDebtDeleted;

  /// No description provided for @activityDebtReopened.
  ///
  /// In ar, this message translates to:
  /// **'تمت إعادة فتح دين'**
  String get activityDebtReopened;

  /// No description provided for @activityDebtUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل دين'**
  String get activityDebtUpdated;

  /// No description provided for @activityExported.
  ///
  /// In ar, this message translates to:
  /// **'تم تصدير بيانات'**
  String get activityExported;

  /// No description provided for @activityImported.
  ///
  /// In ar, this message translates to:
  /// **'تم استيراد بيانات'**
  String get activityImported;

  /// No description provided for @activityMonthSummary.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الملخص الشهري'**
  String get activityMonthSummary;

  /// No description provided for @activityObligationCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء التزام'**
  String get activityObligationCreated;

  /// No description provided for @activityObligationPaid.
  ///
  /// In ar, this message translates to:
  /// **'تم دفع التزام'**
  String get activityObligationPaid;

  /// No description provided for @activityObligationSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم تخطي دورة'**
  String get activityObligationSkipped;

  /// No description provided for @activityPaymentDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف دفعة'**
  String get activityPaymentDeleted;

  /// No description provided for @activityPaymentRecorded.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل دفعة'**
  String get activityPaymentRecorded;

  /// No description provided for @activityPersonCreated.
  ///
  /// In ar, this message translates to:
  /// **'تمت إضافة شخص'**
  String get activityPersonCreated;

  /// No description provided for @activityPersonDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف شخص'**
  String get activityPersonDeleted;

  /// No description provided for @activityPersonUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تعديل بيانات شخص'**
  String get activityPersonUpdated;

  /// No description provided for @activityReminderCompleted.
  ///
  /// In ar, this message translates to:
  /// **'تم إنجاز تذكير'**
  String get activityReminderCompleted;

  /// No description provided for @activityReminderCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء تذكير'**
  String get activityReminderCreated;

  /// No description provided for @addDebtAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين'**
  String get addDebtAction;

  /// No description provided for @addDebtIOwe.
  ///
  /// In ar, this message translates to:
  /// **'دين عليّ'**
  String get addDebtIOwe;

  /// No description provided for @addDebtIOweHint.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ يجب عليّ دفعه'**
  String get addDebtIOweHint;

  /// No description provided for @addDebtOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'دين لي'**
  String get addDebtOwedToMe;

  /// No description provided for @addDebtOwedToMeHint.
  ///
  /// In ar, this message translates to:
  /// **'مبلغ مستحق لي'**
  String get addDebtOwedToMeHint;

  /// No description provided for @addObligation.
  ///
  /// In ar, this message translates to:
  /// **'التزام'**
  String get addObligation;

  /// No description provided for @addObligationHint.
  ///
  /// In ar, this message translates to:
  /// **'إيجار، فاتورة، اشتراك…'**
  String get addObligationHint;

  /// No description provided for @addPersonAction.
  ///
  /// In ar, this message translates to:
  /// **'إضافة شخص جديد'**
  String get addPersonAction;

  /// No description provided for @addReminder.
  ///
  /// In ar, this message translates to:
  /// **'تذكير'**
  String get addReminder;

  /// No description provided for @addReminderHint.
  ///
  /// In ar, this message translates to:
  /// **'موعد لا يجب نسيانه'**
  String get addReminderHint;

  /// No description provided for @addTitle.
  ///
  /// In ar, this message translates to:
  /// **'إضافة'**
  String get addTitle;

  /// No description provided for @allRecords.
  ///
  /// In ar, this message translates to:
  /// **'كل السجلات'**
  String get allRecords;

  /// No description provided for @appName.
  ///
  /// In ar, this message translates to:
  /// **'ذِمّة'**
  String get appName;

  /// No description provided for @appTagline.
  ///
  /// In ar, this message translates to:
  /// **'اعرف ما لك وما عليك'**
  String get appTagline;

  /// No description provided for @appTaglineShort.
  ///
  /// In ar, this message translates to:
  /// **'ذمّتك المالية، منظمة في مكان واحد.'**
  String get appTaglineShort;

  /// No description provided for @appVersion.
  ///
  /// In ar, this message translates to:
  /// **'الإصدار {version} ({build})'**
  String appVersion(String version, String build);

  /// No description provided for @attentionDueSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريب الاستحقاق'**
  String get attentionDueSoon;

  /// No description provided for @attentionDueToday.
  ///
  /// In ar, this message translates to:
  /// **'يستحق اليوم'**
  String get attentionDueToday;

  /// No description provided for @attentionOverdue.
  ///
  /// In ar, this message translates to:
  /// **'متأخر'**
  String get attentionOverdue;

  /// No description provided for @biometricNotEnrolled.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل أي بصمة على هذا الجهاز بعد.'**
  String get biometricNotEnrolled;

  /// No description provided for @biometricUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'البصمة غير متاحة على هذا الجهاز.'**
  String get biometricUnavailable;

  /// No description provided for @brandPromise.
  ///
  /// In ar, this message translates to:
  /// **'هذا المكان يحفظ كل شيء عليّ ولي، ويذكّرني بما يجب أن أدفعه وما يجب أن أستلمه.'**
  String get brandPromise;

  /// No description provided for @categoryHousing.
  ///
  /// In ar, this message translates to:
  /// **'سكن'**
  String get categoryHousing;

  /// No description provided for @categoryInstallment.
  ///
  /// In ar, this message translates to:
  /// **'أقساط'**
  String get categoryInstallment;

  /// No description provided for @categoryInsurance.
  ///
  /// In ar, this message translates to:
  /// **'تأمين'**
  String get categoryInsurance;

  /// No description provided for @categoryLoan.
  ///
  /// In ar, this message translates to:
  /// **'قرض'**
  String get categoryLoan;

  /// No description provided for @categoryOther.
  ///
  /// In ar, this message translates to:
  /// **'أخرى'**
  String get categoryOther;

  /// No description provided for @categorySalary.
  ///
  /// In ar, this message translates to:
  /// **'رواتب'**
  String get categorySalary;

  /// No description provided for @categorySubscription.
  ///
  /// In ar, this message translates to:
  /// **'اشتراكات'**
  String get categorySubscription;

  /// No description provided for @categoryTax.
  ///
  /// In ar, this message translates to:
  /// **'ضرائب'**
  String get categoryTax;

  /// No description provided for @categoryTelecom.
  ///
  /// In ar, this message translates to:
  /// **'اتصالات'**
  String get categoryTelecom;

  /// No description provided for @categoryUtilities.
  ///
  /// In ar, this message translates to:
  /// **'فواتير'**
  String get categoryUtilities;

  /// No description provided for @chooseOption.
  ///
  /// In ar, this message translates to:
  /// **'اختر'**
  String get chooseOption;

  /// No description provided for @clearDataBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف كل الأشخاص والديون والدفعات والالتزامات والتذكيرات من هذا الجهاز. تُحفظ نسخة أمان أولًا وتبقى النسخ الاحتياطية على الجهاز، فيمكن استعادة الدفتر من «النسخ الاحتياطي والاستعادة».'**
  String get clearDataBody;

  /// No description provided for @clearDataTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف كل البيانات؟'**
  String get clearDataTitle;

  /// No description provided for @collapse.
  ///
  /// In ar, this message translates to:
  /// **'طي'**
  String get collapse;

  /// No description provided for @copiedToClipboard.
  ///
  /// In ar, this message translates to:
  /// **'تم النسخ'**
  String get copiedToClipboard;

  /// No description provided for @currencySymbolWithCode.
  ///
  /// In ar, this message translates to:
  /// **'{code} {symbol}'**
  String currencySymbolWithCode(String code, String symbol);

  /// No description provided for @dashboardAgainstYou.
  ///
  /// In ar, this message translates to:
  /// **'عليك'**
  String get dashboardAgainstYou;

  /// No description provided for @dashboardBalanced.
  ///
  /// In ar, this message translates to:
  /// **'متوازن'**
  String get dashboardBalanced;

  /// No description provided for @dashboardDueSoon.
  ///
  /// In ar, this message translates to:
  /// **'المستحق قريبًا'**
  String get dashboardDueSoon;

  /// No description provided for @dashboardDueSoonHint.
  ///
  /// In ar, this message translates to:
  /// **'خلال {days} أيام'**
  String dashboardDueSoonHint(int days);

  /// No description provided for @dashboardEmptyAddDebt.
  ///
  /// In ar, this message translates to:
  /// **'إضافة أول دين'**
  String get dashboardEmptyAddDebt;

  /// No description provided for @dashboardEmptyAddObligation.
  ///
  /// In ar, this message translates to:
  /// **'إضافة التزام'**
  String get dashboardEmptyAddObligation;

  /// No description provided for @dashboardEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ بإضافة أول دين أو التزام، وسيتولى التطبيق التذكير والتنظيم.'**
  String get dashboardEmptyBody;

  /// No description provided for @dashboardEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'ممتاز، لا توجد ديون مسجّلة حاليًا.'**
  String get dashboardEmptyTitle;

  /// No description provided for @dashboardGreeting.
  ///
  /// In ar, this message translates to:
  /// **'مرحبًا'**
  String get dashboardGreeting;

  /// No description provided for @dashboardIOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get dashboardIOwe;

  /// No description provided for @dashboardIOweHint.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي ما يجب عليّ دفعه'**
  String get dashboardIOweHint;

  /// No description provided for @dashboardInYourFavour.
  ///
  /// In ar, this message translates to:
  /// **'لمصلحتك'**
  String get dashboardInYourFavour;

  /// No description provided for @dashboardNetPosition.
  ///
  /// In ar, this message translates to:
  /// **'الصافي'**
  String get dashboardNetPosition;

  /// No description provided for @dashboardObligations.
  ///
  /// In ar, this message translates to:
  /// **'التزامات قادمة'**
  String get dashboardObligations;

  /// No description provided for @dashboardOtherCurrencies.
  ///
  /// In ar, this message translates to:
  /// **'أرصدة بعملات أخرى'**
  String get dashboardOtherCurrencies;

  /// No description provided for @dashboardOverdue.
  ///
  /// In ar, this message translates to:
  /// **'المتأخر'**
  String get dashboardOverdue;

  /// No description provided for @dashboardOverdueHint.
  ///
  /// In ar, this message translates to:
  /// **'تجاوز موعد الاستحقاق'**
  String get dashboardOverdueHint;

  /// No description provided for @dashboardOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get dashboardOwedToMe;

  /// No description provided for @dashboardOwedToMeHint.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي ما هو مستحق لي'**
  String get dashboardOwedToMeHint;

  /// No description provided for @dashboardRecentActivity.
  ///
  /// In ar, this message translates to:
  /// **'آخر العمليات'**
  String get dashboardRecentActivity;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'هذه نظرة سريعة على ذمتك المالية'**
  String get dashboardSubtitle;

  /// No description provided for @dashboardUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاقات القادمة'**
  String get dashboardUpcoming;

  /// No description provided for @dashboardViewAll.
  ///
  /// In ar, this message translates to:
  /// **'عرض الكل'**
  String get dashboardViewAll;

  /// No description provided for @dateDayCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{يوم واحد} =2{يومان} few{{count} أيام} other{{count} يومًا}}'**
  String dateDayCount(int count);

  /// No description provided for @dateDaysAgo.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{منذ يوم واحد} =2{منذ يومين} few{منذ {days} أيام} other{منذ {days} يومًا}}'**
  String dateDaysAgo(int days);

  /// No description provided for @dateDueOn.
  ///
  /// In ar, this message translates to:
  /// **'يستحق في {date}'**
  String dateDueOn(String date);

  /// No description provided for @dateInDays.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{خلال يوم واحد} =2{خلال يومين} few{خلال {days} أيام} other{خلال {days} يومًا}}'**
  String dateInDays(int days);

  /// No description provided for @dateNoDueDate.
  ///
  /// In ar, this message translates to:
  /// **'بدون استحقاق'**
  String get dateNoDueDate;

  /// No description provided for @dateOverdueBy.
  ///
  /// In ar, this message translates to:
  /// **'{days, plural, =1{متأخر يومًا واحدًا} =2{متأخر يومين} few{متأخر {days} أيام} other{متأخر {days} يومًا}}'**
  String dateOverdueBy(int days);

  /// No description provided for @dateToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get dateToday;

  /// No description provided for @dateTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get dateTomorrow;

  /// No description provided for @dateYesterday.
  ///
  /// In ar, this message translates to:
  /// **'أمس'**
  String get dateYesterday;

  /// No description provided for @debtArchived.
  ///
  /// In ar, this message translates to:
  /// **'تمت الأرشفة'**
  String get debtArchived;

  /// No description provided for @debtClosed.
  ///
  /// In ar, this message translates to:
  /// **'تم إغلاق الدين'**
  String get debtClosed;

  /// No description provided for @debtCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء الدين'**
  String get debtCreated;

  /// No description provided for @debtFormEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدين'**
  String get debtFormEdit;

  /// No description provided for @debtFormNewIOwe.
  ///
  /// In ar, this message translates to:
  /// **'دين عليّ'**
  String get debtFormNewIOwe;

  /// No description provided for @debtFormNewOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'دين لي'**
  String get debtFormNewOwedToMe;

  /// No description provided for @debtFormSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'سجّل التفاصيل في ثوانٍ'**
  String get debtFormSubtitle;

  /// No description provided for @debtRestored.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة'**
  String get debtRestored;

  /// No description provided for @debtSettled.
  ///
  /// In ar, this message translates to:
  /// **'تم سداد الدين بالكامل'**
  String get debtSettled;

  /// No description provided for @debtUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الدين'**
  String get debtUpdated;

  /// No description provided for @deleteConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن التراجع عن هذا الإجراء.'**
  String get deleteConfirmBody;

  /// No description provided for @deleteUndoableBody.
  ///
  /// In ar, this message translates to:
  /// **'سيُحذف الدين، ويمكنك التراجع خلال ثوانٍ.'**
  String get deleteUndoableBody;

  /// No description provided for @recordGone.
  ///
  /// In ar, this message translates to:
  /// **'هذا السجل لم يعد موجودًا.'**
  String get recordGone;

  /// No description provided for @deleteConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد الحذف'**
  String get deleteConfirmTitle;

  /// No description provided for @detailClosedOn.
  ///
  /// In ar, this message translates to:
  /// **'أُغلق في {date}'**
  String detailClosedOn(String date);

  /// No description provided for @detailDueOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستحقاق'**
  String get detailDueOn;

  /// No description provided for @detailIssuedOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدين'**
  String get detailIssuedOn;

  /// No description provided for @detailNoPayments.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل أي دفعة بعد.'**
  String get detailNoPayments;

  /// No description provided for @detailOverpaid.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ المدفوع تجاوز أصل الدين بمقدار {amount}.'**
  String detailOverpaid(String amount);

  /// No description provided for @detailPaid.
  ///
  /// In ar, this message translates to:
  /// **'تم دفع'**
  String get detailPaid;

  /// No description provided for @detailProgress.
  ///
  /// In ar, this message translates to:
  /// **'{percent}% مدفوع'**
  String detailProgress(int percent);

  /// No description provided for @detailRecordPayment.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفعة'**
  String get detailRecordPayment;

  /// No description provided for @detailRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get detailRemaining;

  /// No description provided for @detailTimeline.
  ///
  /// In ar, this message translates to:
  /// **'سجل العمليات'**
  String get detailTimeline;

  /// No description provided for @detailTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدين'**
  String get detailTotal;

  /// No description provided for @expand.
  ///
  /// In ar, this message translates to:
  /// **'توسيع'**
  String get expand;

  /// No description provided for @exportCsv.
  ///
  /// In ar, this message translates to:
  /// **'CSV — جدول البيانات'**
  String get exportCsv;

  /// No description provided for @exportCsvBody.
  ///
  /// In ar, this message translates to:
  /// **'افتحه في Excel أو Sheets'**
  String get exportCsvBody;

  /// No description provided for @exportDone.
  ///
  /// In ar, this message translates to:
  /// **'تم التصدير'**
  String get exportDone;

  /// No description provided for @exportFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر التصدير. حاول مرة أخرى.'**
  String get exportFailed;

  /// No description provided for @exportJson.
  ///
  /// In ar, this message translates to:
  /// **'JSON — نسخة كاملة'**
  String get exportJson;

  /// No description provided for @exportJsonBody.
  ///
  /// In ar, this message translates to:
  /// **'ملف يحتوي كل سجلاتك'**
  String get exportJsonBody;

  /// No description provided for @exportPdf.
  ///
  /// In ar, this message translates to:
  /// **'PDF — تقرير'**
  String get exportPdf;

  /// No description provided for @exportPdfBody.
  ///
  /// In ar, this message translates to:
  /// **'تقرير مرتب للمشاركة أو الطباعة'**
  String get exportPdfBody;

  /// No description provided for @fieldAdvancedHint.
  ///
  /// In ar, this message translates to:
  /// **'الوصف، التذكير، التاريخ، الملاحظات'**
  String get fieldAdvancedHint;

  /// No description provided for @fieldAdvancedOptions.
  ///
  /// In ar, this message translates to:
  /// **'خيارات إضافية'**
  String get fieldAdvancedOptions;

  /// No description provided for @fieldAdvancedSet.
  ///
  /// In ar, this message translates to:
  /// **'مضبوط'**
  String get fieldAdvancedSet;

  /// No description provided for @fieldAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get fieldAmount;

  /// No description provided for @fieldCategory.
  ///
  /// In ar, this message translates to:
  /// **'التصنيف'**
  String get fieldCategory;

  /// No description provided for @fieldCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة'**
  String get fieldCurrency;

  /// No description provided for @fieldDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدين'**
  String get fieldDate;

  /// No description provided for @fieldDayOfMonth.
  ///
  /// In ar, this message translates to:
  /// **'يوم الاستحقاق في الشهر'**
  String get fieldDayOfMonth;

  /// No description provided for @fieldDirection.
  ///
  /// In ar, this message translates to:
  /// **'نوع العملية'**
  String get fieldDirection;

  /// No description provided for @fieldDueDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستحقاق'**
  String get fieldDueDate;

  /// No description provided for @fieldDueDateNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون تاريخ استحقاق'**
  String get fieldDueDateNone;

  /// No description provided for @fieldEndDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء'**
  String get fieldEndDate;

  /// No description provided for @fieldFrequency.
  ///
  /// In ar, this message translates to:
  /// **'التكرار'**
  String get fieldFrequency;

  /// No description provided for @fieldNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظات'**
  String get fieldNote;

  /// No description provided for @fieldNoteHint.
  ///
  /// In ar, this message translates to:
  /// **'أي تفاصيل إضافية…'**
  String get fieldNoteHint;

  /// No description provided for @fieldObligationName.
  ///
  /// In ar, this message translates to:
  /// **'الاسم'**
  String get fieldObligationName;

  /// No description provided for @fieldObligationNameHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: إيجار المنزل'**
  String get fieldObligationNameHint;

  /// No description provided for @fieldOptional.
  ///
  /// In ar, this message translates to:
  /// **'اختياري'**
  String get fieldOptional;

  /// No description provided for @fieldPerson.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشخص'**
  String get fieldPerson;

  /// No description provided for @fieldPersonHint.
  ///
  /// In ar, this message translates to:
  /// **'اختر شخصًا أو أضف جديدًا'**
  String get fieldPersonHint;

  /// No description provided for @fieldPersonNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون شخص'**
  String get fieldPersonNone;

  /// No description provided for @fieldRecurrence.
  ///
  /// In ar, this message translates to:
  /// **'تكرار الدين'**
  String get fieldRecurrence;

  /// No description provided for @fieldReminder.
  ///
  /// In ar, this message translates to:
  /// **'التذكير'**
  String get fieldReminder;

  /// No description provided for @fieldStartDate.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ البداية'**
  String get fieldStartDate;

  /// No description provided for @fieldTitle.
  ///
  /// In ar, this message translates to:
  /// **'الوصف'**
  String get fieldTitle;

  /// No description provided for @fieldTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: سلفة، قرض سيارة'**
  String get fieldTitleHint;

  /// No description provided for @filterActive.
  ///
  /// In ar, this message translates to:
  /// **'نشط'**
  String get filterActive;

  /// No description provided for @filterAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get filterAll;

  /// No description provided for @filterApply.
  ///
  /// In ar, this message translates to:
  /// **'تطبيق'**
  String get filterApply;

  /// No description provided for @filterArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get filterArchived;

  /// No description provided for @filterDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون'**
  String get filterDebts;

  /// No description provided for @filterDueSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريب الاستحقاق'**
  String get filterDueSoon;

  /// No description provided for @filterObligations.
  ///
  /// In ar, this message translates to:
  /// **'التزامات'**
  String get filterObligations;

  /// No description provided for @filterPartiallyPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع جزئيًا'**
  String get filterPartiallyPaid;

  /// No description provided for @filterPeriod.
  ///
  /// In ar, this message translates to:
  /// **'الفترة'**
  String get filterPeriod;

  /// No description provided for @filterReset.
  ///
  /// In ar, this message translates to:
  /// **'إعادة تعيين'**
  String get filterReset;

  /// No description provided for @filterSort.
  ///
  /// In ar, this message translates to:
  /// **'الترتيب'**
  String get filterSort;

  /// No description provided for @filterStatus.
  ///
  /// In ar, this message translates to:
  /// **'الحالة'**
  String get filterStatus;

  /// No description provided for @filterTitle.
  ///
  /// In ar, this message translates to:
  /// **'الفلاتر'**
  String get filterTitle;

  /// No description provided for @filterType.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get filterType;

  /// No description provided for @filterUnpaid.
  ///
  /// In ar, this message translates to:
  /// **'غير مدفوع'**
  String get filterUnpaid;

  /// No description provided for @filtersApplied.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بدون فلاتر} =1{فلتر واحد} other{{count} فلاتر}}'**
  String filtersApplied(int count);

  /// No description provided for @importDone.
  ///
  /// In ar, this message translates to:
  /// **'تم استيراد {count} سجلًا'**
  String importDone(int count);

  /// No description provided for @ioweEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'عندما تسجّل دينًا عليك سيظهر هنا مع موعده.'**
  String get ioweEmptyBody;

  /// No description provided for @ioweEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ديون عليك.'**
  String get ioweEmptyTitle;

  /// No description provided for @ioweSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الأموال التي يجب عليّ دفعها'**
  String get ioweSubtitle;

  /// No description provided for @ioweTitle.
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get ioweTitle;

  /// No description provided for @languageArabic.
  ///
  /// In ar, this message translates to:
  /// **'العربية'**
  String get languageArabic;

  /// No description provided for @languageEnglish.
  ///
  /// In ar, this message translates to:
  /// **'الإنجليزية'**
  String get languageEnglish;

  /// No description provided for @leadCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{بدون تذكير} =1{تذكير واحد} =2{تذكيران} few{{count} تذكيرات} other{{count} تذكيرًا}}'**
  String leadCount(int count);

  /// No description provided for @leadNone.
  ///
  /// In ar, this message translates to:
  /// **'بدون تذكير'**
  String get leadNone;

  /// No description provided for @leadOnDueDate.
  ///
  /// In ar, this message translates to:
  /// **'في يوم الاستحقاق'**
  String get leadOnDueDate;

  /// No description provided for @leadOneDayBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل يوم'**
  String get leadOneDayBefore;

  /// No description provided for @leadOneWeekBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل أسبوع'**
  String get leadOneWeekBefore;

  /// No description provided for @leadSummary.
  ///
  /// In ar, this message translates to:
  /// **'التذكير: {lead}'**
  String leadSummary(String lead);

  /// No description provided for @leadThreeDaysBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل 3 أيام'**
  String get leadThreeDaysBefore;

  /// No description provided for @leadTwoDaysBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل يومين'**
  String get leadTwoDaysBefore;

  /// No description provided for @leadTwoWeeksBefore.
  ///
  /// In ar, this message translates to:
  /// **'قبل أسبوعين'**
  String get leadTwoWeeksBefore;

  /// No description provided for @ledgerAllPeople.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get ledgerAllPeople;

  /// No description provided for @ledgerSwitchIOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get ledgerSwitchIOwe;

  /// No description provided for @ledgerSwitchOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get ledgerSwitchOwedToMe;

  /// No description provided for @loading.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ التحميل…'**
  String get loading;

  /// No description provided for @lockAttemptsLeft.
  ///
  /// In ar, this message translates to:
  /// **'المحاولات المتبقية: {count}'**
  String lockAttemptsLeft(int count);

  /// No description provided for @lockBiometricReason.
  ///
  /// In ar, this message translates to:
  /// **'تأكيد هويتك لفتح ذِمّة'**
  String get lockBiometricReason;

  /// No description provided for @lockConfirmPin.
  ///
  /// In ar, this message translates to:
  /// **'أعد إدخال الرمز للتأكيد'**
  String get lockConfirmPin;

  /// No description provided for @lockCreatePin.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ رمزًا مكونًا من {length} أرقام'**
  String lockCreatePin(int length);

  /// No description provided for @lockCurrentPin.
  ///
  /// In ar, this message translates to:
  /// **'الرمز الحالي'**
  String get lockCurrentPin;

  /// No description provided for @lockDisabledForSession.
  ///
  /// In ar, this message translates to:
  /// **'القفل معطّل حتى إغلاق التطبيق.'**
  String get lockDisabledForSession;

  /// No description provided for @lockEnterPin.
  ///
  /// In ar, this message translates to:
  /// **'أدخل الرمز للمتابعة'**
  String get lockEnterPin;

  /// No description provided for @lockNewPin.
  ///
  /// In ar, this message translates to:
  /// **'الرمز الجديد'**
  String get lockNewPin;

  /// No description provided for @lockPinMismatch.
  ///
  /// In ar, this message translates to:
  /// **'الرمزان غير متطابقين.'**
  String get lockPinMismatch;

  /// No description provided for @lockPinUpdated.
  ///
  /// In ar, this message translates to:
  /// **'تم تحديث الرمز'**
  String get lockPinUpdated;

  /// No description provided for @lockTitle.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق'**
  String get lockTitle;

  /// No description provided for @lockTooManyAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات كثيرة. حاول بعد قليل.'**
  String get lockTooManyAttempts;

  /// No description provided for @lockUseBiometric.
  ///
  /// In ar, this message translates to:
  /// **'استخدم البصمة'**
  String get lockUseBiometric;

  /// No description provided for @lockWrongPin.
  ///
  /// In ar, this message translates to:
  /// **'الرمز غير صحيح. حاول مرة أخرى.'**
  String get lockWrongPin;

  /// No description provided for @longPressForOptions.
  ///
  /// In ar, this message translates to:
  /// **'اضغط مطولًا للمزيد'**
  String get longPressForOptions;

  /// No description provided for @monthEndDayNumber.
  ///
  /// In ar, this message translates to:
  /// **'يوم {day}'**
  String monthEndDayNumber(int day);

  /// No description provided for @monthEndLastDay.
  ///
  /// In ar, this message translates to:
  /// **'آخر يوم من الشهر'**
  String get monthEndLastDay;

  /// No description provided for @moreFollowUpSection.
  ///
  /// In ar, this message translates to:
  /// **'المتابعة'**
  String get moreFollowUpSection;

  /// No description provided for @moreTitle.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get moreTitle;

  /// No description provided for @navHome.
  ///
  /// In ar, this message translates to:
  /// **'الرئيسية'**
  String get navHome;

  /// No description provided for @navIOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get navIOwe;

  /// No description provided for @navLedger.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get navLedger;

  /// No description provided for @navMore.
  ///
  /// In ar, this message translates to:
  /// **'المزيد'**
  String get navMore;

  /// No description provided for @navObligations.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get navObligations;

  /// No description provided for @navObligationsShort.
  ///
  /// In ar, this message translates to:
  /// **'التزامات'**
  String get navObligationsShort;

  /// No description provided for @navOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get navOwedToMe;

  /// No description provided for @navPeople.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get navPeople;

  /// No description provided for @navReminders.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get navReminders;

  /// No description provided for @navReports.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get navReports;

  /// No description provided for @navSettings.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get navSettings;

  /// No description provided for @netLabel.
  ///
  /// In ar, this message translates to:
  /// **'الصافي'**
  String get netLabel;

  /// No description provided for @noInternetNeeded.
  ///
  /// In ar, this message translates to:
  /// **'يعمل بدون إنترنت'**
  String get noInternetNeeded;

  /// No description provided for @notifChannelDueBody.
  ///
  /// In ar, this message translates to:
  /// **'دفعة مستحقة اليوم أو متأخرة'**
  String get notifChannelDueBody;

  /// No description provided for @notifChannelDueName.
  ///
  /// In ar, this message translates to:
  /// **'مستحق الآن'**
  String get notifChannelDueName;

  /// No description provided for @notifChannelBackupName.
  ///
  /// In ar, this message translates to:
  /// **'مشكلة في النسخ الاحتياطي'**
  String get notifChannelBackupName;

  /// No description provided for @notifChannelBackupBody.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه عندما يتعذّر على ذِمّة حفظ نسخة من بياناتك'**
  String get notifChannelBackupBody;

  /// No description provided for @backupAlertTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطية تحتاج انتباهك'**
  String get backupAlertTitle;

  /// No description provided for @backupAlertBody.
  ///
  /// In ar, this message translates to:
  /// **'لم يتمكن ذِمّة من حفظ نسخة من تغييراتك. بياناتك محفوظة داخل التطبيق، وسيُعيد المحاولة تلقائيًا.'**
  String get backupAlertBody;

  /// No description provided for @notifChannelSummaryBody.
  ///
  /// In ar, this message translates to:
  /// **'ملخص ذمتك في نهاية كل شهر'**
  String get notifChannelSummaryBody;

  /// No description provided for @notifChannelSummaryName.
  ///
  /// In ar, this message translates to:
  /// **'الملخص الشهري'**
  String get notifChannelSummaryName;

  /// No description provided for @notifChannelUpcomingBody.
  ///
  /// In ar, this message translates to:
  /// **'دفعة تستحق خلال الأيام القادمة'**
  String get notifChannelUpcomingBody;

  /// No description provided for @notifChannelUpcomingName.
  ///
  /// In ar, this message translates to:
  /// **'استحقاقات قادمة'**
  String get notifChannelUpcomingName;

  /// No description provided for @notifDueSoonBody.
  ///
  /// In ar, this message translates to:
  /// **'{name} — {amount} · {when}'**
  String notifDueSoonBody(String name, String amount, String when);

  /// No description provided for @notifDueSoonTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفعة مستحقة قريبًا'**
  String get notifDueSoonTitle;

  /// No description provided for @notifDueTodayBody.
  ///
  /// In ar, this message translates to:
  /// **'{name} — {amount} يستحق اليوم.'**
  String notifDueTodayBody(String name, String amount);

  /// No description provided for @notifDueTodayTitle.
  ///
  /// In ar, this message translates to:
  /// **'موعد سداد اليوم'**
  String get notifDueTodayTitle;

  /// No description provided for @notifMonthEndBody.
  ///
  /// In ar, this message translates to:
  /// **'عليّ {iOwe} · لي {owedToMe} · مدفوع {paid}'**
  String notifMonthEndBody(String iOwe, String owedToMe, String paid);

  /// No description provided for @notifMonthEndBodyWithOverdue.
  ///
  /// In ar, this message translates to:
  /// **'عليّ {iOwe} · لي {owedToMe} · مدفوع {paid} · متأخر {overdue}'**
  String notifMonthEndBodyWithOverdue(
    String iOwe,
    String owedToMe,
    String paid,
    String overdue,
  );

  /// No description provided for @notifMonthEndTitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص ذمتك لهذا الشهر'**
  String get notifMonthEndTitle;

  /// No description provided for @notifObligationTitle.
  ///
  /// In ar, this message translates to:
  /// **'التزام مستحق'**
  String get notifObligationTitle;

  /// No description provided for @notifOverdueBody.
  ///
  /// In ar, this message translates to:
  /// **'{name} — {amount} · {when}'**
  String notifOverdueBody(String name, String amount, String when);

  /// No description provided for @notifOverdueTitle.
  ///
  /// In ar, this message translates to:
  /// **'دفعة متأخرة'**
  String get notifOverdueTitle;

  /// No description provided for @notifPermissionDenied.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات غير مفعّلة في إعدادات النظام.'**
  String get notifPermissionDenied;

  /// No description provided for @notifReminderBody.
  ///
  /// In ar, this message translates to:
  /// **'{title}'**
  String notifReminderBody(String title);

  /// No description provided for @notifReminderTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير'**
  String get notifReminderTitle;

  /// No description provided for @notifWeeklyDigestTitle.
  ///
  /// In ar, this message translates to:
  /// **'{count} التزامات قادمة هذا الأسبوع'**
  String notifWeeklyDigestTitle(int count);

  /// No description provided for @numeralsArabicIndic.
  ///
  /// In ar, this message translates to:
  /// **'أرقام عربية (١٢٣٤)'**
  String get numeralsArabicIndic;

  /// No description provided for @numeralsLatin.
  ///
  /// In ar, this message translates to:
  /// **'أرقام غربية (1234)'**
  String get numeralsLatin;

  /// No description provided for @obligationArchived.
  ///
  /// In ar, this message translates to:
  /// **'التزام مؤرشف'**
  String get obligationArchived;

  /// No description provided for @obligationEndedOn.
  ///
  /// In ar, this message translates to:
  /// **'ينتهي في {date}'**
  String obligationEndedOn(String date);

  /// No description provided for @obligationFormEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الالتزام'**
  String get obligationFormEdit;

  /// No description provided for @obligationFormNew.
  ///
  /// In ar, this message translates to:
  /// **'التزام جديد'**
  String get obligationFormNew;

  /// No description provided for @obligationHistory.
  ///
  /// In ar, this message translates to:
  /// **'السجل'**
  String get obligationHistory;

  /// No description provided for @obligationMarkPaid.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل الدفع'**
  String get obligationMarkPaid;

  /// No description provided for @obligationMarkedPaid.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدفع'**
  String get obligationMarkedPaid;

  /// No description provided for @obligationMarkedSkipped.
  ///
  /// In ar, this message translates to:
  /// **'تم تخطي هذه الدورة'**
  String get obligationMarkedSkipped;

  /// No description provided for @obligationMonthlyAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get obligationMonthlyAmount;

  /// No description provided for @obligationNextDue.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق القادم {date}'**
  String obligationNextDue(String date);

  /// No description provided for @obligationSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي هذه الدورة'**
  String get obligationSkip;

  /// No description provided for @obligationUndoPayment.
  ///
  /// In ar, this message translates to:
  /// **'إلغاء الدفع'**
  String get obligationUndoPayment;

  /// No description provided for @obligationsEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف الإيجار أو الفواتير أو الاشتراكات ليتابعها التطبيق تلقائيًا.'**
  String get obligationsEmptyBody;

  /// No description provided for @obligationsEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد التزامات قادمة.'**
  String get obligationsEmptyTitle;

  /// No description provided for @obligationsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل ما يجب دفعه بشكل متكرر'**
  String get obligationsSubtitle;

  /// No description provided for @obligationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الالتزامات'**
  String get obligationsTitle;

  /// No description provided for @onboardingBack.
  ///
  /// In ar, this message translates to:
  /// **'السابق'**
  String get onboardingBack;

  /// No description provided for @onboardingCurrencyBody.
  ///
  /// In ar, this message translates to:
  /// **'ستُستخدم في السجلات الجديدة. كل سجل يمكن أن يكون بعملة مختلفة.'**
  String get onboardingCurrencyBody;

  /// No description provided for @onboardingCurrencyTitle.
  ///
  /// In ar, this message translates to:
  /// **'عملتك الافتراضية'**
  String get onboardingCurrencyTitle;

  /// No description provided for @onboardingEnableNotifications.
  ///
  /// In ar, this message translates to:
  /// **'تفعيل التذكيرات'**
  String get onboardingEnableNotifications;

  /// No description provided for @onboardingMaybeLater.
  ///
  /// In ar, this message translates to:
  /// **'ليس الآن'**
  String get onboardingMaybeLater;

  /// No description provided for @onboardingNext.
  ///
  /// In ar, this message translates to:
  /// **'التالي'**
  String get onboardingNext;

  /// No description provided for @onboardingNotificationsBody.
  ///
  /// In ar, this message translates to:
  /// **'نذكّرك قبل كل موعد استحقاق، في الوقت الذي تختاره. التذكيرات تُجدول على جهازك ولا تحتاج إنترنت.'**
  String get onboardingNotificationsBody;

  /// No description provided for @onboardingNotificationsDenied.
  ///
  /// In ar, this message translates to:
  /// **'لم يتم منح الإذن. يمكنك تفعيله من الإعدادات.'**
  String get onboardingNotificationsDenied;

  /// No description provided for @onboardingNotificationsTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يفوتك أي موعد'**
  String get onboardingNotificationsTitle;

  /// No description provided for @onboardingSkip.
  ///
  /// In ar, this message translates to:
  /// **'تخطي'**
  String get onboardingSkip;

  /// No description provided for @onboardingStart.
  ///
  /// In ar, this message translates to:
  /// **'ابدأ الآن'**
  String get onboardingStart;

  /// No description provided for @owedToMeEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل ما لك عند الآخرين لتتابعه.'**
  String get owedToMeEmptyBody;

  /// No description provided for @owedToMeEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد أموال مستحقة لك.'**
  String get owedToMeEmptyTitle;

  /// No description provided for @owedToMeSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'الأموال المستحقة لي'**
  String get owedToMeSubtitle;

  /// No description provided for @owedToMeTitle.
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get owedToMeTitle;

  /// No description provided for @paymentAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get paymentAmount;

  /// No description provided for @paymentDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get paymentDate;

  /// No description provided for @paymentDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'سيعود الرصيد إلى ما كان عليه قبل تسجيلها.'**
  String get paymentDeleteBody;

  /// No description provided for @paymentDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الدفعة؟'**
  String get paymentDeleteTitle;

  /// No description provided for @paymentDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الدفعة'**
  String get paymentDeleted;

  /// No description provided for @paymentEditTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الدفعة'**
  String get paymentEditTitle;

  /// No description provided for @paymentExceedsRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من المتبقي ({amount}). سيُسدَّد الدين بالكامل.'**
  String paymentExceedsRemaining(String amount);

  /// No description provided for @paymentNote.
  ///
  /// In ar, this message translates to:
  /// **'ملاحظة'**
  String get paymentNote;

  /// No description provided for @paymentPayFull.
  ///
  /// In ar, this message translates to:
  /// **'سداد كامل المتبقي'**
  String get paymentPayFull;

  /// No description provided for @paymentRemainingAfter.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي بعد الدفعة: {amount}'**
  String paymentRemainingAfter(String amount);

  /// No description provided for @paymentSave.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الدفعة'**
  String get paymentSave;

  /// No description provided for @paymentSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم تسجيل الدفعة'**
  String get paymentSaved;

  /// No description provided for @paymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'تسجيل دفعة'**
  String get paymentTitle;

  /// No description provided for @paymentWillSettle.
  ///
  /// In ar, this message translates to:
  /// **'هذه الدفعة ستُغلق الدين بالكامل.'**
  String get paymentWillSettle;

  /// No description provided for @peopleEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أضف شخصًا لتربط به الديون وتتابع الرصيد.'**
  String get peopleEmptyBody;

  /// No description provided for @peopleEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا يوجد أشخاص بعد.'**
  String get peopleEmptyTitle;

  /// No description provided for @peopleTitle.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get peopleTitle;

  /// No description provided for @periodAny.
  ///
  /// In ar, this message translates to:
  /// **'أي وقت'**
  String get periodAny;

  /// No description provided for @periodCustom.
  ///
  /// In ar, this message translates to:
  /// **'مخصص'**
  String get periodCustom;

  /// No description provided for @periodFrom.
  ///
  /// In ar, this message translates to:
  /// **'من {date}'**
  String periodFrom(String date);

  /// No description provided for @periodFromLabel.
  ///
  /// In ar, this message translates to:
  /// **'من تاريخ'**
  String get periodFromLabel;

  /// No description provided for @periodThisMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر'**
  String get periodThisMonth;

  /// No description provided for @periodThisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get periodThisWeek;

  /// No description provided for @periodTo.
  ///
  /// In ar, this message translates to:
  /// **'إلى {date}'**
  String periodTo(String date);

  /// No description provided for @periodToLabel.
  ///
  /// In ar, this message translates to:
  /// **'إلى تاريخ'**
  String get periodToLabel;

  /// No description provided for @periodToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get periodToday;

  /// No description provided for @personAddDebt.
  ///
  /// In ar, this message translates to:
  /// **'إضافة دين لهذا الشخص'**
  String get personAddDebt;

  /// No description provided for @personArchived.
  ///
  /// In ar, this message translates to:
  /// **'شخص مؤرشف'**
  String get personArchived;

  /// No description provided for @personAvatarColor.
  ///
  /// In ar, this message translates to:
  /// **'لون الصورة الرمزية'**
  String get personAvatarColor;

  /// No description provided for @personBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get personBalance;

  /// No description provided for @personDebtCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد ديون} =1{دين واحد} =2{دينان} few{{count} ديون} other{{count} دينًا}}'**
  String personDebtCount(int count);

  /// No description provided for @personDebtsSection.
  ///
  /// In ar, this message translates to:
  /// **'الديون'**
  String get personDebtsSection;

  /// No description provided for @personDeleteBody.
  ///
  /// In ar, this message translates to:
  /// **'ستبقى الديون محفوظة لكن بدون ارتباط بهذا الشخص.'**
  String get personDeleteBody;

  /// No description provided for @personDeleteTitle.
  ///
  /// In ar, this message translates to:
  /// **'حذف الشخص؟'**
  String get personDeleteTitle;

  /// No description provided for @personDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم حذف الشخص'**
  String get personDeleted;

  /// No description provided for @personFormEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل الشخص'**
  String get personFormEdit;

  /// No description provided for @personNameLabel.
  ///
  /// In ar, this message translates to:
  /// **'اسم الشخص'**
  String get personNameLabel;

  /// No description provided for @personNew.
  ///
  /// In ar, this message translates to:
  /// **'شخص جديد'**
  String get personNew;

  /// No description provided for @personNoDebts.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد ديون مرتبطة بهذا الشخص.'**
  String get personNoDebts;

  /// No description provided for @personPhoneLabel.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get personPhoneLabel;

  /// No description provided for @progressLabel.
  ///
  /// In ar, this message translates to:
  /// **'نسبة السداد'**
  String get progressLabel;

  /// No description provided for @recordDeleted.
  ///
  /// In ar, this message translates to:
  /// **'تم الحذف'**
  String get recordDeleted;

  /// No description provided for @recordSaved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ'**
  String get recordSaved;

  /// No description provided for @recordsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد سجلات} =1{سجل واحد} =2{سجلان} few{{count} سجلات} other{{count} سجلًا}}'**
  String recordsCount(int count);

  /// No description provided for @recurrenceCustom.
  ///
  /// In ar, this message translates to:
  /// **'مخصص'**
  String get recurrenceCustom;

  /// No description provided for @recurrenceEveryN.
  ///
  /// In ar, this message translates to:
  /// **'كل {count} {unit}'**
  String recurrenceEveryN(int count, String unit);

  /// No description provided for @recurrenceMonthly.
  ///
  /// In ar, this message translates to:
  /// **'شهري'**
  String get recurrenceMonthly;

  /// No description provided for @recurrenceNone.
  ///
  /// In ar, this message translates to:
  /// **'لا يتكرر'**
  String get recurrenceNone;

  /// No description provided for @recurrenceQuarterly.
  ///
  /// In ar, this message translates to:
  /// **'كل 3 أشهر'**
  String get recurrenceQuarterly;

  /// No description provided for @recurrenceWeekly.
  ///
  /// In ar, this message translates to:
  /// **'أسبوعي'**
  String get recurrenceWeekly;

  /// No description provided for @recurrenceYearly.
  ///
  /// In ar, this message translates to:
  /// **'سنوي'**
  String get recurrenceYearly;

  /// No description provided for @reminderCompletedMessage.
  ///
  /// In ar, this message translates to:
  /// **'تم إنجاز التذكير'**
  String get reminderCompletedMessage;

  /// No description provided for @reminderCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء التذكير'**
  String get reminderCreated;

  /// No description provided for @reminderFormEdit.
  ///
  /// In ar, this message translates to:
  /// **'تعديل التذكير'**
  String get reminderFormEdit;

  /// No description provided for @reminderMarkDone.
  ///
  /// In ar, this message translates to:
  /// **'تم'**
  String get reminderMarkDone;

  /// No description provided for @reminderNew.
  ///
  /// In ar, this message translates to:
  /// **'تذكير جديد'**
  String get reminderNew;

  /// No description provided for @reminderReopen.
  ///
  /// In ar, this message translates to:
  /// **'إعادة فتح'**
  String get reminderReopen;

  /// No description provided for @reminderTitleHint.
  ///
  /// In ar, this message translates to:
  /// **'مثال: تجديد التأمين'**
  String get reminderTitleHint;

  /// No description provided for @reminderTitleLabel.
  ///
  /// In ar, this message translates to:
  /// **'العنوان'**
  String get reminderTitleLabel;

  /// No description provided for @remindersCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتملة'**
  String get remindersCompleted;

  /// No description provided for @remindersEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ تذكيرًا لأي موعد لا تريد نسيانه.'**
  String get remindersEmptyBody;

  /// No description provided for @remindersEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد تذكيرات.'**
  String get remindersEmptyTitle;

  /// No description provided for @remindersLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get remindersLater;

  /// No description provided for @remindersOverdue.
  ///
  /// In ar, this message translates to:
  /// **'متأخر'**
  String get remindersOverdue;

  /// No description provided for @remindersSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'كل ما لا يجب نسيانه'**
  String get remindersSubtitle;

  /// No description provided for @remindersThisWeek.
  ///
  /// In ar, this message translates to:
  /// **'هذا الأسبوع'**
  String get remindersThisWeek;

  /// No description provided for @remindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get remindersTitle;

  /// No description provided for @remindersToday.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get remindersToday;

  /// No description provided for @remindersTomorrow.
  ///
  /// In ar, this message translates to:
  /// **'غدًا'**
  String get remindersTomorrow;

  /// No description provided for @reportAccountSummary.
  ///
  /// In ar, this message translates to:
  /// **'ملخص الحساب'**
  String get reportAccountSummary;

  /// No description provided for @reportActiveDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون نشطة'**
  String get reportActiveDebts;

  /// No description provided for @reportChartPaidVsNew.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع مقابل الديون الجديدة'**
  String get reportChartPaidVsNew;

  /// No description provided for @reportClosedDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون مغلقة'**
  String get reportClosedDebts;

  /// No description provided for @reportColumnAmount.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ'**
  String get reportColumnAmount;

  /// No description provided for @reportColumnBalance.
  ///
  /// In ar, this message translates to:
  /// **'الرصيد'**
  String get reportColumnBalance;

  /// No description provided for @reportColumnDate.
  ///
  /// In ar, this message translates to:
  /// **'التاريخ'**
  String get reportColumnDate;

  /// No description provided for @reportColumnDebt.
  ///
  /// In ar, this message translates to:
  /// **'الدين'**
  String get reportColumnDebt;

  /// No description provided for @reportColumnDirection.
  ///
  /// In ar, this message translates to:
  /// **'النوع'**
  String get reportColumnDirection;

  /// No description provided for @reportColumnDue.
  ///
  /// In ar, this message translates to:
  /// **'الاستحقاق'**
  String get reportColumnDue;

  /// No description provided for @reportColumnOperation.
  ///
  /// In ar, this message translates to:
  /// **'العملية'**
  String get reportColumnOperation;

  /// No description provided for @reportColumnPaid.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get reportColumnPaid;

  /// No description provided for @reportColumnRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي'**
  String get reportColumnRemaining;

  /// No description provided for @reportColumnTotal.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get reportColumnTotal;

  /// No description provided for @reportCurrentPosition.
  ///
  /// In ar, this message translates to:
  /// **'المركز الحالي'**
  String get reportCurrentPosition;

  /// No description provided for @reportDebtsBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'تفصيل الديون'**
  String get reportDebtsBreakdown;

  /// No description provided for @reportDeclaration.
  ///
  /// In ar, this message translates to:
  /// **'هذا المستند صادر من تطبيق ذِمّة بناءً على السجلات التي أدخلها صاحبه، ويُعرض للمراجعة والتذكير فقط.'**
  String get reportDeclaration;

  /// No description provided for @reportDocumentId.
  ///
  /// In ar, this message translates to:
  /// **'معرّف المستند'**
  String get reportDocumentId;

  /// No description provided for @reportDocumentNumber.
  ///
  /// In ar, this message translates to:
  /// **'رقم المستند'**
  String get reportDocumentNumber;

  /// No description provided for @reportEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب اختيار شهر آخر، أو أضف عملية جديدة.'**
  String get reportEmptyBody;

  /// No description provided for @reportEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات لهذا الشهر.'**
  String get reportEmptyTitle;

  /// No description provided for @reportExportPdf.
  ///
  /// In ar, this message translates to:
  /// **'تصدير PDF'**
  String get reportExportPdf;

  /// No description provided for @reportFutureMonth.
  ///
  /// In ar, this message translates to:
  /// **'هذا الشهر لم يبدأ بعد.'**
  String get reportFutureMonth;

  /// No description provided for @reportGeneratedBy.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء هذا المستند بواسطة تطبيق ذِمّة'**
  String get reportGeneratedBy;

  /// No description provided for @reportInsightAllClear.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد متأخرات، وكل شيء تحت السيطرة.'**
  String get reportInsightAllClear;

  /// No description provided for @reportInsightClosed.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لم تُغلق أي ديون هذا الشهر.} =1{تم إغلاق دين واحد هذا الشهر.} =2{تم إغلاق ديان هذا الشهر.} few{تم إغلاق {count} ديون هذا الشهر.} other{تم إغلاق {count} دينًا هذا الشهر.}}'**
  String reportInsightClosed(int count);

  /// No description provided for @reportInsightOverdue.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا ديون متأخرة.} =1{دين واحد متأخر يحتاج متابعة.} =2{ديان متأخران يحتاجان متابعة.} few{{count} ديون متأخرة تحتاج متابعة.} other{{count} دينًا متأخرًا يحتاج متابعة.}}'**
  String reportInsightOverdue(int count);

  /// No description provided for @reportInsightQuiet.
  ///
  /// In ar, this message translates to:
  /// **'لم تُسجَّل عمليات هذا الشهر بعد.'**
  String get reportInsightQuiet;

  /// No description provided for @reportInsightUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا التزامات مستحقة خلال الأيام القادمة.} =1{لديك التزام واحد يستحق خلال الأيام القادمة.} =2{لديك التزامان يستحقان خلال الأيام القادمة.} few{لديك {count} التزامات تستحق خلال الأيام القادمة.} other{لديك {count} التزامًا يستحق خلال الأيام القادمة.}}'**
  String reportInsightUpcoming(int count);

  /// No description provided for @reportIssuedOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الإصدار'**
  String get reportIssuedOn;

  /// No description provided for @reportMonthlyTitle.
  ///
  /// In ar, this message translates to:
  /// **'التقرير الشهري'**
  String get reportMonthlyTitle;

  /// No description provided for @reportNeedsAttention.
  ///
  /// In ar, this message translates to:
  /// **'يحتاج انتباهك'**
  String get reportNeedsAttention;

  /// No description provided for @reportNeedsAttentionEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا شيء متأخر ولا مستحق اليوم.'**
  String get reportNeedsAttentionEmpty;

  /// No description provided for @reportNewDebts.
  ///
  /// In ar, this message translates to:
  /// **'ديون جديدة'**
  String get reportNewDebts;

  /// No description provided for @reportObligations.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الالتزامات'**
  String get reportObligations;

  /// No description provided for @reportOpenPdf.
  ///
  /// In ar, this message translates to:
  /// **'فتح الملف'**
  String get reportOpenPdf;

  /// No description provided for @reportOptionBreakdown.
  ///
  /// In ar, this message translates to:
  /// **'تفصيل كل دين'**
  String get reportOptionBreakdown;

  /// No description provided for @reportOptionNotes.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات'**
  String get reportOptionNotes;

  /// No description provided for @reportOptionPayments.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الدفعات'**
  String get reportOptionPayments;

  /// No description provided for @reportOptionPhone.
  ///
  /// In ar, this message translates to:
  /// **'رقم الهاتف'**
  String get reportOptionPhone;

  /// No description provided for @reportOptionsTitle.
  ///
  /// In ar, this message translates to:
  /// **'خيارات الكشف'**
  String get reportOptionsTitle;

  /// No description provided for @reportOverdue.
  ///
  /// In ar, this message translates to:
  /// **'المتأخرات'**
  String get reportOverdue;

  /// No description provided for @reportPageOf.
  ///
  /// In ar, this message translates to:
  /// **'صفحة {page} من {total}'**
  String reportPageOf(int page, int total);

  /// No description provided for @reportPaidOut.
  ///
  /// In ar, this message translates to:
  /// **'ما تم دفعه'**
  String get reportPaidOut;

  /// No description provided for @reportPaymentHistory.
  ///
  /// In ar, this message translates to:
  /// **'سجل الدفعات'**
  String get reportPaymentHistory;

  /// No description provided for @reportPeopleCount.
  ///
  /// In ar, this message translates to:
  /// **'عدد الأشخاص'**
  String get reportPeopleCount;

  /// No description provided for @reportPickMonth.
  ///
  /// In ar, this message translates to:
  /// **'اختر الشهر'**
  String get reportPickMonth;

  /// No description provided for @reportReceived.
  ///
  /// In ar, this message translates to:
  /// **'ما تم استلامه'**
  String get reportReceived;

  /// No description provided for @reportSavePdf.
  ///
  /// In ar, this message translates to:
  /// **'طباعة أو حفظ'**
  String get reportSavePdf;

  /// No description provided for @reportSettled.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي ما تم سداده'**
  String get reportSettled;

  /// No description provided for @reportSharePdf.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة PDF'**
  String get reportSharePdf;

  /// No description provided for @reportShareStatement.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة كشف'**
  String get reportShareStatement;

  /// No description provided for @reportStatementFor.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب'**
  String get reportStatementFor;

  /// No description provided for @reportStatementReady.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء كشف الحساب'**
  String get reportStatementReady;

  /// No description provided for @reportStatementReadyBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك مراجعته قبل الإرسال.'**
  String get reportStatementReadyBody;

  /// No description provided for @reportStatementTitle.
  ///
  /// In ar, this message translates to:
  /// **'كشف حساب'**
  String get reportStatementTitle;

  /// No description provided for @reportTrend.
  ///
  /// In ar, this message translates to:
  /// **'آخر {months} أشهر'**
  String reportTrend(int months);

  /// No description provided for @reportTrendNewDebt.
  ///
  /// In ar, this message translates to:
  /// **'ديون جديدة'**
  String get reportTrendNewDebt;

  /// No description provided for @reportTrendSettled.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع'**
  String get reportTrendSettled;

  /// No description provided for @reportsSubtitle.
  ///
  /// In ar, this message translates to:
  /// **'ملخص شهري بسيط وواضح'**
  String get reportsSubtitle;

  /// No description provided for @reportsTitle.
  ///
  /// In ar, this message translates to:
  /// **'التقارير'**
  String get reportsTitle;

  /// No description provided for @requiredMark.
  ///
  /// In ar, this message translates to:
  /// **'مطلوب'**
  String get requiredMark;

  /// No description provided for @saveChanges.
  ///
  /// In ar, this message translates to:
  /// **'حفظ التعديلات'**
  String get saveChanges;

  /// No description provided for @saveDebt.
  ///
  /// In ar, this message translates to:
  /// **'حفظ الدين'**
  String get saveDebt;

  /// No description provided for @saving.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ الحفظ…'**
  String get saving;

  /// No description provided for @searchAction.
  ///
  /// In ar, this message translates to:
  /// **'بحث'**
  String get searchAction;

  /// No description provided for @searchEmptyBody.
  ///
  /// In ar, this message translates to:
  /// **'جرّب كلمة أخرى أو أزل الفلاتر.'**
  String get searchEmptyBody;

  /// No description provided for @searchEmptyTitle.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نتائج مطابقة.'**
  String get searchEmptyTitle;

  /// No description provided for @searchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث في الأسماء والالتزامات والملاحظات'**
  String get searchHint;

  /// No description provided for @searchRecent.
  ///
  /// In ar, this message translates to:
  /// **'آخر ما بحثت عنه'**
  String get searchRecent;

  /// No description provided for @searchTitle.
  ///
  /// In ar, this message translates to:
  /// **'البحث'**
  String get searchTitle;

  /// No description provided for @seeAll.
  ///
  /// In ar, this message translates to:
  /// **'الكل'**
  String get seeAll;

  /// No description provided for @settingsAbout.
  ///
  /// In ar, this message translates to:
  /// **'حول التطبيق'**
  String get settingsAbout;

  /// No description provided for @settingsAboutBody.
  ///
  /// In ar, this message translates to:
  /// **'ذِمّة تطبيق شخصي لإدارة ما لك وما عليك. يعمل بالكامل بدون إنترنت، وبياناتك محفوظة على جهازك فقط.'**
  String get settingsAboutBody;

  /// No description provided for @settingsAppLock.
  ///
  /// In ar, this message translates to:
  /// **'قفل التطبيق'**
  String get settingsAppLock;

  /// No description provided for @settingsAppLockBody.
  ///
  /// In ar, this message translates to:
  /// **'اطلب رمزًا عند فتح التطبيق'**
  String get settingsAppLockBody;

  /// No description provided for @settingsAppearance.
  ///
  /// In ar, this message translates to:
  /// **'المظهر'**
  String get settingsAppearance;

  /// No description provided for @settingsBiometric.
  ///
  /// In ar, this message translates to:
  /// **'فتح بالبصمة'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricBody.
  ///
  /// In ar, this message translates to:
  /// **'استخدم بصمة الإصبع أو الوجه'**
  String get settingsBiometricBody;

  /// No description provided for @settingsChangePin.
  ///
  /// In ar, this message translates to:
  /// **'تغيير الرمز'**
  String get settingsChangePin;

  /// No description provided for @settingsClearData.
  ///
  /// In ar, this message translates to:
  /// **'حذف جميع البيانات'**
  String get settingsClearData;

  /// No description provided for @settingsCurrenciesInUse.
  ///
  /// In ar, this message translates to:
  /// **'العملات المستخدمة'**
  String get settingsCurrenciesInUse;

  /// No description provided for @settingsCurrency.
  ///
  /// In ar, this message translates to:
  /// **'العملة الافتراضية'**
  String get settingsCurrency;

  /// No description provided for @settingsDangerZone.
  ///
  /// In ar, this message translates to:
  /// **'منطقة الخطر'**
  String get settingsDangerZone;

  /// No description provided for @settingsData.
  ///
  /// In ar, this message translates to:
  /// **'البيانات'**
  String get settingsData;

  /// No description provided for @settingsDueSoonWindow.
  ///
  /// In ar, this message translates to:
  /// **'نافذة «قريب الاستحقاق»'**
  String get settingsDueSoonWindow;

  /// No description provided for @settingsExport.
  ///
  /// In ar, this message translates to:
  /// **'تصدير البيانات'**
  String get settingsExport;

  /// No description provided for @settingsExportBody.
  ///
  /// In ar, this message translates to:
  /// **'احتفظ بنسخة من بياناتك'**
  String get settingsExportBody;

  /// No description provided for @settingsImport.
  ///
  /// In ar, this message translates to:
  /// **'استيراد البيانات'**
  String get settingsImport;

  /// No description provided for @settingsLanguage.
  ///
  /// In ar, this message translates to:
  /// **'اللغة'**
  String get settingsLanguage;

  /// No description provided for @settingsLicenses.
  ///
  /// In ar, this message translates to:
  /// **'التراخيص'**
  String get settingsLicenses;

  /// No description provided for @settingsMonthEnd.
  ///
  /// In ar, this message translates to:
  /// **'ملخص نهاية الشهر'**
  String get settingsMonthEnd;

  /// No description provided for @settingsMonthEndBody.
  ///
  /// In ar, this message translates to:
  /// **'ملخص تلقائي لذمتك في نهاية كل شهر'**
  String get settingsMonthEndBody;

  /// No description provided for @settingsMonthEndDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم الإشعار'**
  String get settingsMonthEndDay;

  /// No description provided for @settingsMonthEndTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإشعار'**
  String get settingsMonthEndTime;

  /// No description provided for @settingsNotificationTime.
  ///
  /// In ar, this message translates to:
  /// **'وقت الإشعار'**
  String get settingsNotificationTime;

  /// No description provided for @settingsNotifications.
  ///
  /// In ar, this message translates to:
  /// **'التنبيهات'**
  String get settingsNotifications;

  /// No description provided for @settingsNumerals.
  ///
  /// In ar, this message translates to:
  /// **'شكل الأرقام'**
  String get settingsNumerals;

  /// No description provided for @settingsPrivacyNote.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك على جهازك فقط'**
  String get settingsPrivacyNote;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In ar, this message translates to:
  /// **'سياسة الخصوصية'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsPrivacyPolicyBody.
  ///
  /// In ar, this message translates to:
  /// **'تُفتح في المتصفح'**
  String get settingsPrivacyPolicyBody;

  /// No description provided for @linkOpenFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح الرابط. تأكد من وجود متصفح على الجهاز.'**
  String get linkOpenFailed;

  /// No description provided for @settingsRateApp.
  ///
  /// In ar, this message translates to:
  /// **'قيّم التطبيق'**
  String get settingsRateApp;

  /// No description provided for @settingsReminderLead.
  ///
  /// In ar, this message translates to:
  /// **'التذكير قبل الاستحقاق'**
  String get settingsReminderLead;

  /// No description provided for @settingsRemindersEnabled.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات'**
  String get settingsRemindersEnabled;

  /// No description provided for @settingsRemindersEnabledBody.
  ///
  /// In ar, this message translates to:
  /// **'إشعارات محلية تعمل بدون إنترنت'**
  String get settingsRemindersEnabledBody;

  /// No description provided for @settingsSecurity.
  ///
  /// In ar, this message translates to:
  /// **'الأمان'**
  String get settingsSecurity;

  /// No description provided for @settingsSendFeedback.
  ///
  /// In ar, this message translates to:
  /// **'أرسل ملاحظاتك'**
  String get settingsSendFeedback;

  /// No description provided for @settingsTheme.
  ///
  /// In ar, this message translates to:
  /// **'الوضع'**
  String get settingsTheme;

  /// No description provided for @settingsTitle.
  ///
  /// In ar, this message translates to:
  /// **'الإعدادات'**
  String get settingsTitle;

  /// No description provided for @shareFooter.
  ///
  /// In ar, this message translates to:
  /// **'أُرسلت من تطبيق ذِمّة'**
  String get shareFooter;

  /// No description provided for @shareLineDirectionIOwe.
  ///
  /// In ar, this message translates to:
  /// **'عليّ'**
  String get shareLineDirectionIOwe;

  /// No description provided for @shareLineDirectionOwedToMe.
  ///
  /// In ar, this message translates to:
  /// **'لي'**
  String get shareLineDirectionOwedToMe;

  /// No description provided for @shareLineDue.
  ///
  /// In ar, this message translates to:
  /// **'موعد الاستحقاق: {date}'**
  String shareLineDue(String date);

  /// No description provided for @shareLinePaid.
  ///
  /// In ar, this message translates to:
  /// **'المدفوع: {amount}'**
  String shareLinePaid(String amount);

  /// No description provided for @shareLinePaidOn.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الدفع: {date}'**
  String shareLinePaidOn(String date);

  /// No description provided for @shareLineRemaining.
  ///
  /// In ar, this message translates to:
  /// **'المتبقي: {amount}'**
  String shareLineRemaining(String amount);

  /// No description provided for @shareLineTotal.
  ///
  /// In ar, this message translates to:
  /// **'إجمالي الدين: {amount}'**
  String shareLineTotal(String amount);

  /// No description provided for @sharePaymentBody.
  ///
  /// In ar, this message translates to:
  /// **'{person} · {amount} · {date}'**
  String sharePaymentBody(String person, String amount, String date);

  /// No description provided for @sharePaymentTitle.
  ///
  /// In ar, this message translates to:
  /// **'إيصال دفعة'**
  String get sharePaymentTitle;

  /// No description provided for @shareSubject.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الدين'**
  String get shareSubject;

  /// No description provided for @somethingWentWrong.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ غير متوقع.'**
  String get somethingWentWrong;

  /// No description provided for @sortAmountHighest.
  ///
  /// In ar, this message translates to:
  /// **'الأعلى مبلغًا'**
  String get sortAmountHighest;

  /// No description provided for @sortAmountLowest.
  ///
  /// In ar, this message translates to:
  /// **'الأقل مبلغًا'**
  String get sortAmountLowest;

  /// No description provided for @sortDueLatest.
  ///
  /// In ar, this message translates to:
  /// **'الأبعد استحقاقًا'**
  String get sortDueLatest;

  /// No description provided for @sortDueSoonest.
  ///
  /// In ar, this message translates to:
  /// **'الأقرب استحقاقًا'**
  String get sortDueSoonest;

  /// No description provided for @sortNameAscending.
  ///
  /// In ar, this message translates to:
  /// **'الاسم (أ–ي)'**
  String get sortNameAscending;

  /// No description provided for @sortOldestAdded.
  ///
  /// In ar, this message translates to:
  /// **'الأقدم إضافة'**
  String get sortOldestAdded;

  /// No description provided for @sortRecentlyAdded.
  ///
  /// In ar, this message translates to:
  /// **'الأحدث إضافة'**
  String get sortRecentlyAdded;

  /// No description provided for @startupFailedBody.
  ///
  /// In ar, this message translates to:
  /// **'حدث خطأ أثناء فتح البيانات على جهازك.'**
  String get startupFailedBody;

  /// No description provided for @startupFailedRetry.
  ///
  /// In ar, this message translates to:
  /// **'إعادة المحاولة'**
  String get startupFailedRetry;

  /// No description provided for @startupFailedSafe.
  ///
  /// In ar, this message translates to:
  /// **'لم يُغيَّر أي شيء في سجلاتك.'**
  String get startupFailedSafe;

  /// No description provided for @startupFailedTitle.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر فتح دفاترك'**
  String get startupFailedTitle;

  /// No description provided for @startupFailedTooNew.
  ///
  /// In ar, this message translates to:
  /// **'هذه البيانات كُتبت بنسخة أحدث من ذِمّة. حدِّث التطبيق ثم أعد المحاولة.'**
  String get startupFailedTooNew;

  /// No description provided for @statusActive.
  ///
  /// In ar, this message translates to:
  /// **'جاري'**
  String get statusActive;

  /// No description provided for @statusArchived.
  ///
  /// In ar, this message translates to:
  /// **'مؤرشف'**
  String get statusArchived;

  /// No description provided for @statusCancelled.
  ///
  /// In ar, this message translates to:
  /// **'ملغى'**
  String get statusCancelled;

  /// No description provided for @statusCompleted.
  ///
  /// In ar, this message translates to:
  /// **'مكتمل'**
  String get statusCompleted;

  /// No description provided for @statusDismissed.
  ///
  /// In ar, this message translates to:
  /// **'متجاهَل'**
  String get statusDismissed;

  /// No description provided for @statusDueSoon.
  ///
  /// In ar, this message translates to:
  /// **'قريب الاستحقاق'**
  String get statusDueSoon;

  /// No description provided for @statusDueToday.
  ///
  /// In ar, this message translates to:
  /// **'مستحق اليوم'**
  String get statusDueToday;

  /// No description provided for @statusOverdue.
  ///
  /// In ar, this message translates to:
  /// **'متأخر'**
  String get statusOverdue;

  /// No description provided for @statusPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع بالكامل'**
  String get statusPaid;

  /// No description provided for @statusPartiallyPaid.
  ///
  /// In ar, this message translates to:
  /// **'مدفوع جزئيًا'**
  String get statusPartiallyPaid;

  /// No description provided for @statusSkipped.
  ///
  /// In ar, this message translates to:
  /// **'متجاوز'**
  String get statusSkipped;

  /// No description provided for @statusUnpaid.
  ///
  /// In ar, this message translates to:
  /// **'غير مدفوع'**
  String get statusUnpaid;

  /// No description provided for @statusUpcoming.
  ///
  /// In ar, this message translates to:
  /// **'قادم'**
  String get statusUpcoming;

  /// No description provided for @swipeToDelete.
  ///
  /// In ar, this message translates to:
  /// **'اسحب للحذف'**
  String get swipeToDelete;

  /// No description provided for @themeDark.
  ///
  /// In ar, this message translates to:
  /// **'ليلي'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In ar, this message translates to:
  /// **'نهاري'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In ar, this message translates to:
  /// **'حسب النظام'**
  String get themeSystem;

  /// No description provided for @todayLabel.
  ///
  /// In ar, this message translates to:
  /// **'اليوم'**
  String get todayLabel;

  /// No description provided for @totalLabel.
  ///
  /// In ar, this message translates to:
  /// **'الإجمالي'**
  String get totalLabel;

  /// No description provided for @unitDay.
  ///
  /// In ar, this message translates to:
  /// **'يوم'**
  String get unitDay;

  /// No description provided for @unitMonth.
  ///
  /// In ar, this message translates to:
  /// **'شهر'**
  String get unitMonth;

  /// No description provided for @unitWeek.
  ///
  /// In ar, this message translates to:
  /// **'أسبوع'**
  String get unitWeek;

  /// No description provided for @unitYear.
  ///
  /// In ar, this message translates to:
  /// **'سنة'**
  String get unitYear;

  /// No description provided for @unknownPerson.
  ///
  /// In ar, this message translates to:
  /// **'بدون عنوان'**
  String get unknownPerson;

  /// No description provided for @updateAvailableBody.
  ///
  /// In ar, this message translates to:
  /// **'يوجد إصدار أحدث من ذِمّة جاهز على Google Play.'**
  String get updateAvailableBody;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In ar, this message translates to:
  /// **'تحديث جديد متوفر'**
  String get updateAvailableTitle;

  /// No description provided for @updateDownloadingBody.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك متابعة عملك في ذِمّة أثناء التنزيل.'**
  String get updateDownloadingBody;

  /// No description provided for @updateDownloadingTitle.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ تنزيل التحديث'**
  String get updateDownloadingTitle;

  /// No description provided for @updateLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get updateLater;

  /// No description provided for @updateNow.
  ///
  /// In ar, this message translates to:
  /// **'تحديث الآن'**
  String get updateNow;

  /// No description provided for @updatePercent.
  ///
  /// In ar, this message translates to:
  /// **'{percent}%'**
  String updatePercent(int percent);

  /// No description provided for @updateReadyBody.
  ///
  /// In ar, this message translates to:
  /// **'أُكمل التنزيل. سيتولّى Google Play التثبيت ويعيد تشغيل ذِمّة.'**
  String get updateReadyBody;

  /// No description provided for @updateReadyTitle.
  ///
  /// In ar, this message translates to:
  /// **'التحديث جاهز للتثبيت'**
  String get updateReadyTitle;

  /// No description provided for @updateRestartAndInstall.
  ///
  /// In ar, this message translates to:
  /// **'إعادة التشغيل والتحديث'**
  String get updateRestartAndInstall;

  /// No description provided for @validationAmountTooLarge.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ كبير جدًا.'**
  String get validationAmountTooLarge;

  /// No description provided for @validationDayOfMonth.
  ///
  /// In ar, this message translates to:
  /// **'اختر يومًا بين 1 و 31.'**
  String get validationDayOfMonth;

  /// No description provided for @validationDueBeforeIssue.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الاستحقاق قبل تاريخ الدين.'**
  String get validationDueBeforeIssue;

  /// No description provided for @validationEndBeforeStart.
  ///
  /// In ar, this message translates to:
  /// **'تاريخ الانتهاء قبل تاريخ البداية.'**
  String get validationEndBeforeStart;

  /// No description provided for @validationInvalidAmount.
  ///
  /// In ar, this message translates to:
  /// **'أدخل مبلغًا صحيحًا أكبر من صفر.'**
  String get validationInvalidAmount;

  /// No description provided for @validationNameExists.
  ///
  /// In ar, this message translates to:
  /// **'يوجد شخص بهذا الاسم بالفعل.'**
  String get validationNameExists;

  /// No description provided for @validationNameTooLong.
  ///
  /// In ar, this message translates to:
  /// **'الاسم طويل جدًا.'**
  String get validationNameTooLong;

  /// No description provided for @validationNameTooShort.
  ///
  /// In ar, this message translates to:
  /// **'الاسم قصير جدًا.'**
  String get validationNameTooShort;

  /// No description provided for @validationNegative.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إدخال قيمة سالبة.'**
  String get validationNegative;

  /// No description provided for @validationNoteTooLong.
  ///
  /// In ar, this message translates to:
  /// **'الملاحظات طويلة جدًا.'**
  String get validationNoteTooLong;

  /// No description provided for @validationOverPayment.
  ///
  /// In ar, this message translates to:
  /// **'المبلغ أكبر من المتبقي ({amount}).'**
  String validationOverPayment(String amount);

  /// No description provided for @validationPhoneInvalid.
  ///
  /// In ar, this message translates to:
  /// **'أدخل رقم هاتف صحيحًا.'**
  String get validationPhoneInvalid;

  /// No description provided for @validationRequired.
  ///
  /// In ar, this message translates to:
  /// **'هذا الحقل مطلوب.'**
  String get validationRequired;

  /// No description provided for @validationTitleTooLong.
  ///
  /// In ar, this message translates to:
  /// **'الوصف طويل جدًا.'**
  String get validationTitleTooLong;

  /// No description provided for @debtFormWithPerson.
  ///
  /// In ar, this message translates to:
  /// **'الدين مع {name}'**
  String debtFormWithPerson(String name);

  /// No description provided for @debtSavedMoved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ، وانتقل الدين إلى «{side}».'**
  String debtSavedMoved(String side);

  /// No description provided for @debtSavedParticipantRemoved.
  ///
  /// In ar, this message translates to:
  /// **'تم الحفظ، ولم يعد الدين مرتبطًا بـ {name}.'**
  String debtSavedParticipantRemoved(String name);

  /// No description provided for @fieldPeople.
  ///
  /// In ar, this message translates to:
  /// **'الأشخاص'**
  String get fieldPeople;

  /// No description provided for @fieldPersonPlaceholder.
  ///
  /// In ar, this message translates to:
  /// **'اختر شخصًا أو أكثر'**
  String get fieldPersonPlaceholder;

  /// No description provided for @participantsAdd.
  ///
  /// In ar, this message translates to:
  /// **'إضافة شخص'**
  String get participantsAdd;

  /// No description provided for @participantsAddMore.
  ///
  /// In ar, this message translates to:
  /// **'إضافة أشخاص آخرين'**
  String get participantsAddMore;

  /// No description provided for @participantsSearchHint.
  ///
  /// In ar, this message translates to:
  /// **'ابحث عن شخص'**
  String get participantsSearchHint;

  /// No description provided for @participantsSelected.
  ///
  /// In ar, this message translates to:
  /// **'المحددون'**
  String get participantsSelected;

  /// No description provided for @requiredFieldsMissing.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{حقل مطلوب واحد لم يكتمل.} =2{حقلان مطلوبان لم يكتملا.} few{{count} حقول مطلوبة لم تكتمل.} many{{count} حقلًا مطلوبًا لم يكتمل.} other{{count} حقل مطلوب لم يكتمل.}}'**
  String requiredFieldsMissing(int count);

  /// No description provided for @unsavedChangesBody.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفظ التغييرات التي أدخلتها. هل تريد الخروج؟'**
  String get unsavedChangesBody;

  /// No description provided for @unsavedChangesLeave.
  ///
  /// In ar, this message translates to:
  /// **'خروج بدون حفظ'**
  String get unsavedChangesLeave;

  /// No description provided for @unsavedChangesStay.
  ///
  /// In ar, this message translates to:
  /// **'متابعة التعديل'**
  String get unsavedChangesStay;

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In ar, this message translates to:
  /// **'تغييرات غير محفوظة'**
  String get unsavedChangesTitle;

  /// No description provided for @validationSelectDirection.
  ///
  /// In ar, this message translates to:
  /// **'اختر نوع الدين: عليّ أو لي.'**
  String get validationSelectDirection;

  /// No description provided for @validationSelectParticipant.
  ///
  /// In ar, this message translates to:
  /// **'اختر شخصًا واحدًا على الأقل.'**
  String get validationSelectParticipant;

  /// No description provided for @reminderNotArmedOff.
  ///
  /// In ar, this message translates to:
  /// **'التذكيرات متوقفة في الإعدادات، فلن يصلك إشعار عن هذا الدين.'**
  String get reminderNotArmedOff;

  /// No description provided for @reminderNotArmedDenied.
  ///
  /// In ar, this message translates to:
  /// **'الإشعارات غير مسموح بها من النظام، فلن يصلك إشعار عن هذا الدين.'**
  String get reminderNotArmedDenied;

  /// No description provided for @settingsBackup.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطي والاستعادة'**
  String get settingsBackup;

  /// No description provided for @backupSectionHint.
  ///
  /// In ar, this message translates to:
  /// **'نسخة من كل بياناتك في ملف واحد يمكنك الاحتفاظ به.'**
  String get backupSectionHint;

  /// No description provided for @backupAutoTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ التلقائي'**
  String get backupAutoTitle;

  /// No description provided for @backupAutoStateOn.
  ///
  /// In ar, this message translates to:
  /// **'مفعّل'**
  String get backupAutoStateOn;

  /// No description provided for @backupAutoStateOff.
  ///
  /// In ar, this message translates to:
  /// **'متوقف'**
  String get backupAutoStateOff;

  /// No description provided for @backupAutoOnBody.
  ///
  /// In ar, this message translates to:
  /// **'يحفظ ذِمّة تغييراتك تلقائيًا بعد كل تغيير مهم، وعند مغادرة التطبيق.'**
  String get backupAutoOnBody;

  /// No description provided for @backupAutoOffBody.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك الحالية محفوظة داخل التطبيق. لن تُنشأ نسخ جديدة تلقائيًا حتى تُشغّل «الحفظ التلقائي» مرة أخرى.'**
  String get backupAutoOffBody;

  /// No description provided for @backupDetailAutomatic.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ التلقائي'**
  String get backupDetailAutomatic;

  /// No description provided for @backupDetailLastCopy.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة'**
  String get backupDetailLastCopy;

  /// No description provided for @backupDetailRestorable.
  ///
  /// In ar, this message translates to:
  /// **'نسخ للاستعادة'**
  String get backupDetailRestorable;

  /// No description provided for @backupDetailPending.
  ///
  /// In ar, this message translates to:
  /// **'تغييرات غير محفوظة'**
  String get backupDetailPending;

  /// No description provided for @backupDetailFolder.
  ///
  /// In ar, this message translates to:
  /// **'مجلد النسخ'**
  String get backupDetailFolder;

  /// No description provided for @backupDetailAttempts.
  ///
  /// In ar, this message translates to:
  /// **'محاولات فاشلة'**
  String get backupDetailAttempts;

  /// No description provided for @backupHistoryLatest.
  ///
  /// In ar, this message translates to:
  /// **'أحدث نسخة'**
  String get backupHistoryLatest;

  /// No description provided for @backupHistoryVerified.
  ///
  /// In ar, this message translates to:
  /// **'متحقق منها'**
  String get backupHistoryVerified;

  /// No description provided for @backupFolderTitle.
  ///
  /// In ar, this message translates to:
  /// **'مجلد النسخ الاحتياطية'**
  String get backupFolderTitle;

  /// No description provided for @backupFolderSetupTitle.
  ///
  /// In ar, this message translates to:
  /// **'أنشئ مكانًا لنسخك الاحتياطية'**
  String get backupFolderSetupTitle;

  /// No description provided for @backupFolderSetupBody.
  ///
  /// In ar, this message translates to:
  /// **'سيستخدم ذِمّة هذا المجلد لحفظ النسخ الاحتياطية وفتحها مباشرة عند الاستعادة.'**
  String get backupFolderSetupBody;

  /// No description provided for @backupFolderChoose.
  ///
  /// In ar, this message translates to:
  /// **'اختيار مجلد النسخ الاحتياطية'**
  String get backupFolderChoose;

  /// No description provided for @backupFolderChange.
  ///
  /// In ar, this message translates to:
  /// **'تغيير المجلد'**
  String get backupFolderChange;

  /// No description provided for @backupFolderCheck.
  ///
  /// In ar, this message translates to:
  /// **'فحص الآن'**
  String get backupFolderCheck;

  /// No description provided for @backupFolderLater.
  ///
  /// In ar, this message translates to:
  /// **'لاحقًا'**
  String get backupFolderLater;

  /// No description provided for @backupFolderAvailable.
  ///
  /// In ar, this message translates to:
  /// **'متاح'**
  String get backupFolderAvailable;

  /// No description provided for @backupFolderMissing.
  ///
  /// In ar, this message translates to:
  /// **'مجلد النسخ الاحتياطية غير متاح'**
  String get backupFolderMissing;

  /// No description provided for @backupFolderLostAccess.
  ///
  /// In ar, this message translates to:
  /// **'لم يعد للتطبيق وصول إلى هذا المجلد: إمّا أن الإذن أُلغي، أو أن المجلد نُقل أو حُذف.'**
  String get backupFolderLostAccess;

  /// No description provided for @backupFolderReauthorize.
  ///
  /// In ar, this message translates to:
  /// **'إعادة السماح'**
  String get backupFolderReauthorize;

  /// No description provided for @backupFolderBackupsCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا نسخ صالحة} =1{نسخة واحدة صالحة} =2{نسختان صالحتان} few{{count} نسخ صالحة} many{{count} نسخة صالحة} other{{count} نسخة صالحة}}'**
  String backupFolderBackupsCount(int count);

  /// No description provided for @backupFolderEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ احتياطية في هذا المجلد'**
  String get backupFolderEmpty;

  /// No description provided for @backupFolderConfirmTitle.
  ///
  /// In ar, this message translates to:
  /// **'استخدام هذا المجلد؟'**
  String get backupFolderConfirmTitle;

  /// No description provided for @backupFolderConfirmBody.
  ///
  /// In ar, this message translates to:
  /// **'لا يمكن إنشاء مجلد «Dhimmah Backups» هنا. هل تريد حفظ النسخ في المجلد الذي اخترته؟'**
  String get backupFolderConfirmBody;

  /// No description provided for @backupFolderUseIt.
  ///
  /// In ar, this message translates to:
  /// **'استخدم هذا المجلد'**
  String get backupFolderUseIt;

  /// No description provided for @backupFolderDecline.
  ///
  /// In ar, this message translates to:
  /// **'اختيار مجلد آخر'**
  String get backupFolderDecline;

  /// No description provided for @backupFolderInvalidNote.
  ///
  /// In ar, this message translates to:
  /// **'ملفات تشبه النسخ لكنها غير صالحة: {count}'**
  String backupFolderInvalidNote(int count);

  /// No description provided for @backupFolderNotWritable.
  ///
  /// In ar, this message translates to:
  /// **'المجلد لا يقبل الكتابة'**
  String get backupFolderNotWritable;

  /// No description provided for @backupFolderError.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الوصول إلى المجلد'**
  String get backupFolderError;

  /// No description provided for @backupFolderVerifying.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ فحص المجلد'**
  String get backupFolderVerifying;

  /// No description provided for @backupHistoryInternal.
  ///
  /// In ar, this message translates to:
  /// **'داخل التطبيق'**
  String get backupHistoryInternal;

  /// No description provided for @backupHistoryFolder.
  ///
  /// In ar, this message translates to:
  /// **'في مجلد النسخ'**
  String get backupHistoryFolder;

  /// No description provided for @backupExternalDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت النسخة من المجلد'**
  String get backupExternalDeleted;

  /// No description provided for @backupExternalDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف النسخة من المجلد'**
  String get backupExternalDeleteFailed;

  /// No description provided for @backupNowAction.
  ///
  /// In ar, this message translates to:
  /// **'حفظ نسخة خارجية'**
  String get backupNowAction;

  /// No description provided for @backupSaveExternalBody.
  ///
  /// In ar, this message translates to:
  /// **'ملف تحفظه أنت في المكان الذي تختاره.'**
  String get backupSaveExternalBody;

  /// No description provided for @backupShareTile.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة النسخة'**
  String get backupShareTile;

  /// No description provided for @backupShareTileBody.
  ///
  /// In ar, this message translates to:
  /// **'أرسل نسخة إلى تطبيق آخر.'**
  String get backupShareTileBody;

  /// No description provided for @backupExternalSaved.
  ///
  /// In ar, this message translates to:
  /// **'حُفظت النسخة خارجيًا وتحقّقنا منها'**
  String get backupExternalSaved;

  /// No description provided for @backupExternalSavedBody.
  ///
  /// In ar, this message translates to:
  /// **'الملف: {name} · {size}'**
  String backupExternalSavedBody(String name, String size);

  /// No description provided for @backupExternalFailedWrite.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر كتابة الملف في المكان الذي اخترته'**
  String get backupExternalFailedWrite;

  /// No description provided for @backupExternalFailedReadBack.
  ///
  /// In ar, this message translates to:
  /// **'كُتب الملف لكن تعذّر التحقق منه بعد الحفظ'**
  String get backupExternalFailedReadBack;

  /// No description provided for @backupExternalFailedIncomplete.
  ///
  /// In ar, this message translates to:
  /// **'الملف المحفوظ فارغ أو ناقص'**
  String get backupExternalFailedIncomplete;

  /// No description provided for @backupExternalFailedInvalid.
  ///
  /// In ar, this message translates to:
  /// **'الملف المحفوظ لم يجتز التحقق من المحتوى'**
  String get backupExternalFailedInvalid;

  /// No description provided for @backupExternalFailedUnavailable.
  ///
  /// In ar, this message translates to:
  /// **'هذا الجهاز لا يوفّر اختيار مكان للحفظ'**
  String get backupExternalFailedUnavailable;

  /// No description provided for @backupRestoreAction.
  ///
  /// In ar, this message translates to:
  /// **'استعد من ملف'**
  String get backupRestoreAction;

  /// No description provided for @backupPreviousAction.
  ///
  /// In ar, this message translates to:
  /// **'النسخ السابقة'**
  String get backupPreviousAction;

  /// No description provided for @backupCopiesCount.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا توجد نسخ} =1{نسخة واحدة} =2{نسختان} few{{count} نسخ} many{{count} نسخة} other{{count} نسخة}}'**
  String backupCopiesCount(int count);

  /// No description provided for @backupPreviousTitle.
  ///
  /// In ar, this message translates to:
  /// **'النسخ السابقة'**
  String get backupPreviousTitle;

  /// No description provided for @backupPreviousEmpty.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد نسخ محفوظة على هذا الجهاز.'**
  String get backupPreviousEmpty;

  /// No description provided for @backupProtectionProtected.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك محمية'**
  String get backupProtectionProtected;

  /// No description provided for @backupProtectionPending.
  ///
  /// In ar, this message translates to:
  /// **'هناك تغييرات بانتظار الحفظ'**
  String get backupProtectionPending;

  /// No description provided for @backupProtectionBackingUp.
  ///
  /// In ar, this message translates to:
  /// **'جارٍ حفظ التغييرات'**
  String get backupProtectionBackingUp;

  /// No description provided for @backupProtectionNever.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك غير محمية بعد'**
  String get backupProtectionNever;

  /// No description provided for @backupProtectionRecoverable.
  ///
  /// In ar, this message translates to:
  /// **'توجد نسخة يمكن استعادتها'**
  String get backupProtectionRecoverable;

  /// No description provided for @backupProtectionAttention.
  ///
  /// In ar, this message translates to:
  /// **'النسخ الاحتياطية تحتاج انتباهك'**
  String get backupProtectionAttention;

  /// No description provided for @backupProtectionStorage.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر الحفظ في مكان النسخ'**
  String get backupProtectionStorage;

  /// No description provided for @backupProtectionNoLocation.
  ///
  /// In ar, this message translates to:
  /// **'لم يُحدَّد مكان دائم للنسخ'**
  String get backupProtectionNoLocation;

  /// No description provided for @backupProtectionLastSuccess.
  ///
  /// In ar, this message translates to:
  /// **'آخر نسخة ناجحة · {when}'**
  String backupProtectionLastSuccess(String when);

  /// No description provided for @backupProtectionNeverWorked.
  ///
  /// In ar, this message translates to:
  /// **'لم تُحفظ نسخة بعد'**
  String get backupProtectionNeverWorked;

  /// No description provided for @backupProtectionDetails.
  ///
  /// In ar, this message translates to:
  /// **'تفاصيل الحماية'**
  String get backupProtectionDetails;

  /// No description provided for @backupProtectionHideDetails.
  ///
  /// In ar, this message translates to:
  /// **'إخفاء التفاصيل'**
  String get backupProtectionHideDetails;

  /// No description provided for @backupProtectionCopiesInside.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء داخل التطبيق} =1{نسخة واحدة داخل التطبيق} =2{نسختان داخل التطبيق} few{{count} نسخ داخل التطبيق} many{{count} نسخة داخل التطبيق} other{{count} نسخة داخل التطبيق}}'**
  String backupProtectionCopiesInside(int count);

  /// No description provided for @backupProtectionCopiesOutside.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا شيء في مجلدك} =1{نسخة واحدة في مجلدك} =2{نسختان في مجلدك} few{{count} نسخ في مجلدك} many{{count} نسخة في مجلدك} other{{count} نسخة في مجلدك}}'**
  String backupProtectionCopiesOutside(int count);

  /// No description provided for @backupProtectionWaiting.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =0{لا سجلات} =1{سجل واحد} =2{سجلان} few{{count} سجلات} many{{count} سجلًا} other{{count} سجل}}'**
  String backupProtectionWaiting(int count);

  /// No description provided for @backupProtectionFolderNone.
  ///
  /// In ar, this message translates to:
  /// **'لم يُختر بعد'**
  String get backupProtectionFolderNone;

  /// No description provided for @backupProtectionAutoOff.
  ///
  /// In ar, this message translates to:
  /// **'الحفظ التلقائي متوقف'**
  String get backupProtectionAutoOff;

  /// No description provided for @backupProtectionFailedTimes.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{مرة واحدة} =2{مرتان} few{{count} مرات} many{{count} مرة} other{{count} مرة}}'**
  String backupProtectionFailedTimes(int count);

  /// No description provided for @backupProtectionDataSafe.
  ///
  /// In ar, this message translates to:
  /// **'بياناتك الحالية محفوظة داخل التطبيق ولم تتأثر.'**
  String get backupProtectionDataSafe;

  /// No description provided for @backupProtectionHowTitle.
  ///
  /// In ar, this message translates to:
  /// **'كيف يحمي ذِمّة بياناتك؟'**
  String get backupProtectionHowTitle;

  /// No description provided for @backupProtectionHowBody.
  ///
  /// In ar, this message translates to:
  /// **'يحفظ ذِمّة نسخة من تغييراتك من تلقاء نفسه، ويتحقق من كل نسخة بعد كتابتها بقراءتها مرة أخرى. تُحفظ نقاط استعادة تكفي للرجوع خطوة إلى الوراء، ولا تُحذف النسخة اليدوية أبدًا. الاستعادة لا تبدأ إلا بتأكيد منك، وقبلها تُؤخذ نسخة أمان من بياناتك الحالية. وإذا تعذّر الحفظ، فبياناتك في التطبيق تبقى كما هي.'**
  String get backupProtectionHowBody;

  /// No description provided for @backupEntryAuto.
  ///
  /// In ar, this message translates to:
  /// **'نسخة تلقائية'**
  String get backupEntryAuto;

  /// No description provided for @backupEntryManual.
  ///
  /// In ar, this message translates to:
  /// **'نسخة يدوية'**
  String get backupEntryManual;

  /// No description provided for @backupEntrySafety.
  ///
  /// In ar, this message translates to:
  /// **'نسخة قبل استعادة'**
  String get backupEntrySafety;

  /// No description provided for @backupShareAction.
  ///
  /// In ar, this message translates to:
  /// **'مشاركة'**
  String get backupShareAction;

  /// No description provided for @backupDeleteAction.
  ///
  /// In ar, this message translates to:
  /// **'حذف'**
  String get backupDeleteAction;

  /// No description provided for @backupDeleted.
  ///
  /// In ar, this message translates to:
  /// **'حُذفت النسخة'**
  String get backupDeleted;

  /// No description provided for @backupDeleteFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر حذف النسخة، وما زالت في القائمة'**
  String get backupDeleteFailed;

  /// No description provided for @backupCreated.
  ///
  /// In ar, this message translates to:
  /// **'تم إنشاء النسخة الاحتياطية'**
  String get backupCreated;

  /// No description provided for @backupStepReading.
  ///
  /// In ar, this message translates to:
  /// **'قراءة السجلات'**
  String get backupStepReading;

  /// No description provided for @backupStepBuilding.
  ///
  /// In ar, this message translates to:
  /// **'تجهيز بيانات النسخة'**
  String get backupStepBuilding;

  /// No description provided for @backupStepHashing.
  ///
  /// In ar, this message translates to:
  /// **'حساب بصمة التحقق'**
  String get backupStepHashing;

  /// No description provided for @backupStepWriting.
  ///
  /// In ar, this message translates to:
  /// **'كتابة الملف'**
  String get backupStepWriting;

  /// No description provided for @backupStepVerifying.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من الملف بعد كتابته'**
  String get backupStepVerifying;

  /// No description provided for @backupStepRetaining.
  ///
  /// In ar, this message translates to:
  /// **'ترتيب النسخ السابقة'**
  String get backupStepRetaining;

  /// No description provided for @restoreStepReading.
  ///
  /// In ar, this message translates to:
  /// **'قراءة الملف'**
  String get restoreStepReading;

  /// No description provided for @restoreStepDecoding.
  ///
  /// In ar, this message translates to:
  /// **'فك محتوى الملف'**
  String get restoreStepDecoding;

  /// No description provided for @restoreStepChecking.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من سلامة الملف'**
  String get restoreStepChecking;

  /// No description provided for @restoreStepValidating.
  ///
  /// In ar, this message translates to:
  /// **'تدقيق البيانات'**
  String get restoreStepValidating;

  /// No description provided for @restoreStepPlanning.
  ///
  /// In ar, this message translates to:
  /// **'تحديد ما سيُكتب'**
  String get restoreStepPlanning;

  /// No description provided for @restoreStepSnapshot.
  ///
  /// In ar, this message translates to:
  /// **'أخذ نسخة أمان من بياناتك الحالية'**
  String get restoreStepSnapshot;

  /// No description provided for @restoreStepWriting.
  ///
  /// In ar, this message translates to:
  /// **'كتابة البيانات'**
  String get restoreStepWriting;

  /// No description provided for @restoreStepVerifying.
  ///
  /// In ar, this message translates to:
  /// **'التحقق من النتيجة'**
  String get restoreStepVerifying;

  /// No description provided for @restoreStepRebuilding.
  ///
  /// In ar, this message translates to:
  /// **'إعادة بناء الجداول والتذكيرات'**
  String get restoreStepRebuilding;

  /// No description provided for @backupCreateFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر إنشاء النسخة الاحتياطية'**
  String get backupCreateFailed;

  /// No description provided for @backupRestoreTitle.
  ///
  /// In ar, this message translates to:
  /// **'استعادة نسخة احتياطية'**
  String get backupRestoreTitle;

  /// No description provided for @backupRestoreQuestion.
  ///
  /// In ar, this message translates to:
  /// **'هل تريد استعادة هذه البيانات؟'**
  String get backupRestoreQuestion;

  /// No description provided for @backupRestoreFrom.
  ///
  /// In ar, this message translates to:
  /// **'نسخة احتياطية من'**
  String get backupRestoreFrom;

  /// No description provided for @backupRestoreCounts.
  ///
  /// In ar, this message translates to:
  /// **'{people, plural, zero{{people} أشخاص} one{شخص واحد} two{شخصان} few{{people} أشخاص} many{{people} شخصًا} other{{people} شخص}} · {debts, plural, zero{{debts} ديون} one{دين واحد} two{دينان} few{{debts} ديون} many{{debts} دينًا} other{{debts} دين}} · {payments, plural, zero{{payments} دفعات} one{دفعة واحدة} two{دفعتان} few{{payments} دفعات} many{{payments} دفعة} other{{payments} دفعة}}'**
  String backupRestoreCounts(int people, int debts, int payments);

  /// No description provided for @backupRestoreMore.
  ///
  /// In ar, this message translates to:
  /// **'{obligations, plural, zero{{obligations} التزامات} one{التزام واحد} two{التزامان} few{{obligations} التزامات} many{{obligations} التزامًا} other{{obligations} التزام}} · {reminders, plural, zero{{reminders} تذكيرات} one{تذكير واحد} two{تذكيران} few{{reminders} تذكيرات} many{{reminders} تذكيرًا} other{{reminders} تذكير}} · {links, plural, zero{{links} ارتباطات} one{ارتباط واحد} two{ارتباطان} few{{links} ارتباطات} many{{links} ارتباطًا} other{{links} ارتباط}}'**
  String backupRestoreMore(int obligations, int reminders, int links);

  /// No description provided for @backupRestoreLastChange.
  ///
  /// In ar, this message translates to:
  /// **'آخر تغيير في النسخة: {when}'**
  String backupRestoreLastChange(String when);

  /// No description provided for @backupRestoreCurrencies.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{العملة: {codes}} other{العملات: {codes}}}'**
  String backupRestoreCurrencies(String codes, int count);

  /// No description provided for @backupRestoreUnencrypted.
  ///
  /// In ar, this message translates to:
  /// **'الملف غير مشفّر: من يفتحه يقرأ بياناتك.'**
  String get backupRestoreUnencrypted;

  /// No description provided for @backupRestoreSafetyNote.
  ///
  /// In ar, this message translates to:
  /// **'سيأخذ Dhimmah نسخة من بياناتك الحالية قبل الاستعادة، ويمكنك الرجوع إليها.'**
  String get backupRestoreSafetyNote;

  /// No description provided for @backupRestoreMode.
  ///
  /// In ar, this message translates to:
  /// **'طريقة الاستعادة'**
  String get backupRestoreMode;

  /// No description provided for @backupModeReplace.
  ///
  /// In ar, this message translates to:
  /// **'استبدال'**
  String get backupModeReplace;

  /// No description provided for @backupModeReplaceBody.
  ///
  /// In ar, this message translates to:
  /// **'تصبح النسخة هي بياناتك، وتُستبدل بيانات الجهاز الحالية.'**
  String get backupModeReplaceBody;

  /// No description provided for @backupModeMerge.
  ///
  /// In ar, this message translates to:
  /// **'دمج'**
  String get backupModeMerge;

  /// No description provided for @backupModeMergeBody.
  ///
  /// In ar, this message translates to:
  /// **'تُضاف السجلات الجديدة، وتُحدَّث الأحدث، ويُبلَّغ عن أي تعارض بدل تخمينه.'**
  String get backupModeMergeBody;

  /// No description provided for @backupRestoreConfirm.
  ///
  /// In ar, this message translates to:
  /// **'استعادة'**
  String get backupRestoreConfirm;

  /// No description provided for @backupRestoreDone.
  ///
  /// In ar, this message translates to:
  /// **'تمت الاستعادة بنجاح'**
  String get backupRestoreDone;

  /// No description provided for @backupRestoreSummary.
  ///
  /// In ar, this message translates to:
  /// **'{people, plural, zero{{people} أشخاص} one{شخص واحد} two{شخصان} few{{people} أشخاص} many{{people} شخصًا} other{{people} شخص}} · {debts, plural, zero{{debts} ديون} one{دين واحد} two{دينان} few{{debts} ديون} many{{debts} دينًا} other{{debts} دين}} · {payments, plural, zero{{payments} دفعات} one{دفعة واحدة} two{دفعتان} few{{payments} دفعات} many{{payments} دفعة} other{{payments} دفعة}}'**
  String backupRestoreSummary(int people, int debts, int payments);

  /// No description provided for @backupRestoreSkipped.
  ///
  /// In ar, this message translates to:
  /// **'سجلات موجودة أصلًا: {count}'**
  String backupRestoreSkipped(int count);

  /// No description provided for @backupRestoreConflictsTitle.
  ///
  /// In ar, this message translates to:
  /// **'سجلات تحتاج مراجعة'**
  String get backupRestoreConflictsTitle;

  /// No description provided for @backupRestoreConflictsBody.
  ///
  /// In ar, this message translates to:
  /// **'{count, plural, =1{سجل واحد مختلف في النسخة ولم يكن أحدث؛ أُبقي الموجود عندك.} other{{count} سجلًا مختلفة في النسخة ولم تكن أحدث؛ أُبقي الموجود عندك.}}'**
  String backupRestoreConflictsBody(int count);

  /// No description provided for @backupRestoreFailed.
  ///
  /// In ar, this message translates to:
  /// **'تعذّرت الاستعادة، ولم تتغيّر بياناتك.'**
  String get backupRestoreFailed;

  /// No description provided for @backupRestoreInvalid.
  ///
  /// In ar, this message translates to:
  /// **'تعذّر استعادة النسخة لأن الملف غير صالح أو تالف.'**
  String get backupRestoreInvalid;

  /// No description provided for @backupRestoreNotOurs.
  ///
  /// In ar, this message translates to:
  /// **'هذا الملف ليس نسخة احتياطية صالحة لـDhimmah.'**
  String get backupRestoreNotOurs;

  /// No description provided for @backupRestoreTooNew.
  ///
  /// In ar, this message translates to:
  /// **'هذه النسخة من إصدار أحدث من التطبيق. حدّث Dhimmah ثم حاول مرة أخرى.'**
  String get backupRestoreTooNew;

  /// No description provided for @backupRestoreContinue.
  ///
  /// In ar, this message translates to:
  /// **'متابعة إلى Dhimmah'**
  String get backupRestoreContinue;

  /// No description provided for @backupFoundTitle.
  ///
  /// In ar, this message translates to:
  /// **'وجدنا نسخة احتياطية'**
  String get backupFoundTitle;

  /// No description provided for @backupFoundBody.
  ///
  /// In ar, this message translates to:
  /// **'لا توجد بيانات على هذا الجهاز، وهناك نسخة محفوظة يمكن استعادتها.'**
  String get backupFoundBody;

  /// No description provided for @backupPrivacyTitle.
  ///
  /// In ar, this message translates to:
  /// **'أين تُحفظ النسخ؟'**
  String get backupPrivacyTitle;

  /// No description provided for @backupPrivacyBody.
  ///
  /// In ar, this message translates to:
  /// **'النسخ التلقائية داخل التطبيق ولا يقرؤها غيره. وعند المشاركة تختار أنت المكان — الملفات أو Drive أو غيره — والملف غير مشفّر. حذف التطبيق يحذف النسخ التي داخله، فاحتفظ بنسخة خارج الجهاز إن كانت بياناتك تهمّك.'**
  String get backupPrivacyBody;

  /// No description provided for @backupSeparateFromExport.
  ///
  /// In ar, this message translates to:
  /// **'التصدير (CSV وJSON) للقراءة والتحليل، ولا يُستخدم للاستعادة. النسخة الاحتياطية هي التي تُستعاد.'**
  String get backupSeparateFromExport;

  /// No description provided for @currencyNameAed.
  ///
  /// In ar, this message translates to:
  /// **'درهم إماراتي'**
  String get currencyNameAed;

  /// No description provided for @currencyNameEur.
  ///
  /// In ar, this message translates to:
  /// **'يورو'**
  String get currencyNameEur;

  /// No description provided for @currencyNameGbp.
  ///
  /// In ar, this message translates to:
  /// **'جنيه إسترليني'**
  String get currencyNameGbp;

  /// No description provided for @currencyNameInr.
  ///
  /// In ar, this message translates to:
  /// **'روبية هندية'**
  String get currencyNameInr;

  /// No description provided for @currencyNameSar.
  ///
  /// In ar, this message translates to:
  /// **'ريال سعودي'**
  String get currencyNameSar;

  /// No description provided for @currencyNameUsd.
  ///
  /// In ar, this message translates to:
  /// **'دولار أمريكي'**
  String get currencyNameUsd;

  /// No description provided for @currencyNameYer.
  ///
  /// In ar, this message translates to:
  /// **'ريال يمني'**
  String get currencyNameYer;

  /// No description provided for @languageDevice.
  ///
  /// In ar, this message translates to:
  /// **'لغة الجهاز'**
  String get languageDevice;

  /// No description provided for @languageDeviceCurrently.
  ///
  /// In ar, this message translates to:
  /// **'حاليًا: {language}'**
  String languageDeviceCurrently(String language);

  /// No description provided for @languageFollowsDevice.
  ///
  /// In ar, this message translates to:
  /// **'تتبع لغة جهازك'**
  String get languageFollowsDevice;

  /// No description provided for @onboardingChangeLanguage.
  ///
  /// In ar, this message translates to:
  /// **'تغيير اللغة'**
  String get onboardingChangeLanguage;

  /// No description provided for @onboardingChangeLater.
  ///
  /// In ar, this message translates to:
  /// **'يمكنك تغيير ذلك في أي وقت من الإعدادات.'**
  String get onboardingChangeLater;

  /// No description provided for @onboardingFeatureBooksBody.
  ///
  /// In ar, this message translates to:
  /// **'سجّل الديون والدفعات الجزئية والالتزامات الشهرية، ويُحسب المتبقي تلقائيًا.'**
  String get onboardingFeatureBooksBody;

  /// No description provided for @onboardingFeatureBooksTitle.
  ///
  /// In ar, this message translates to:
  /// **'ما لك وما عليك في دفتر واحد'**
  String get onboardingFeatureBooksTitle;

  /// No description provided for @onboardingFeaturePrivateBody.
  ///
  /// In ar, this message translates to:
  /// **'يعمل بدون إنترنت، ولا يُرفع شيء إلى أي خادم.'**
  String get onboardingFeaturePrivateBody;

  /// No description provided for @onboardingFeatureRemindersBody.
  ///
  /// In ar, this message translates to:
  /// **'تنبيه قبل موعد الاستحقاق، وملخص لذمتك في آخر كل شهر.'**
  String get onboardingFeatureRemindersBody;

  /// No description provided for @onboardingFeatureRemindersTitle.
  ///
  /// In ar, this message translates to:
  /// **'تذكير قبل كل موعد'**
  String get onboardingFeatureRemindersTitle;

  /// No description provided for @onboardingMonthEndWhen.
  ///
  /// In ar, this message translates to:
  /// **'{day}، الساعة {time}'**
  String onboardingMonthEndWhen(String day, String time);

  /// No description provided for @onboardingReminderTime.
  ///
  /// In ar, this message translates to:
  /// **'الساعة {time}'**
  String onboardingReminderTime(String time);

  /// No description provided for @onboardingStepOf.
  ///
  /// In ar, this message translates to:
  /// **'الخطوة {step} من {total}'**
  String onboardingStepOf(int step, int total);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
