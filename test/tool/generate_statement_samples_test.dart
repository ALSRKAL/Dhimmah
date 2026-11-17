import 'dart:io';
import 'dart:typed_data';

import 'package:dhimmah/core/brand/brand_mark.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/notifications/notification_composer.dart';
import 'package:dhimmah/core/notifications/notification_service.dart';
import 'package:dhimmah/core/pdf/statement_document.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/core/utils/dates.dart';
import 'package:dhimmah/data/database/app_database.dart';
import 'package:dhimmah/data/read_models/ledger_queries.dart';
import 'package:dhimmah/data/repositories/activity_repository_impl.dart';
import 'package:dhimmah/data/repositories/debt_repository_impl.dart';
import 'package:dhimmah/data/repositories/income_repository_impl.dart';
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/debt.dart';
import 'package:dhimmah/domain/entities/drafts.dart';
import 'package:dhimmah/domain/entities/ledger_views.dart';
import 'package:dhimmah/domain/entities/payment.dart';
import 'package:dhimmah/domain/entities/person.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/domain/enums/recurrence.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Renders the statement sample matrix to `build/qa/`, in both languages, so
/// the layout can be inspected as a real document. Not part of the normal test
/// run.
///
///   flutter test test/tool/generate_statement_samples_test.dart
///   for f in build/qa/*.pdf; do pdftoppm -r 110 -png "$f" "${f%.pdf}"; done
///
/// Every row of `PDF-REDESIGN.md` §11 is a sample here. The signature sample is
/// gone — the developer removed the signature box (ق13) — and `clearance` and
/// `period` are new.
void main() {
  // Asset loading needs the Flutter binding, and date formatting needs the
  // locale data — the app does both at startup.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes statement samples', () async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    final Directory out = Directory('build/qa');
    await out.create(recursive: true);
    // The matrix is the folder. A sample renamed in a previous run must not
    // linger and be reviewed as if it were current.
    for (final FileSystemEntity entity in out.listSync()) {
      if (entity is File && entity.path.endsWith('.pdf')) entity.deleteSync();
    }

    final ByteData regular =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final ByteData semiBold =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf');
    final BrandMark mark = await BrandMark.load();

    final AppDatabase db = AppDatabase.memory();
    final LedgerService service = _service(db);
    final DateTime today = dateOnly(DateTime.now());

    Future<Person> person(String name) =>
        service.createPerson(PersonDraft(name: name));

    // --- A person with several debts, a long history, and both directions --
    final Person ahmed = await person('أحمد محمد عبد الرحمن الشامي');

    final Debt main = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'سلفة شخصية',
        principalMinor: 2500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -120),
        dueAt: addDays(today, 20),
        note: 'سلفة شخصية لظرف طارئ، تُسدَّد على دفعات شهرية.',
        reminderLeads: const <ReminderLead>[ReminderLead.oneWeekBefore],
      ),
    );
    // A long payment history, so the table runs onto a second page.
    for (int i = 0; i < 22; i++) {
      await service.recordPayment(
        main.id,
        PaymentDraft(
          amountMinor: 50000,
          paidAt: addDays(today, -110 + i * 5),
          note: i % 3 == 0 ? 'دفعة شهرية' : null,
        ),
      );
    }

    final Debt second = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'قرض سيارة',
        principalMinor: 3500000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -200),
        dueAt: addDays(today, -6),
      ),
    );
    await service.recordPayment(
      second.id,
      PaymentDraft(amountMinor: 1200000, paidAt: addDays(today, -40)),
    );

    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[ahmed.id],
        title: 'مشاركة في مصاريف السفر',
        principalMinor: 850000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -60),
        dueAt: addDays(today, 3),
      ),
    );
    // A different currency, which must never be folded into the same totals.
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[ahmed.id],
        title: 'تحويل بالدولار',
        principalMinor: 120000,
        currency: AppCurrency.usd,
        issuedAt: addDays(today, -10),
        dueAt: addDays(today, 30),
      ),
    );

    // --- Settled: one debt, paid in full (the clearance) -------------------
    final Person settled = await person('خالد العلي');
    final Debt paid = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[settled.id],
        title: 'فاتورة خدمات',
        principalMinor: 900000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -30),
        dueAt: addDays(today, -5),
      ),
    );
    await service.recordPayment(
      paid.id,
      PaymentDraft(amountMinor: 900000, paidAt: addDays(today, -2)),
    );

    // --- One debt, never paid ---------------------------------------------
    final Person oneDebt = await person('نورة السالم');
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[oneDebt.id],
        title: 'سلفة قصيرة',
        principalMinor: 750000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -15),
        dueAt: addDays(today, 15),
      ),
    );

    // --- Three debts, all the same side -----------------------------------
    final Person three = await person('سارة الحربي');
    const List<(String, int)> threeDebts = <(String, int)>[
      ('إيجار المكتب', 450000),
      ('فاتورة كهرباء', 120000),
      ('سلفة نقدية', 300000),
    ];
    for (final (String title, int amount) in threeDebts) {
      await service.createDebt(
        DebtDraft(
          direction: DebtDirection.owedToMe,
          personIds: <String>[three.id],
          title: title,
          principalMinor: amount,
          currency: AppCurrency.inr,
          issuedAt: addDays(today, -40),
          dueAt: addDays(today, 10),
        ),
      );
    }

    // --- Sixty movements: three pages, a repeating header ------------------
    final Person busy = await person('مازن القاسمي');
    final Debt busyDebt = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[busy.id],
        title: 'تمويل سيارة',
        principalMinor: 3000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -300),
        dueAt: addDays(today, 60),
      ),
    );
    for (int i = 0; i < 59; i++) {
      await service.recordPayment(
        busyDebt.id,
        PaymentDraft(
          amountMinor: 25000,
          paidAt: addDays(today, -295 + i * 5),
        ),
      );
    }

    // --- A name and a title that hardly fit -------------------------------
    final Person longNames = await person(
      'عبد الرحمن محمد أحمد السيد الحسيني الشامي الكيلاني الجبوري',
    );
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[longNames.id],
        title: 'مشاركة في مصاريف رحلة الصيف الطويلة إلى الجنوب مع العائلة والأصدقاء والزملاء',
        principalMinor: 1234500,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -25),
        dueAt: addDays(today, 25),
      ),
    );

    // --- A twelve-digit amount --------------------------------------------
    final Person big = await person('بدر العتيبي');
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.iOwe,
        personIds: <String>[big.id],
        title: 'قرض عقاري',
        principalMinor: 100000000000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -500),
        dueAt: addDays(today, 365),
      ),
    );

    // --- A Latin name inside an Arabic document ---------------------------
    final Person latin = await person('Michael Anderson');
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[latin.id],
        title: 'Consulting invoice — October',
        principalMinor: 450000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -12),
        dueAt: addDays(today, 12),
      ),
    );

    // --- One open debt and one settled, so the scope hides something ------
    final Person filtered = await person('ليلى النعيمي');
    await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[filtered.id],
        title: 'سلفة مفتوحة',
        principalMinor: 300000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -20),
        dueAt: addDays(today, 20),
      ),
    );
    final Debt hidden = await service.createDebt(
      DebtDraft(
        direction: DebtDirection.owedToMe,
        personIds: <String>[filtered.id],
        title: 'دين مسدَّد',
        principalMinor: 100000,
        currency: AppCurrency.inr,
        issuedAt: addDays(today, -50),
        dueAt: addDays(today, -10),
      ),
    );
    await service.recordPayment(
      hidden.id,
      PaymentDraft(amountMinor: 100000, paidAt: addDays(today, -5)),
    );

    final LedgerQueries queries = _queries(db);

    Future<void> write({
      required Person target,
      required AppLanguage language,
      required String fileName,
      StatementOptions options = const StatementOptions(),
      AppCurrency currency = AppCurrency.inr,
    }) async {
      final PersonLedger? ledger = await queries
          .watchPersonLedger(
            target.id,
            dueSoonWindowDays: 7,
            asOf: today,
          )
          .first;
      expect(ledger, isNotNull);

      final AppLocalizations l10n = lookupAppLocalizations(Locale(language.code));
      final AppFormatting formatting = AppFormatting(
        language: language,
        numerals: NumeralsStyle.latin,
        defaultCurrency: currency,
        localizations: l10n,
      );

      final List<Payment> payments = await _paymentsFor(queries, ledger!);
      final StatementData data = StatementService(
        localizations: l10n,
        // The document language is the formatting's, so both languages can be
        // generated in one run.
        formatting: formatting,
      ).buildData(
        ledger: ledger,
        payments: payments,
        currency: currency,
        now: today,
        options: options,
      );

      final Uint8List bytes = await StatementDocument(
        data: data,
        localizations: l10n,
        formatting: formatting,
        regularFont: regular,
        semiBoldFont: semiBold,
        mark: mark,
      ).build().save();

      await File('${out.path}/$fileName').writeAsBytes(bytes, flush: true);
      // ignore: avoid_print
      print('WROTE ${out.path}/$fileName  (${bytes.length} bytes) '
          'name=${data.fileName} number=${data.documentNumber} '
          'status=${data.status.name} entries=${data.entries.length} '
          'clearance=${data.isClearance}');
    }

    /// Both languages of one matrix row.
    Future<void> both({
      required Person target,
      required String sample,
      StatementOptions options = const StatementOptions(scope: StatementScope.all),
      AppCurrency currency = AppCurrency.inr,
    }) async {
      for (final AppLanguage language in AppLanguage.values) {
        await write(
          target: target,
          language: language,
          fileName: '${language.code}-$sample.pdf',
          options: options,
          currency: currency,
        );
      }
    }

    await both(
      target: oneDebt,
      sample: 'one-debt-no-payments',
      options: const StatementOptions(),
    );
    // One debt, part paid: what a statement opened from a debt's page looks
    // like.
    await both(
      target: ahmed,
      sample: 'one-debt-partial',
      options: StatementOptions(
        scope: StatementScope.selected,
        selectedDebtIds: <String>{second.id},
      ),
    );
    // A settled account. With the default scope there would be no row to
    // print; this is what the user gets after choosing "all", and it is the
    // clearance.
    await both(target: settled, sample: 'settled');
    await both(target: three, sample: 'three-debts-one-side');
    // The person with both directions: the legend, the side column, the net.
    await both(
      target: ahmed,
      sample: 'mixed',
      options: const StatementOptions(includePhone: true, includeNotes: true),
    );
    await both(target: busy, sample: 'sixty-movements');
    // A bounded period: the movements inside it, and the balance the account
    // opened it with.
    await both(
      target: ahmed,
      sample: 'period',
      options: StatementOptions(
        scope: StatementScope.all,
        periodFrom: addDays(today, -100),
        periodTo: addDays(today, -10),
      ),
    );
    await both(target: longNames, sample: 'long-names');
    await both(target: big, sample: 'big-amounts');
    // A Latin name in an Arabic document, and the reverse is covered by every
    // English sample of an Arabic-named person (`en-mixed`).
    await both(target: latin, sample: 'latin-in-arabic');
    await both(
      target: ahmed,
      sample: 'with-issuer',
      options: const StatementOptions(
        includePhone: true,
        issuerName: 'محمد السركال',
      ),
    );
    // The scope hides a settled debt, and the line says so.
    await both(
      target: filtered,
      sample: 'filtered-with-hidden',
      options: const StatementOptions(),
    );

    // --- Receipts: one payment, both ways round and in both languages -----
    Future<void> writeReceipt({
      required Person target,
      required Debt debt,
      required AppLanguage language,
      required String fileName,
      String issuerName = '',
    }) async {
      final PersonLedger? ledger = await queries
          .watchPersonLedger(target.id, dueSoonWindowDays: 7, asOf: today)
          .first;
      final DebtView view = ledger!.debts.firstWhere(
        (DebtView candidate) => candidate.debt.id == debt.id,
      );
      final Payment payment =
          (await queries.payments.forDebt(debt.id)).first;
      final AppLocalizations l10n =
          lookupAppLocalizations(Locale(language.code));
      final AppFormatting formatting = AppFormatting(
        language: language,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      );
      final ReceiptData data = StatementService(
        localizations: l10n,
        formatting: formatting,
      ).buildReceipt(
        parts: <({DebtView view, Payment payment})>[
          (view: view, payment: payment),
        ],
        includeNote: true,
        personName: target.name,
        now: today,
        issuerName: issuerName,
      );
      final Uint8List bytes = await ReceiptDocument(
        data: data,
        localizations: l10n,
        formatting: formatting,
        regularFont: regular,
        semiBoldFont: semiBold,
        mark: mark,
      ).build().save();
      await File('${out.path}/$fileName').writeAsBytes(bytes, flush: true);
      // ignore: avoid_print
      print('WROTE ${out.path}/$fileName  (${bytes.length} bytes) '
          'name=${data.fileName} number=${data.number}');
    }

    for (final AppLanguage language in AppLanguage.values) {
      await writeReceipt(
        target: settled,
        debt: paid,
        language: language,
        fileName: '${language.code}-receipt-in.pdf',
        issuerName: 'محمد السركال',
      );
      await writeReceipt(
        target: ahmed,
        debt: second,
        language: language,
        fileName: '${language.code}-receipt-out.pdf',
      );
    }

    await db.close();
  });
}

Future<List<Payment>> _paymentsFor(LedgerQueries queries, PersonLedger ledger) async {
  final List<Payment> out = <Payment>[];
  for (final DebtView view in ledger.debts) {
    out.addAll(await queries.payments.forDebt(view.debt.id));
  }
  return out;
}

LedgerQueries _queries(AppDatabase db) => LedgerQueries(
      database: db,
      people: PersonRepositoryImpl(db),
      debts: DebtRepositoryImpl(db),
      payments: PaymentRepositoryImpl(db),
      obligations: ObligationRepositoryImpl(db),
      incomes: IncomeRepositoryImpl(db),
      reminders: ReminderRepositoryImpl(db),
      activity: ActivityRepositoryImpl(db),
    );

LedgerService _service(AppDatabase db) {
  final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
  return LedgerService(
    database: db,
    people: PersonRepositoryImpl(db),
    debts: DebtRepositoryImpl(db),
    payments: PaymentRepositoryImpl(db),
    obligations: ObligationRepositoryImpl(db),
    incomes: IncomeRepositoryImpl(db),
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
