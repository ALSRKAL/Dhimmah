import 'dart:typed_data';

import 'package:dhimmah/core/brand/brand_mark.dart';
import 'package:dhimmah/core/formatting/app_formatting.dart';
import 'package:dhimmah/core/money/currency.dart';
import 'package:dhimmah/core/money/money.dart';
import 'package:dhimmah/core/pdf/pdf_text.dart';
import 'package:dhimmah/core/pdf/statement_document.dart';
import 'package:dhimmah/core/pdf/statement_models.dart';
import 'package:dhimmah/domain/enums/debt_enums.dart';
import 'package:dhimmah/domain/enums/preference_enums.dart';
import 'package:dhimmah/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'pdf_inspector.dart';

/// A statement whose account is closed is a clearance.
///
/// The difference is not decoration: a page titled «كشف حساب» with a zero at
/// the bottom still reads as a running account, while a clearance is the
/// document that says the two parties are done. The sentence it carries is the
/// approved wording, and these tests pin that it appears exactly when it is
/// true — and not when a single minor unit is still owed.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ByteData regular;
  late ByteData semiBold;
  late BrandMark mark;

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
    regular =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-Regular.ttf');
    semiBold =
        await rootBundle.load('assets/fonts/IBMPlexSansArabic-SemiBold.ttf');
    mark = await BrandMark.load();
  });

  final DateTime day = DateTime(2026, 11, 15);
  const AppCurrency currency = AppCurrency.inr;

  /// A person whose one debt was recorded and paid in full.
  StatementData data({
    AppLanguage language = AppLanguage.arabic,
    int remainingMinor = 0,
    int lineRemainingMinor = 0,
    bool withDebt = true,
    bool withPeriod = false,
  }) {
    return StatementData(
      documentNumber: 'DHM-20261115-1000-1234',
      generatedAt: day,
      language: language,
      personName: 'أحمد محمد',
      phone: null,
      currency: currency,
      totalMinor: 900000,
      paidMinor: 900000,
      remainingMinor: remainingMinor,
      status: remainingMinor == 0
          ? DebtLifecycleStatus.paid
          : DebtLifecycleStatus.active,
      debts: <StatementDebtLine>[
        if (withDebt)
          StatementDebtLine(
            title: 'فاتورة خدمات',
            direction: DebtDirection.owedToMe,
            principal: const Money(900000, currency),
            paid: const Money(900000, currency),
            remaining: Money(lineRemainingMinor, currency),
            status: lineRemainingMinor == 0
                ? DebtLifecycleStatus.paid
                : DebtLifecycleStatus.active,
            dueAt: DateTime(2026, 11, 10),
          ),
      ],
      entries: <StatementEntry>[
        StatementEntry(
          date: DateTime(2026, 10),
          kind: StatementEntryKind.debtCreated,
          direction: DebtDirection.owedToMe,
          amountMinor: 900000,
          balanceAfterMinor: 900000,
          balanceDirection: DebtDirection.owedToMe,
          currency: currency,
          debtTitle: 'فاتورة خدمات',
        ),
        StatementEntry(
          date: DateTime(2026, 11, 12),
          kind: StatementEntryKind.payment,
          direction: DebtDirection.owedToMe,
          amountMinor: 900000,
          balanceAfterMinor: 0,
          currency: currency,
          debtTitle: 'فاتورة خدمات',
        ),
      ],
      options: withPeriod
          ? StatementOptions(
              scope: StatementScope.all,
              periodFrom: DateTime(2026, 10),
              periodTo: day,
            )
          : const StatementOptions(scope: StatementScope.all),
      closingBalanceMinor:
          withPeriod ? (remainingMinor == 0 ? 0 : remainingMinor) : null,
      periodFrom: withPeriod ? DateTime(2026, 10) : null,
      periodTo: withPeriod ? day : null,
    );
  }

  Future<PdfInspection> render(StatementData data) async {
    final AppLocalizations l10n =
        lookupAppLocalizations(Locale(data.language.code));
    final AppFormatting formatting = AppFormatting(
      language: data.language,
      numerals: NumeralsStyle.latin,
      defaultCurrency: currency,
      localizations: l10n,
    );
    final Uint8List bytes = await StatementDocument(
      data: data,
      localizations: l10n,
      formatting: formatting,
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
    return inspectPdf(bytes);
  }

  /// How a shaped Arabic word is drawn; the renderer places the glyphs of a
  /// right-to-left run in reverse of their shaped order.
  String visual(String logicalWord) =>
      shapeArabic(logicalWord).split('').reversed.join();

  /// Whether [sentence] was drawn at all, word by word.
  ///
  /// It cannot be one run: long Arabic is set word by word, and a sentence of
  /// this length wraps. Every word has to be somewhere on the page. Diacritics
  /// and trailing punctuation are dropped before comparing: the renderer draws
  /// them as separate marks and the inspector decodes them in a different
  /// order from the one they were shaped in.
  bool drew(PdfInspection page, String sentence, {required bool rtl}) {
    String bare(String value) => value
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[.,،]'), '');
    final String all = bare(page.runs.map((PdfRun run) => run.text).join(' '));
    for (final String word in sentence.split(' ')) {
      if (word.isEmpty) continue;
      final String wanted =
          rtl && containsArabic(word) ? visual(word) : word;
      if (!all.contains(bare(wanted))) return false;
    }
    return true;
  }

  group('a clearance', () {
    test('is titled as one, and says nothing is left', () async {
      final StatementData statement = data();
      expect(statement.isClearance, isTrue);
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = await render(statement);

      final String sentence = l10n.reportClearanceSentence(
        AppFormatting(
          language: AppLanguage.arabic,
          numerals: NumeralsStyle.latin,
          defaultCurrency: currency,
          localizations: l10n,
        ).date(day),
      );
      expect(
        drew(page, sentence, rtl: true),
        isTrue,
        reason: 'the approved sentence has to be on the page',
      );
      expect(
        drew(page, l10n.reportClearanceTitle, rtl: true),
        isTrue,
        reason: 'the document is a clearance',
      );
      expect(
        drew(page, l10n.statusPaid, rtl: true),
        isTrue,
        reason: 'and it carries the paid-in-full badge',
      );
      expect(
        drew(page, l10n.reportStatementTitle, rtl: true),
        isFalse,
        reason: 'a clearance is not called a statement',
      );
    });

    test('fits on one page', () async {
      final PdfInspection page = await render(data());
      expect(page.pageCount, 1);
    });

    test('names itself in the file name', () {
      expect(data().fileName, startsWith('Dhimmah_Clearance_'));
      expect(
        data(remainingMinor: 1, lineRemainingMinor: 1).fileName,
        startsWith('Dhimmah_'),
      );
      expect(
        data(remainingMinor: 1, lineRemainingMinor: 1).fileName,
        isNot(contains('Clearance')),
      );
    });

    test('the English clearance carries the English sentence', () async {
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('en'));
      final PdfInspection page =
          await render(data(language: AppLanguage.english));
      final String sentence = l10n.reportClearanceSentence(
        AppFormatting(
          language: AppLanguage.english,
          numerals: NumeralsStyle.latin,
          defaultCurrency: currency,
          localizations: l10n,
        ).date(day),
      );
      expect(drew(page, sentence, rtl: false), isTrue);
      expect(drew(page, l10n.reportClearanceTitle, rtl: false), isTrue);
      // "Debt" appears in the movements table's own column; the phrase that
      // names the document must not.
      expect(
        page.runs.map((PdfRun run) => run.text).join(' '),
        isNot(contains('Debt Statement')),
        reason: 'a clearance is not called a statement',
      );
    });

    test('a period that closed at zero is still a clearance', () async {
      final StatementData statement = data(withPeriod: true);
      expect(statement.isClearance, isTrue);
      final PdfInspection page = await render(statement);
      expect(page.pageCount, 1);
    });
  });

  group('not a clearance', () {
    test('one minor unit left keeps it a statement', () async {
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('ar'));
      final StatementData statement =
          data(remainingMinor: 1, lineRemainingMinor: 1);
      expect(statement.isClearance, isFalse);
      final PdfInspection page = await render(statement);
      expect(drew(page, l10n.reportClearanceTitle, rtl: true), isFalse);
      expect(
        drew(page, 'لا متبقٍّ بين الطرفين', rtl: true),
        isFalse,
        reason: 'the clearance sentence is not on a statement',
      );
      expect(drew(page, l10n.reportStatementTitle, rtl: true), isTrue);
    });

    test('a person with no debt in scope is not a clearance', () async {
      final StatementData statement =
          data(withDebt: false);
      expect(statement.isClearance, isFalse);
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = await render(statement);
      expect(drew(page, l10n.reportClearanceTitle, rtl: true), isFalse);
    });

    test('a period that ended with money owing is a statement', () async {
      final StatementData statement = data(
        withPeriod: true,
      );
      // Paid off inside the period, closed at zero: a clearance. Now make the
      // closing figure non-zero while the records are settled today.
      final StatementData owingPeriod = StatementData(
        documentNumber: statement.documentNumber,
        generatedAt: statement.generatedAt,
        language: statement.language,
        personName: statement.personName,
        phone: null,
        currency: statement.currency,
        totalMinor: statement.totalMinor,
        paidMinor: statement.paidMinor,
        remainingMinor: statement.remainingMinor,
        status: statement.status,
        debts: statement.debts,
        entries: statement.entries.take(1).toList(),
        options: statement.options,
        openingBalanceMinor: 900000,
        closingBalanceMinor: 900000,
        periodFrom: DateTime(2026, 10),
        periodTo: DateTime(2026, 10, 20),
      );
      expect(owingPeriod.isClearance, isFalse);
    });
  });
}
