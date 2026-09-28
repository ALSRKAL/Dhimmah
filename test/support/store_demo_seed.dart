import 'dart:ui' show Locale;

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
import 'package:dhimmah/domain/entities/obligation.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/obligation_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';

/// The demonstration dataset the app is reviewed with.
///
/// Built through the real service layer — the same `LedgerService` calls a
/// person makes — so what a screen shows here is what that screen shows for
/// real data, not a fixture the widgets were tuned to. The same story exists in
/// Arabic and in English, so the store captures of either language photograph
/// the same ledger.
///
/// Used by `test/tool/seed_demo_data_test.dart` (a review database on the host)
/// and by the store-capture integration test (the app's own database on the
/// device). The function leaves the database open: the caller owns it.
///
/// [currency] is the ledger's own currency, and every record is written in it.
/// The store listings are photographed in dollars (English) and Yemeni riyals
/// (Arabic); see [_minor] for how one set of figures serves both.
///
/// What the dataset contains.
///
/// The counts live beside the records that produce them so a test that opens a
/// file seeded from this dataset does not have to state the shape a second time
/// and drift from it — which is exactly how the backward-compatibility test came
/// to expect three people from a seed that writes five, and to build a statement
/// in a currency the seed never writes.
const ({int people, int debts, int payments, int obligations}) storeDemoShape = (
  people: 5,
  debts: 8,
  payments: 3,
  obligations: 4,
);

/// The currency the dataset is written in.
///
/// Named once and used as the default below, so a test that reads a seeded file
/// asks for a statement in the currency the file is actually in.
const AppCurrency storeDemoCurrency = AppCurrency.usd;

