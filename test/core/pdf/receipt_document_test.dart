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

/// The receipt for one payment, read back from the page it draws.
///
/// The same kind of check as the statement's: what was actually drawn, not the
/// widgets that were asked for. A receipt is short, so most of what can go
/// wrong is in what it *says* — which way the money moved, and in whose words.
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

  const double pageWidth = 595.276;
  const double margin = 38;
  // The renderer draws a shaped word a point or so wider than it measured it;
  // see the statement's geometry test for where this figure comes from.
  const double slack = 2.0;

  String visual(String word) => shapeArabic(word).split('').reversed.join();

  ReceiptData receipt({
    AppLanguage language = AppLanguage.arabic,
    DebtDirection direction = DebtDirection.owedToMe,
    String person = 'أحمد محمد',
    String issuer = '',
    String? title = 'فاتورة خدمات',
    String? note,
    int amountMinor = 900000,
    List<ReceiptLine> lines = const <ReceiptLine>[],
  }) =>
      ReceiptData(
        number: 'RCP-20261113-1438-4821',
        issuedAt: DateTime(2026, 11, 13, 14, 38),
        language: language,
        personName: person,
        issuerName: issuer,
        direction: direction,
        amount: Money(amountMinor, AppCurrency.inr),
        paidAt: DateTime(2026, 11, 10),
        remainingNow: const Money(250000, AppCurrency.inr),
        debtTitle: title,
        note: note,
        lines: lines,
      );

  Future<PdfInspection> render(ReceiptData data) async {
    final AppLocalizations l10n =
        lookupAppLocalizations(Locale(data.language.code));
    final Uint8List bytes = await ReceiptDocument(
      data: data,
      localizations: l10n,
      formatting: AppFormatting(
        language: data.language,
        numerals: NumeralsStyle.latin,
        defaultCurrency: AppCurrency.inr,
        localizations: l10n,
      ),
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
    return inspectPdf(bytes);
  }

  void expectInsideMargins(PdfInspection page) {
    for (final PdfRun run in page.runs) {
      expect(run.x, greaterThanOrEqualTo(margin - slack), reason: '$run');
      expect(
        run.right,
        lessThanOrEqualTo(pageWidth - margin + slack),
        reason: '$run',
      );
    }
  }

  String words(PdfInspection page) =>
      ' ${page.runs.map((PdfRun run) => run.text).join(' ')} ';

  group('which way the money moved', () {
    test('a debt owed to the user is received: a receipt, from the person',
        () async {
      final PdfInspection page = await render(
        receipt(language: AppLanguage.english, person: 'Ahmed Mohammed'),
      );
      final String all = words(page);
      expect(all, contains(' Payment receipt '));
      expect(all, contains(' Received from: '));
      expect(all, isNot(contains('Paid to')));
      expect(all, contains(' Ahmed Mohammed '));
    });

    test('a debt the user owes is paid out: a voucher, to the person',
        () async {
      final PdfInspection page = await render(
        receipt(
          language: AppLanguage.english,
          person: 'Ahmed Mohammed',
          direction: DebtDirection.iOwe,
        ),
      );
      final String all = words(page);
      expect(all, contains(' Payment voucher '));
      expect(all, contains(' Paid to: '));
      expect(all, isNot(contains('Received from')));
    });

    test('the issuer takes the other half of the sentence', () async {
      final String received = words(
        await render(
          receipt(language: AppLanguage.english, issuer: 'Mohammed Alsrkal'),
        ),
      );
      expect(received, contains(' Received by: '));
      expect(received, contains(' Mohammed Alsrkal '));

      final String paid = words(
        await render(
          receipt(
            language: AppLanguage.english,
            issuer: 'Mohammed Alsrkal',
            direction: DebtDirection.iOwe,
          ),
        ),
      );
      expect(paid, contains(' Paid by: '));

      // No name, no label: an empty line reads as a field left blank.
      final String anonymous =
          words(await render(receipt(language: AppLanguage.english)));
      expect(anonymous, isNot(contains('Received by')));
      expect(anonymous, isNot(contains('Paid by')));
    });

    test('nothing on it speaks as the person who made it', () async {
      // Handed to the other party, who would read "I" as themselves.
      for (final AppLanguage language in AppLanguage.values) {
        for (final DebtDirection direction in DebtDirection.values) {
          final PdfInspection page = await render(
            receipt(
              language: language,
              direction: direction,
              issuer: 'محمد',
              note: 'حوالة',
            ),
          );
          final String all = words(page);
          for (final String forbidden in <String>[
            ' I ',
            ' me ',
            ' my ',
            ' ${visual('لي')} ',
            ' ${visual('عليّ')} ',
          ]) {
            expect(
              all,
              isNot(contains(forbidden)),
              reason: '${language.name}/${direction.name}: "$forbidden"',
            );
          }
        }
      }
    });
  });

  group('what it states', () {
    test('the amount, the day, the debt and what is left', () async {
      final PdfInspection page =
          await render(receipt(language: AppLanguage.english));
      final String all = words(page);
      expect(all, contains(' ₹ 9,000 '));
      expect(all, contains(' Nov 10, 2026 '), reason: 'the month is a word');
      expect(all, contains(' ${visual('فاتورة')} '));
      expect(all, contains(' ₹ 2,500 '));
      expect(all, contains(' RCP-20261113-1438-4821 '));
    });

    test('a debt with no title and a payment with no note leave no gap',
        () async {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('en'));
      final String all = words(
        await render(receipt(language: AppLanguage.english, title: '  ')),
      );
      expect(all, isNot(contains(' ${l10n.receiptFor}: ')));
      expect(all, isNot(contains(' ${l10n.fieldNote}: ')));
    });

    test('an Arabic receipt is drawn, and the amount is not reversed',
        () async {
      final PdfInspection page = await render(receipt(issuer: 'محمد السركال'));
      final String all = words(page);
      expect(all, contains(' ${visual('سند')} '));
      expect(all, contains(' ${visual('أحمد')} '));
      expect(
        page.lineContaining('9,000').map((PdfRun run) => run.text).join(' '),
        '₹ 9,000',
      );
      expectInsideMargins(page);
    });
  });

  group('a payment spread over several debts', () {
    const List<ReceiptLine> lines = <ReceiptLine>[
      ReceiptLine(
        debtTitle: 'Electricity',
        amount: Money(100000, AppCurrency.inr),
        remainingNow: Money(0, AppCurrency.inr),
      ),
      ReceiptLine(
        debtTitle: 'Water',
        amount: Money(50000, AppCurrency.inr),
        remainingNow: Money(150000, AppCurrency.inr),
      ),
    ];

    test('states the total, and where each share went', () async {
      final PdfInspection page = await render(
        receipt(
          language: AppLanguage.english,
          title: null,
          amountMinor: 150000,
          lines: lines,
        ),
      );
      final String all = words(page);
      expect(all, contains(' ₹ 1,500 '), reason: 'the money that changed hands');
      expect(all, contains(' Electricity '));
      expect(all, contains(' Water '));
      expect(all, contains(' ₹ 1,000 '));
      expect(all, contains(' ₹ 500 '));
      expect(page.pageCount, 1);
      expectInsideMargins(page);
    });

    test('an Arabic split receipt stays inside the page', () async {
      final PdfInspection page = await render(
        receipt(
          title: null,
          amountMinor: 150000,
          lines: const <ReceiptLine>[
            ReceiptLine(
              debtTitle: 'مشاركة في مصاريف رحلة الصيف الطويلة إلى الجنوب',
              amount: Money(100000, AppCurrency.inr),
              remainingNow: Money(0, AppCurrency.inr),
            ),
            ReceiptLine(
              debtTitle: 'ماء',
              amount: Money(50000, AppCurrency.inr),
              remainingNow: Money(150000, AppCurrency.inr),
            ),
          ],
        ),
      );
      expectInsideMargins(page);
      expect(words(page), contains(' ${visual('ماء')} '));
    });
  });

  group('the page', () {
    test('is one page, inside its margins, with the mark on it', () async {
      final PdfInspection page = await render(receipt());
      expect(page.pageCount, 1);
      expect(page.drawsImage, isTrue);
      expectInsideMargins(page);
    });

    test('long names, a long title and a long note wrap inside it', () async {
      final PdfInspection page = await render(
        receipt(
          person: 'أحمد محمد عبد الرحمن الشامي ' * 4,
          issuer: 'محمد عبد الله السركال ' * 4,
          title: 'مشاركة في مصاريف رحلة الصيف الطويلة إلى الجنوب ' * 3,
          note: 'ملاحظة طويلة جدًا ' * 30,
          amountMinor: 125000000050,
        ),
      );
      expectInsideMargins(page);
    });
  });

  group('the file', () {
    test('is named for the person and the day of the payment', () {
      expect(
        receipt().fileName,
        'Dhimmah_Receipt_أحمد_محمد_2026-11-10.pdf',
      );
      expect(
        receipt(person: 'a/b:c').fileName,
        'Dhimmah_Receipt_a_b_c_2026-11-10.pdf',
        reason: 'nothing that is a path separator survives',
      );
    });
  });
}
