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
import 'package:dhimmah/data/repositories/obligation_repository_impl.dart';
import 'package:dhimmah/data/repositories/person_repository_impl.dart';
import 'package:dhimmah/data/repositories/reminder_repository_impl.dart';
import 'package:dhimmah/data/repositories/settings_repository_impl.dart';
import 'package:dhimmah/data/services/ledger_service.dart';
import 'package:dhimmah/data/services/statement_service.dart';
import 'package:dhimmah/domain/entities/app_settings.dart';
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


/// Renders statement samples to `build/qa/` so the layout can be inspected as a
/// real document. Not part of the normal test run.
///
///   flutter test test/tool/generate_statement_samples_test.dart
///   pdftoppm -r 110 -png build/qa/*.pdf build/qa/page
///
void main() {
  // Asset loading needs the Flutter binding, and date formatting needs the
  // locale data — the app does both at startup.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('writes statement samples', () async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    final Directory out = Directory('build/qa');
    await out.create(recursive: true);

    final ByteData regular =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    final ByteData semiBold =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf');
    final BrandMark mark = await BrandMark.load();

    final AppDatabase db = AppDatabase.memory();
    final LedgerService service = _service(db);
    final DateTime today = dateOnly(DateTime.now());

    Future<Person> person(String name, {String? phone}) =>
        service.createPerson(PersonDraft(name: name, phone: phone));

    // --- A person with several debts and a long payment history ------------
    final Person ahmed = await person('أحمد محمد عبد الرحمن الشامي',
        phone: '+967 771 234 567');

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

    // A second person: a settled account with no payments at all.
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
        formatting: formatting,
        // The document language follows the caller, not the stored setting, so
        // both languages can be generated in one run.
        settings: AppSettings.initial.copyWith(language: language),
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
          'status=${data.status.name} entries=${data.entries.length}');
    }

    await write(
      target: ahmed,
      language: AppLanguage.arabic,
      fileName: 'ar-multipage.pdf',
      options: const StatementOptions(includeNotes: true, includePhone: true),
    );
    await write(
      target: ahmed,
      language: AppLanguage.english,
      fileName: 'en-multipage.pdf',
      options: const StatementOptions(includeNotes: true, includePhone: true),
    );
    await write(
      target: settled,
      language: AppLanguage.arabic,
      fileName: 'ar-settled.pdf',
    );
    await write(
      target: settled,
      language: AppLanguage.english,
      fileName: 'en-settled.pdf',
    );

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