/// All names, notes and amounts are fictional.
Future<void> seedStoreDemoData(
  AppDatabase db, {
  required AppLanguage language,
  AppThemeMode themeMode = AppThemeMode.light,
  AppCurrency currency = storeDemoCurrency,
}) async {
  final DateTime today = dateOnly(DateTime.now());
  final AppLocalizations localizations =
      lookupAppLocalizations(Locale(language.code));
  final AppFormatting formatting = AppFormatting(
    language: language,
    numerals: NumeralsStyle.latin,
    defaultCurrency: currency,
    localizations: localizations,
  );
  final LedgerService service = LedgerService(
    database: db,
    people: PersonRepositoryImpl(db),
    debts: DebtRepositoryImpl(db),
    payments: PaymentRepositoryImpl(db),
    obligations: ObligationRepositoryImpl(db),
    reminders: ReminderRepositoryImpl(db),
    activity: ActivityRepositoryImpl(db),
    settings: SettingsRepositoryImpl(db),
    notifications: NotificationService(),
    localizations: () => localizations,
    composer: () => NotificationComposer(
      localizations: localizations,
      formatting: formatting,
    ),
    clock: DateTime.now,
  );

  /// A figure as it is written for this ledger: `minor(1500)` is $1,500.00, or
  /// 375,000.00 ﷼ at the 250-to-the-dollar rate the dataset is written at.
  int minor(int units) => units * 100 * (currency == AppCurrency.yer ? 250 : 1);

  final StoreCopy copy = StoreCopy.forLanguage(language);

  // Start from the state a real user would be in after onboarding.
  await SettingsRepositoryImpl(db).save(
    AppSettings.initial.copyWith(
      onboardingCompleted: true,
      defaultCurrency: currency,
      language: language,
      dueSoonWindowDays: 7,
      themeMode: themeMode,
    ),
  );

  Future<Person> person(String name, int color) => service.createPerson(
        PersonDraft(name: name, colorIndex: color),
      );

  final Person ahmed = await person(copy.personNames[0], 0);
  final Person khalid = await person(copy.personNames[1], 3);
  final Person mohammed = await person(copy.personNames[2], 2);
  final Person ali = await person(copy.personNames[3], 4);
  final Person office = await person(copy.personNames[4], 5);

  // --- Money I owe ---------------------------------------------------------
  // The record the payment screen is photographed on: 1,500 borrowed, 500
  // repaid, 1,000 still owed.
  final Debt advance = await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[khalid.id],
      title: copy.advanceTitle,
      principalMinor: minor(1500),
      currency: currency,
      issuedAt: addDays(today, -40),
      dueAt: addDays(today, 3),
      reminderLeads: const <ReminderLead>[
        ReminderLead.oneDayBefore,
        ReminderLead.threeDaysBefore,
      ],
      note: copy.advanceNote,
    ),
  );
  await service.recordPayment(
    advance.id,
    PaymentDraft(
      amountMinor: minor(500),
      paidAt: addDays(today, -12),
      note: copy.firstPaymentNote,
    ),
  );

  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[ahmed.id],
      title: copy.carLoanTitle,
      principalMinor: minor(3500),
      currency: currency,
      issuedAt: addDays(today, -90),
      dueAt: addDays(today, -4),
      reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
    ),
  );
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[office.id],
      title: copy.feesTitle,
      principalMinor: minor(850),
      currency: currency,
      issuedAt: addDays(today, -20),
      dueAt: addDays(today, 12),
    ),
  );

  // One record, two people: each of them reads it on their own page as an
  // ordinary debt of theirs, which is how the app has always behaved. No due
  // date, so it also carries the "ongoing" state.
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.iOwe,
      personIds: <String>[mohammed.id, ali.id],
      title: copy.sharedExpensesTitle,
      principalMinor: minor(320),
      currency: currency,
      issuedAt: addDays(today, -60),
    ),
  );

  // --- Money owed to me ----------------------------------------------------
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personIds: <String>[ahmed.id],
      title: copy.loanTitle,
      principalMinor: minor(1200),
      currency: currency,
      issuedAt: addDays(today, -30),
      dueAt: addDays(today, 1),
      reminderLeads: const <ReminderLead>[ReminderLead.onDueDate],
    ),
  );
  final Debt settled = await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personIds: <String>[office.id],
      title: copy.utilityBillTitle,
      principalMinor: minor(3000),
      currency: currency,
      issuedAt: addDays(today, -50),
      dueAt: addDays(today, -10),
    ),
  );
  await service.recordPayment(
    settled.id,
    PaymentDraft(
      amountMinor: minor(3000),
      paidAt: addDays(today, -8),
      note: copy.paidInFullNote,
    ),
  );
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personIds: <String>[khalid.id],
      title: copy.tripShareTitle,
      principalMinor: minor(750),
      currency: currency,
      issuedAt: addDays(today, -5),
      dueAt: addDays(today, 20),
    ),
  );
  await service.createDebt(
    DebtDraft(
      direction: DebtDirection.owedToMe,
      personIds: <String>[ali.id],
      title: copy.furnitureTitle,
      principalMinor: minor(450),
      currency: currency,
      issuedAt: addDays(today, -14),
      dueAt: addDays(today, 9),
    ),
  );

  // --- Recurring commitments ------------------------------------------------
  await service.createObligation(
    ObligationDraft(
      name: copy.rentObligation,
      category: ObligationCategory.housing,
      amountMinor: minor(1200),
      currency: currency,
      frequency: RecurrenceFrequency.monthly,
      startAt: DateTime(today.year, today.month),
      dayOfMonth: 1,
      reminderLeads: const <ReminderLead>[ReminderLead.oneDayBefore],
    ),
  );
  await service.createObligation(
    ObligationDraft(
      name: copy.internetObligation,
      category: ObligationCategory.telecom,
      amountMinor: minor(120),
      currency: currency,
      frequency: RecurrenceFrequency.monthly,
      startAt: DateTime(today.year, today.month, 5),
      dayOfMonth: 5,
      reminderLeads: const <ReminderLead>[ReminderLead.twoDaysBefore],
    ),
  );
  await service.createObligation(
    ObligationDraft(
      name: copy.carInstallmentObligation,
      category: ObligationCategory.installment,
      amountMinor: minor(1800),
      currency: currency,
      frequency: RecurrenceFrequency.monthly,
      startAt: DateTime(today.year, today.month, 15),
      dayOfMonth: 15,
    ),
  );
  await service.createObligation(
    ObligationDraft(
      name: copy.gymObligation,
      category: ObligationCategory.subscription,
      amountMinor: minor(40),
      currency: currency,
      frequency: RecurrenceFrequency.monthly,
      startAt: DateTime(today.year, today.month, 20),
      dayOfMonth: 20,
    ),
  );

  // Pay the month's rent, so history and an upcoming period both exist.
  await service.ensureOccurrences();
  final ObligationInstance? due = await _firstPayable(db);
  if (due != null) await service.markObligationPaid(due);

  // --- Reminders ------------------------------------------------------------
  await service.createReminder(
    ReminderDraft(
      title: copy.insuranceReminder,
      dueAt: addDays(today, 4),
      note: copy.insuranceReminderNote,
    ),
  );
  await service.createReminder(
    ReminderDraft(
      title: copy.bankStatementReminder,
      dueAt: addDays(today, 1),
    ),
  );
  await service.createReminder(
    ReminderDraft(title: copy.taxReportReminder, dueAt: addDays(today, 21)),
  );
}

