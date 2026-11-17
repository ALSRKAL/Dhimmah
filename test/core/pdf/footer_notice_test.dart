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

/// The line the documents carry at the very end.
///
/// A statement is a record of what one side wrote down, not a document the
/// other side signed. The last page says so, once, so a page count is not a
/// promise of agreement that neither party made.
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

  const AppCurrency currency = AppCurrency.inr;
  final DateTime day = DateTime(2026, 11, 15);

  StatementData longStatement({AppLanguage language = AppLanguage.arabic}) {
    return StatementData(
      documentNumber: 'DHM-20261115-1000-1234',
      generatedAt: day,
      language: language,
      personName: 'أحمد محمد عبد الرحمن الشامي',
      phone: null,
      currency: currency,
      totalMinor: 5000000,
      paidMinor: 1200000,
      remainingMinor: 3800000,
      status: DebtLifecycleStatus.active,
      debts: <StatementDebtLine>[
        StatementDebtLine(
          title: 'سلفة شخصية',
          direction: DebtDirection.owedToMe,
          principal: const Money(5000000, currency),
          paid: const Money(1200000, currency),
          remaining: const Money(3800000, currency),
          status: DebtLifecycleStatus.active,
          dueAt: DateTime(2027),
        ),
      ],
      // Enough rows that the document runs to three pages.
      entries: <StatementEntry>[
        for (int i = 0; i < 45; i++)
          StatementEntry(
            date: DateTime(2026).add(Duration(days: i * 3)),
            kind: i.isEven
                ? StatementEntryKind.debtCreated
                : StatementEntryKind.payment,
            direction: DebtDirection.owedToMe,
            amountMinor: 50000,
            balanceAfterMinor: 5000000 - i * 50000,
            balanceDirection: DebtDirection.owedToMe,
            currency: currency,
            debtTitle: 'سلفة شخصية',
          ),
      ],
      options: const StatementOptions(scope: StatementScope.all),
    );
  }

  ReceiptData receipt({AppLanguage language = AppLanguage.arabic}) {
    return ReceiptData(
      number: 'RCP-20261115-1000-1234',
      issuedAt: day,
      language: language,
      personName: 'أحمد محمد',
      direction: DebtDirection.owedToMe,
      amount: const Money(900000, currency),
      paidAt: DateTime(2026, 11, 12),
      remainingNow: const Money(0, currency),
      debtTitle: 'فاتورة خدمات',
    );
  }

  Future<PdfInspection> renderStatement(StatementData data) async {
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

  Future<PdfInspection> renderReceipt(ReceiptData data) async {
    final AppLocalizations l10n =
        lookupAppLocalizations(Locale(data.language.code));
    final AppFormatting formatting = AppFormatting(
      language: data.language,
      numerals: NumeralsStyle.latin,
      defaultCurrency: currency,
      localizations: l10n,
    );
    final Uint8List bytes = await ReceiptDocument(
      data: data,
      localizations: l10n,
      formatting: formatting,
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
    return inspectPdf(bytes);
  }

  String visual(String logicalWord) =>
      shapeArabic(logicalWord).split('').reversed.join();

  /// Whether [word] is drawn on [page] (1-based).
  bool drewOn(PdfInspection page, String word, int pageNumber) {
    final String drawn = page.runs
        .where((PdfRun run) => run.page == pageNumber)
        .map((PdfRun run) => run.text)
        .join(' ');
    return drawn.contains(
      containsArabic(word) ? visual(word) : word,
    );
  }

  group('the notice', () {
    test('is on the last page of a three-page statement, and not the first',
        () async {
      final PdfInspection page = await renderStatement(longStatement());
      expect(page.pageCount, 3, reason: 'the fixture has to be three pages');
      expect(
        drewOn(page, 'الطرف', page.pageCount),
        isTrue,
        reason: 'the last page says the document is not an acknowledgement',
      );
      expect(
        drewOn(page, 'الطرف', 1),
        isFalse,
        reason: 'the first page does not carry it',
      );
      // It is drawn once, on the page that ends the document.
      final int occurrences = page.runs
          .where(
            (PdfRun run) => run.text.contains(visual('الطرف')),
          )
          .length;
      expect(occurrences, 1);
    });

    test('is on the last page of the English statement', () async {
      final PdfInspection page = await renderStatement(
        longStatement(language: AppLanguage.english),
      );
      expect(
        drewOn(page, 'acknowledgement', page.pageCount),
        isTrue,
      );
      expect(drewOn(page, 'acknowledgement', 1), isFalse);
    });

    test('a clearance carries it on its only page', () async {
      final StatementData data = longStatement();
      final StatementData clearance = StatementData(
        documentNumber: data.documentNumber,
        generatedAt: data.generatedAt,
        language: data.language,
        personName: data.personName,
        phone: null,
        currency: data.currency,
        totalMinor: data.totalMinor,
        paidMinor: data.totalMinor,
        remainingMinor: 0,
        status: DebtLifecycleStatus.paid,
        debts: <StatementDebtLine>[
          StatementDebtLine(
            title: 'سلفة شخصية',
            direction: DebtDirection.owedToMe,
            principal: data.debts.single.principal,
            paid: data.debts.single.principal,
            remaining: const Money(0, currency),
            status: DebtLifecycleStatus.paid,
          ),
        ],
        entries: data.entries.take(2).toList(),
        options: data.options,
      );
      expect(clearance.isClearance, isTrue);
      final PdfInspection page = await renderStatement(clearance);
      expect(page.pageCount, 1);
      expect(drewOn(page, 'الطرف', 1), isTrue);
    });

    test('a receipt carries it too', () async {
      final PdfInspection page = await renderReceipt(receipt());
      expect(page.pageCount, 1);
      expect(drewOn(page, 'الطرف', 1), isTrue);
    });
  });
}
