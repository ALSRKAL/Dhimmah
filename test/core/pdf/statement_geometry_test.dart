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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'pdf_inspector.dart';

/// What the rendered page actually contains.
///
/// These assert on the PDF's own drawing instructions rather than on the widget
/// tree that produced them, because the interesting failures are the ones where
/// the layout code was doing exactly what it was told and the page still came
/// out wrong. The one this file was written for: a long Arabic debt title whose
/// last word was printed past the right margin and clipped, because the width it
/// was wrapped against belonged to a different string from the one that was
/// drawn.
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

  // The document's own geometry. A statement is A4 with 38pt side margins.
  const double pageWidth = 595.276;
  const double margin = 38;
  const double leftEdge = margin;
  const double rightEdge = pageWidth - margin;

  /// How far past a margin a run may land before it counts as overflow.
  ///
  /// The renderer measures a line with kerning applied and then writes the
  /// font's per-glyph widths into the file, so a shaped Arabic word is drawn
  /// about a point and a half wider than it was measured — 0.3% of the column,
  /// and it lands the last word of a right-aligned line just past the margin.
  /// That is the renderer's own arithmetic, not the layout's: the widest
  /// overshoot measured across every sample is 1.44pt, where the defect this
  /// file exists for was 9.3pt and a real clip. The tolerance is set from the
  /// measurement rather than the other way round, and the negative control below
  /// keeps it honest.
  const double measurementSlack = 2.0;

  Future<Uint8List> render(
    StatementData data, {
    AppLanguage language = AppLanguage.arabic,
    NumeralsStyle numerals = NumeralsStyle.latin,
  }) async {
    final AppLocalizations l10n =
        lookupAppLocalizations(Locale(language.code));
    final AppFormatting formatting = AppFormatting(
      language: language,
      numerals: numerals,
      defaultCurrency: data.currency,
      localizations: l10n,
    );
    return StatementDocument(
      data: data,
      localizations: l10n,
      formatting: formatting,
      regularFont: regular,
      semiBoldFont: semiBold,
      mark: mark,
    ).build().save();
  }


/// A PNG's pixel width, read from its own header.
int pngWidth(ByteData png) =>
    (png.getUint8(16) << 24) |
    (png.getUint8(17) << 16) |
    (png.getUint8(18) << 8) |
    png.getUint8(19);

/// A PNG's pixel height, read from its own header.
int pngHeight(ByteData png) =>
    (png.getUint8(20) << 24) |
    (png.getUint8(21) << 16) |
    (png.getUint8(22) << 8) |
    png.getUint8(23);

/// How a shaped word is drawn: the renderer arranges a right-to-left line from
/// the reading side, so a word's glyphs appear in reverse of the order they were
/// shaped in. Comparing against the logical form would fail on every correct
/// document.
String visual(String logicalWord) =>
    shapeArabic(logicalWord).split('').reversed.join();