/// The first obligation period that still needs paying.
Future<ObligationInstance?> _firstPayable(AppDatabase db) async {
  final ObligationRepositoryImpl obligations = ObligationRepositoryImpl(db);
  for (final Obligation obligation in await obligations.getAll()) {
    for (final ObligationOccurrence occurrence
        in await obligations.occurrencesFor(obligation.id)) {
      if (occurrence.isPayable) {
        return ObligationInstance(obligation: obligation, occurrence: occurrence);
      }
    }
  }
  return null;
}

/// Every string the dataset carries, in both languages.
///
/// Names, titles and notes are data — the app renders them exactly as given —
/// so each language's capture photographs a ledger written in that language.
class StoreCopy {
  const StoreCopy._(this._v);

  factory StoreCopy.forLanguage(AppLanguage language) =>
      language == AppLanguage.arabic ? _ar : _en;

  static const StoreCopy _ar = StoreCopy._(<String, String>{
    'person0': 'أحمد محمد',
    'person1': 'خالد العلي',
    'person2': 'محمد صالح',
    'person3': 'علي حسن',
    'person4': 'مكتب المحاسبة',
    'advanceTitle': 'سلفة',
    'advanceNote': 'سلفة شخصية لظرف طارئ',
    'firstPaymentNote': 'دفعة أولى',
    'carLoanTitle': 'قرض سيارة',
    'feesTitle': 'أتعاب',
    'sharedExpensesTitle': 'مصاريف مشتركة',
    'loanTitle': 'قرض',
    'utilityBillTitle': 'فاتورة خدمات',
    'paidInFullNote': 'سُدّد بالكامل',
    'tripShareTitle': 'مشاركة في رحلة',
    'furnitureTitle': 'قسط أثاث',
    'rentObligation': 'إيجار المنزل',
    'internetObligation': 'فاتورة الإنترنت',
    'carInstallmentObligation': 'قسط السيارة',
    'gymObligation': 'اشتراك الصالة الرياضية',
    'insuranceReminder': 'تجديد التأمين الطبي',
    'insuranceReminderNote': 'قبل انتهاء المهلة بأسبوع',
    'bankStatementReminder': 'مراجعة كشف الحساب البنكي',
    'taxReportReminder': 'تسليم تقرير الضريبة',
  });

  static const StoreCopy _en = StoreCopy._(<String, String>{
    'person0': 'Ahmed Mohammed',
    'person1': 'Khalid Al-Ali',
    'person2': 'Mohammed Saleh',
    'person3': 'Ali Hassan',
    'person4': 'Accounting Office',
    'advanceTitle': 'Advance',
    'advanceNote': 'A personal advance for an emergency',
    'firstPaymentNote': 'First payment',
    'carLoanTitle': 'Car loan',
    'feesTitle': 'Professional fees',
    'sharedExpensesTitle': 'Shared expenses',
    'loanTitle': 'Loan',
    'utilityBillTitle': 'Utility bill',
    'paidInFullNote': 'Paid in full',
    'tripShareTitle': 'Trip share',
    'furnitureTitle': 'Furniture installment',
    'rentObligation': 'Home rent',
    'internetObligation': 'Internet bill',
    'carInstallmentObligation': 'Car installment',
    'gymObligation': 'Gym subscription',
    'insuranceReminder': 'Medical insurance renewal',
    'insuranceReminderNote': 'A week before the deadline',
    'bankStatementReminder': 'Bank statement review',
    'taxReportReminder': 'Tax report submission',
  });

  final Map<String, String> _v;

  List<String> get personNames => <String>[
        _v['person0']!,
        _v['person1']!,
        _v['person2']!,
        _v['person3']!,
        _v['person4']!,
      ];
  String get advanceTitle => _v['advanceTitle']!;
  String get advanceNote => _v['advanceNote']!;
  String get firstPaymentNote => _v['firstPaymentNote']!;
  String get carLoanTitle => _v['carLoanTitle']!;
  String get feesTitle => _v['feesTitle']!;
  String get sharedExpensesTitle => _v['sharedExpensesTitle']!;
  String get loanTitle => _v['loanTitle']!;
  String get utilityBillTitle => _v['utilityBillTitle']!;
  String get paidInFullNote => _v['paidInFullNote']!;
  String get tripShareTitle => _v['tripShareTitle']!;
  String get furnitureTitle => _v['furnitureTitle']!;
  String get rentObligation => _v['rentObligation']!;
  String get internetObligation => _v['internetObligation']!;
  String get carInstallmentObligation => _v['carInstallmentObligation']!;
  String get gymObligation => _v['gymObligation']!;
  String get insuranceReminder => _v['insuranceReminder']!;
  String get insuranceReminderNote => _v['insuranceReminderNote']!;
  String get bankStatementReminder => _v['bankStatementReminder']!;
  String get taxReportReminder => _v['taxReportReminder']!;
}