/// The line that draws every one of [words].
///
/// A phrase is not one run — the renderer draws a run per word, in visual order
/// — so a label has to be looked for word by word. Looking for its first word
/// alone finds the wrong line: «تاريخ» starts both «تاريخ الاستحقاق» in the
/// summary and «تاريخ الإصدار» in the header.
List<PdfRun> lineWithAllWords(PdfInspection page, String phrase) {
  final List<String> wanted =
      phrase.split(' ').map(visual).toList(growable: false);
  for (final List<PdfRun> line in page.lines) {
    final String drawn = line.map((PdfRun run) => run.text).join(' ');
    if (wanted.every(drawn.contains)) return line;
  }
  return const <PdfRun>[];
}

  double maxOf(double a, double b) => a > b ? a : b;

  /// Nothing may be drawn outside the margins. A run that starts or ends past
  /// them is either clipped by the viewer or printed into the paper's edge.
  void expectInsideMargins(PdfInspection page, String what) {
    for (final PdfRun run in page.runs) {
      expect(
        run.x,
        greaterThanOrEqualTo(leftEdge - measurementSlack),
        reason: '$what: a run starts left of the margin — $run',
      );
      expect(
        run.right,
        lessThanOrEqualTo(rightEdge + measurementSlack),
        reason: '$what: a run ends past the right margin — $run',
      );
      // Nothing may leave the page itself, whatever the renderer's arithmetic
      // does: this is the bound that means "clipped".
      expect(run.x, greaterThanOrEqualTo(0));
      expect(run.right, lessThanOrEqualTo(pageWidth));
    }
  }

  group('a statement with a multi-person record', () {
    test('prints it as an ordinary line, and names nobody else', () async {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            title: 'فاتورة العشاء',
            extraDebts: <String>['سلفة'],
          ),
        ),
      );

      // Two records put the breakdown table on the page, and the record that is
      // linked to several people is simply one of its rows: its own title, its
      // own figures, and no heading or block of its own.
      expect(
        lineWithAllWords(page, 'فاتورة العشاء'),
        isNotEmpty,
        reason: 'the record has to be named',
      );
      expect(
        lineWithAllWords(page, l10n.reportDebtsBreakdown),
        isNotEmpty,
        reason: 'and to be one row of the ordinary breakdown',
      );
      expect(
        lineWithAllWords(page, 'علي محمد'),
        isEmpty,
        reason: 'a statement speaks for one person, and never names the '
            'others the record is also linked to',
      );
      expectInsideMargins(page, 'a multi-person record');
    });

    test('stays inside the margins when there are several of them', () async {
      final AppLocalizations l10n = lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            title: 'مشاركة في مصاريف رحلة الصيف الطويلة إلى الجنوب',
            extraDebts: <String>['سلفة', 'قرض', 'إيجار', 'مصاريف', 'فواتير'],
          ),
        ),
      );

      // Long titles and a dozen rows: the table grows and nothing may run off
      // the page. There is no participants column for it to grow into either.
      expectInsideMargins(page, 'several records');
      expect(lineWithAllWords(page, l10n.reportColumnDebt), isNotEmpty);
    });
  });

  group('no text leaves the page', () {
    test('a long Arabic statement stays inside the margins', () async {
      final PdfInspection page = inspectPdf(await render(_arabicStatement()));
      expectInsideMargins(page, 'Arabic');
      expect(page.runs, isNotEmpty);
    });

    test('the English statement stays inside the margins', () async {
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(language: AppLanguage.english),
          language: AppLanguage.english,
        ),
      );
      expectInsideMargins(page, 'English');
      expect(page.runs, isNotEmpty);
    });

    test('a debt title that cannot be broken does not overflow', () async {
      // The pathological case: one token wider than its column, with no space
      // to break at. It has to be broken by the renderer rather than run off
      // the page.
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            title: 'mohammed.abdulrahman.alshami.1990@verylongdomainname.example',
          ),
        ),
      );
      expectInsideMargins(page, 'unbreakable title');
    });

    test('a long note wraps instead of running off', () async {
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            notes: 'ملاحظة طويلة جدًا ' * 40,
            options: const StatementOptions(includeNotes: true),
          ),
        ),
      );
      expectInsideMargins(page, 'long note');
    });

    test('a large amount in a narrow column stays inside', () async {
      final PdfInspection page = inspectPdf(
        await render(_arabicStatement(amountMinor: 125000050)),
      );
      expectInsideMargins(page, 'large amount');
    });
  });

  group('reading order', () {
    test('an Arabic line is drawn right to left', () async {
      // The renderer is given the words in logical order and a right-to-left
      // direction, and arranges each line from the right. Read back from the
      // page, the leftmost run must therefore be the last word.
      final PdfInspection page = inspectPdf(
        await render(_arabicStatement()),
      );

      final List<PdfRun> line = page.lineContaining(visual('أحمد'));
      expect(line, isNotEmpty, reason: 'the name was not drawn');

      final List<String> drawn =
          line.map((PdfRun run) => run.text).toList();
      final List<String> logical = <String>[
        'أحمد',
        'محمد',
        'عبد',
        'الرحمن',
        'الشامي',
      ].map(visual).toList();

      // Left to right on the page is last word first.
      expect(drawn, logical.reversed.toList());
    });

    test('a numeric line is not reversed', () async {
      // Numbers are a left-to-right run inside a right-to-left document, and a
      // renderer that reversed every word would turn `₹ 45,500` into
      // `45,500 ₹` — a column of amounts nobody could read.
      final PdfInspection page = inspectPdf(await render(_arabicStatement()));

      final List<PdfRun> line = page.lineContaining('45,500');
      expect(line, isNotEmpty, reason: 'the remaining amount was not drawn');
      expect(
        line.map((PdfRun run) => run.text).join(' '),
        '₹ 45,500',
        reason: 'the amount was reordered',
      );
    });

    test('Arabic-Indic numerals keep their own order too', () async {
      // The numeral style is a user setting, so the statement has to be right
      // in both. Arabic-Indic digits are a separate Unicode block, and the font
      // covers them — but they are still an Arabic Number run, and a renderer
      // that mirrored them would print ٠٠٥٤ for ٤٥٠٠.
      final PdfInspection page = inspectPdf(
        await render(_arabicStatement(), numerals: NumeralsStyle.arabicIndic),
      );
      expectInsideMargins(page, 'Arabic-Indic numerals');

      // The grouping separator stays a Latin comma: the app maps digit shapes
      // and nothing else, so the statement and the screen agree.
      final List<PdfRun> line = page.lineContaining('٤٥,٥٠٠');
      expect(
        line,
        isNotEmpty,
        reason: 'the remaining amount was not drawn in Arabic-Indic digits',
      );
      expect(line.map((PdfRun run) => run.text).join(' '), '₹ ٤٥,٥٠٠');
    });

    test('an English line is drawn left to right', () async {
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(language: AppLanguage.english, name: 'Ahmed Mohammed'),
          language: AppLanguage.english,
        ),
      );
      final List<PdfRun> line = page.lineContaining('Ahmed');
      expect(line, isNotEmpty);
      expect(
        line.map((PdfRun run) => run.text).join(' '),
        startsWith('Ahmed Mohammed'),
      );
    });
  });

  group('the reading side', () {
    // A heading is the one thing on a page that has to start where the eye
    // starts. These were laid out as rows only as wide as their own text, so the
    // page put them against the left margin: «ملخص الحساب» sat under the
    // document number instead of over the summary it names.
    test('an Arabic heading starts at the right margin', () async {
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = inspectPdf(
        await render(
          // The breakdown only appears when there is more than one debt.
          _arabicStatement(extraDebts: <String>['قرض سيارة']),
        ),
      );

      for (final String title in <String>[
        l10n.reportAccountSummary,
        l10n.reportDebtsBreakdown,
        l10n.reportPaymentHistory,
      ]) {
        final List<PdfRun> line = lineWithAllWords(page, title);
        expect(line, isNotEmpty, reason: '"$title" was not drawn');
        final double right = line
            .map((PdfRun run) => run.right)
            .reduce((double a, double b) => a > b ? a : b);
        expect(
          right,
          greaterThan(rightEdge - 12),
          reason: '"$title" does not start at the reading side — '
              'its rightmost run ends at ${right.toStringAsFixed(1)}',
        );
      }
    });

    test('the summary facts start at the right margin', () async {
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('ar'));
      final PdfInspection page = inspectPdf(await render(_arabicStatement()));

      // The currency note is the whole row, so its rightmost run is the row's.
      final List<PdfRun> currency = lineWithAllWords(page, l10n.fieldCurrency);
      expect(currency, isNotEmpty, reason: 'the currency note was not drawn');
      expect(
        currency.map((PdfRun run) => run.right).reduce(maxOf),
        greaterThan(rightEdge - 12),
        reason: 'the currency note does not start at the reading side',
      );

      // The status row is the badge and then the due date. The badge's word is
      // not the rightmost ink — the dot that leads it is — so the assertion is
      // the property that matters rather than a position: the row is on the
      // reading side of the page, and the badge comes before the date in it.
      final List<PdfRun> status = lineWithAllWords(page, l10n.statusOverdue);
      expect(status, isNotEmpty, reason: 'the status badge was not drawn');
      final double statusRight =
          status.map((PdfRun run) => run.right).reduce(maxOf);
      expect(
        statusRight,
        greaterThan((leftEdge + rightEdge) / 2),
        reason: 'the status row is not on the reading side',
      );

      // Both are on the same baseline, so the question is which comes first in
      // reading order: in a right-to-left row, the rightmost run is the one read
      // first, and that has to be the status word.
      expect(
        lineWithAllWords(page, l10n.detailDueOn),
        isNotEmpty,
        reason: 'the due date was not drawn',
      );
      final PdfRun rightmost = status.reduce(
        (PdfRun a, PdfRun b) => a.right > b.right ? a : b,
      );
      expect(
        rightmost.text,
        contains(visual(l10n.statusOverdue)),
        reason: 'the badge is not the first thing read in its row',
      );
    });

    test('the English statement keeps its headings on the left', () async {
      // The same rows, the other way round: a fix that right-aligned everything
      // would be just as wrong.
      final AppLocalizations l10n =
          lookupAppLocalizations(const Locale('en'));
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(language: AppLanguage.english),
          language: AppLanguage.english,
        ),
      );
      final List<PdfRun> line =
          page.lineContaining(l10n.reportAccountSummary.split(' ').first);
      expect(line, isNotEmpty);
      final double left =
          line.map((PdfRun run) => run.x).reduce((double a, double b) => a < b ? a : b);
      expect(left, lessThan(leftEdge + 12));
    });
  });

  group('pages', () {
    test('a long payment history flows onto more pages', () async {
      final PdfInspection page =
          inspectPdf(await render(_arabicStatement(payments: 300)));
      expect(page.pageCount, greaterThan(1));
      expectInsideMargins(page, 'multi-page');
    });

    test('the column header repeats on every page', () async {
      final PdfInspection page =
          inspectPdf(await render(_arabicStatement(payments: 300)));
      // The payment history's date column, drawn once per page.
      final int headerLines = page.lines
          .where(
            (List<PdfRun> line) =>
                line.any((PdfRun run) => run.text == visual('التاريخ')),
          )
          .length;
      expect(
        headerLines,
        page.pageCount,
        reason: 'the table header did not repeat on every page',
      );
    });

    test('a statement with no payments still renders its empty note', () async {
      final PdfInspection page =
          inspectPdf(await render(_arabicStatement(payments: 0)));
      expect(page.pageCount, 1);
      expectInsideMargins(page, 'no payments');
    });
  });

  group('the detector itself', () {
    test('an overflow that is really there is reported', () async {
      // A test that passes on both a correct and a broken document is worth
      // nothing, and the check above is only meaningful if it can fail. This
      // draws a line wider than the page on purpose, the way the old renderer
      // did by accident, and asserts the inspector sees it.
      final pw.Document document = pw.Document();
      document.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: pw.Font.ttf(regular)),
          margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 52),
          build: (pw.Context context) => pw.Text(
            'a line that is deliberately far too long to fit inside the '
            'content box of this page and must therefore be reported '
            'a line that is deliberately far too long to fit inside the '
            'content box of this page and must therefore be reported',
            softWrap: false,
            style: const pw.TextStyle(fontSize: 11),
          ),
        ),
      );
      final PdfInspection page = inspectPdf(await document.save());
      final Iterable<PdfRun> outside =
          page.runs.where((PdfRun run) => run.right > rightEdge + 20);
      expect(
        outside,
        isNotEmpty,
        reason: 'the inspector did not notice a line drawn past the margin',
      );
    });

    test('a document inside its margins reports nothing', () async {
      final PdfInspection page = inspectPdf(await render(_arabicStatement()));
      expect(
        page.runs.where(
          (PdfRun run) =>
              run.x < leftEdge - measurementSlack ||
              run.right > rightEdge + measurementSlack,
        ),
        isEmpty,
      );
    });
  });

  group('content survives the trip', () {
    test('every debt title in the source appears in the document', () async {
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            extraDebts: <String>['قرض سيارة', 'مشاركة في مصاريف السفر'],
          ),
        ),
      );
      // Word by word: the renderer draws one run per word, so a phrase is not a
      // contiguous string on the page even though it is one in the data.
      final String all = page.runs.map((PdfRun run) => run.text).join(' ');
      for (final String word in <String>['قرض', 'سيارة', 'مصاريف', 'السفر']) {
        expect(
          all.contains(visual(word)),
          isTrue,
          reason: '"$word" is missing from the document',
        );
      }
    });

    test('a mixed Arabic and Latin note keeps both orders', () async {
      final PdfInspection page = inspectPdf(
        await render(
          _arabicStatement(
            notes: 'تم الدفع إلى Ahmed بمبلغ 1,250 INR',
            options: const StatementOptions(includeNotes: true),
          ),
        ),
      );
      expectInsideMargins(page, 'mixed note');
      final String all = page.runs.map((PdfRun run) => run.text).join(' ');
      // The Latin words are untouched and the Arabic is shaped.
      expect(all, contains('Ahmed'));
      expect(all, contains('1,250'));
      expect(all, contains('INR'));
      expect(all, contains(visual('الدفع')));
    });

    test('the brand mark is drawn, not skipped', () async {
      // The header carries the artwork itself. If the asset stopped loading the
      // document would still render, just without its logo — which is exactly
      // the kind of failure nothing else notices.
      final PdfInspection page = inspectPdf(await render(_arabicStatement()));
      expect(page.runs, isNotEmpty);
      expect(
        page.drawsImage,
        isTrue,
        reason: 'the mark was never drawn on any page',
      );
      // And it is the mark's own artwork, not a placeholder. The expectation is
      // read from the asset rather than written down, so re-exporting the
      // reference at a different size does not fail a test that is really about
      // whether the logo is in the document at all.
      final ByteData asset =
          await rootBundle.load('assets/icon/mark_document.png');
      expect(
        page.imageSize,
        <int>[pngWidth(asset), pngHeight(asset)],
        reason: 'the embedded image is not the document mark',
      );
    });
  });
}

// --- Fixtures ----------------------------------------------------------------

/// A statement with the shapes that break layout: a long name, a title with
/// spaces, several currencies' worth of amounts, and a configurable history.
StatementData _arabicStatement({
  /// The document's language, which is what decides its reading direction. The
  /// strings come from the localizations the caller passes, so a fixture with
  /// English words and an Arabic language is a right-to-left document that
  /// happens to be written in English — which is not the thing any test here
  /// means to check.
  AppLanguage language = AppLanguage.arabic,
  String name = 'أحمد محمد عبد الرحمن الشامي',
  String title = 'مشاركة في مصاريف السفر',
  String? notes,
  int payments = 3,
  int amountMinor = 4550000,
  List<String> extraDebts = const <String>[],
  StatementOptions options = const StatementOptions(),
}) {
  const AppCurrency currency = AppCurrency.inr;
  final DateTime today = DateTime(2026, 9, 23);

  return StatementData(
    documentNumber: 'DHM-2026-1234',
    documentId: 'ABC123',
    generatedAt: today,
    language: language,
    personName: name,
    phone: '+967 771 234 567',
    currency: currency,
    totalMinor: 6850000,
    paidMinor: 2300000,
    remainingMinor: amountMinor,
    status: DebtLifecycleStatus.overdue,
    dueAt: DateTime(2026, 9, 17),
    debts: <StatementDebtLine>[
      StatementDebtLine(
        title: title,
        direction: DebtDirection.iOwe,
        principal: const Money(6850000, currency),
        paid: const Money(2300000, currency),
        remaining: Money(amountMinor, currency),
        status: DebtLifecycleStatus.overdue,
        dueAt: DateTime(2026, 9, 17),
      ),
      for (final String extra in extraDebts)
        StatementDebtLine(
          title: extra,
          direction: DebtDirection.owedToMe,
          principal: const Money(850000, currency),
          paid: const Money(0, currency),
          remaining: const Money(850000, currency),
          status: DebtLifecycleStatus.upcoming,
          dueAt: DateTime(2026, 9, 26),
        ),
    ],
    entries: <StatementEntry>[
      for (int i = 0; i < payments; i++)
        StatementEntry(
          date: DateTime(2026, 3, 7).add(Duration(days: i * 5)),
          kind: i.isEven
              ? StatementEntryKind.payment
              : StatementEntryKind.debtCreated,
          amountMinor: 3500000 - i * 50000,
          balanceAfterMinor: 6850000 - i * 50000,
          currency: currency,
          note: i == 1 ? 'سلفة شخصية' : null,
        ),
    ],
    options: options,
    notes: notes,
  );
}
