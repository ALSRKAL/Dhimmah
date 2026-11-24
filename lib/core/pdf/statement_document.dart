import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/enums/debt_enums.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';
import '../brand/brand_mark.dart';
import '../formatting/app_formatting.dart';
import '../money/money.dart';
import 'pdf_text.dart';
import 'statement_models.dart';

part 'receipt_document.dart';

/// The Dhimmah document palette.
///
/// A printed statement is read on paper and in other people's viewers, so these
/// are fixed values rather than theme lookups: a statement must look the same
/// whoever generated it, in whatever mode their app happened to be in.
abstract final class DocumentColors {
  const DocumentColors._();

  // The same ink-on-paper values as the app. A statement is a sibling of the
  // screen it came from, and a document in last year's colours reads as a
  // document from a different product.
  static const PdfColor ink = PdfColor.fromInt(0xFF1C1917);
  static const PdfColor secondary = PdfColor.fromInt(0xFF6B655C);
  /// Decoration only. At about 3.3:1 on white it is below what small text
  /// needs, so nothing that is read is set in it: labels, the footer and the
  /// document number use [secondary].
  static const PdfColor muted = PdfColor.fromInt(0xFF948D83);
  static const PdfColor brand = PdfColor.fromInt(0xFF1E554C);
  static const PdfColor brandTint = PdfColor.fromInt(0xFFEAF2F0);
  static const PdfColor gold = PdfColor.fromInt(0xFFC8A24A);
  static const PdfColor border = PdfColor.fromInt(0xFFE5E1DA);
  static const PdfColor rowTint = PdfColor.fromInt(0xFFF7F5F2);

  static const PdfColor settled = PdfColor.fromInt(0xFF0B7A54);
  static const PdfColor overdue = PdfColor.fromInt(0xFFB3261E);
  static const PdfColor dueSoon = PdfColor.fromInt(0xFF9E5C00);
  static const PdfColor neutral = PdfColor.fromInt(0xFF6B655C);
}

/// The width of the text area, in points: A4, less a 38pt margin either side.
const double _contentWidth = 595.276 - 38 * 2;

/// What every Dhimmah document is set with.
///
/// The text setting — shaping, line breaking, word order — and the header and
/// footer, shared by the statement and the receipt so the two are one family
/// and so a fix to how Arabic is drawn is made once. Everything about *what* a
/// document says stays in the document.
abstract class _Sheet {
  _Sheet({
    required this.localizations,
    required this.formatting,
    required this.regularFont,
    required this.semiBoldFont,
    required this.mark,
  });

  final AppLocalizations localizations;
  final AppFormatting formatting;
  final ByteData regularFont;
  final ByteData semiBoldFont;

  /// The brand mark, as the artwork rather than a redrawing of it.
  final BrandMark mark;

  /// Whether the document reads right to left: its language, not its content.
  bool get _isRtl;

  /// The most pages a generated document may take.
  ///
  /// The `pdf` package defaults to 20, which a long but ordinary history can
  /// exceed; the user then saw «تعذّر التصدير» instead of the statement. Five
  /// hundred A4 pages holds over ten thousand movement rows, far beyond a
  /// person's ledger. If a document ever exceeds it, generation fails rather
  /// than silently dropping the end, and the preview still offers retry.
  static const int maxDocumentPages = 500;

  /// How much of a user string a fixed-width cell may show.
  static const int displayNameLimit = 80;
  static const int displayTitleLimit = 80;

  /// Breaks a pathologically long string into page-sized pieces.
  ///
  /// A single unbroken word in a narrow table cell or a note becomes one line
  /// per character, and a widget taller than a page cannot be split by the PDF
  /// paginator. The full value is still printed, in the document's appendix.
  static List<String> textChunks(String value) {
    final List<int> runes = value.runes.toList(growable: false);
    if (runes.length <= 300) return <String>[value];
    final bool hasLongWord = value
        .split(RegExp(r'\s+'))
        .any((String word) => word.runes.length > 60);
    final int size = hasLongWord ? 40 : 200;
    return <String>[
      for (int start = 0; start < runes.length; start += size)
        String.fromCharCodes(
          runes.sublist(
            start,
            start + size > runes.length ? runes.length : start + size,
          ),
        ),
    ];
  }

  /// The visible form of an overlong user string.
  static String shortened(String value, int limit) {
    final List<int> runes = value.runes.toList(growable: false);
    if (runes.length <= limit) return value;
    return '${String.fromCharCodes(runes.take(limit - 1))}…';
  }

  /// The fonts in use.
  late final pw.Font _regular = pw.Font.ttf(regularFont);
  late final pw.Font _semiBold = pw.Font.ttf(semiBoldFont);

  /// The same two faces, read for their glyph advances, so a line can be set
  /// word by word at exactly the width the renderer will draw.
  late final TtfParser _regularFace = TtfParser(regularFont);
  late final TtfParser _semiBoldFace = TtfParser(semiBoldFont);

  /// The width [text] takes in [style], from the font's own advances.
  double _advance(String text, pw.TextStyle style) {
    final TtfParser face = style.fontWeight == pw.FontWeight.bold
        ? _semiBoldFace
        : _regularFace;
    double em = 0;
    for (final int rune in text.runes) {
      // A mark sits on the letter before it and takes no room of its own.
      if (isCombiningMark(rune)) continue;
      final int? glyph = face.charToGlyphIndexMap[rune];
      if (glyph == null) continue;
      em += face.glyphInfoMap[glyph]?.advanceWidth ?? 0;
    }
    return em * (style.fontSize ?? 12);
  }

  /// An amount for a printed page: plain text, no bidi controls.
  String _money(Money money) => formatting.documentAmount(money);

  /// The reading side of the page: right for Arabic, left for English.
  pw.Alignment get _alignStart =>
      _isRtl ? pw.Alignment.centerRight : pw.Alignment.centerLeft;

  /// The opposite edge, where amounts sit so a column of numbers lines up.
  pw.Alignment get _alignEnd =>
      _isRtl ? pw.Alignment.centerLeft : pw.Alignment.centerRight;

  /// Where a column of text starts, for a `Column`'s cross axis.
  ///
  /// The renderer resolves `start` and `end` against a `Directionality` that
  /// this document cannot install, so the side is named outright.
  pw.CrossAxisAlignment get _crossStart =>
      _isRtl ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start;

  /// A row whose content sits on the reading side of the page.
  ///
  /// A row fills the width it is given and packs its children from the left, so
  /// a heading with nothing to its right hugs the left margin — which is how
  /// «ملخص الحساب» came to sit under the document number instead of over the
  /// summary it names. Packing it to the reading side is what fixes it, and it
  /// has to be done here rather than with a trailing spacer: the renderer's
  /// spacer arithmetic leaves the last word about a point past the margin.
  ///
  /// The children are given in reading order, as everywhere else, and the
  /// reversal for Arabic still applies — packed to the end, the reversed list
  /// puts the first child on the reading side.
  pw.Widget _rowOnReadingSide(List<pw.Widget> children) {
    return _row(
      align: _isRtl ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
      children: children,
    );
  }

  /// A row laid out in reading order.
  ///
  /// The renderer always draws left to right, so an Arabic row's children are
  /// reversed here. Without this the summary cells would read Total, Paid,
  /// Remaining from the left, which is backwards for an Arabic reader.
  pw.Widget _row({
    required List<pw.Widget> children,
    pw.MainAxisAlignment align = pw.MainAxisAlignment.start,
    pw.CrossAxisAlignment cross = pw.CrossAxisAlignment.center,
  }) {
    return pw.Row(
      mainAxisAlignment: align,
      crossAxisAlignment: cross,
      children: _isRtl ? children.reversed.toList() : children,
    );
  }

  /// Draws [logical], deciding direction and alignment from the string itself.
  ///
  /// Neither is the document's language, and getting that wrong is what makes an
  /// Arabic statement look almost right:
  ///
  ///  * **Direction** follows the string. A string with Arabic in it is set
  ///    here, in the order its own letters give; a Latin or numeric one is
  ///    handed to the renderer left-to-right, because the renderer reorders
  ///    *every* right-to-left paragraph by reversing its words, and `₹ 45,500`
  ///    would come out as `45,500 ₹`.
  ///  * **Alignment** follows the document, then the string. A label sits on the
  ///    reading side; a number sits on the far side so a column of amounts lines
  ///    up. The renderer expresses both as `start`/`end` *of the string's own
  ///    direction*, so the side is converted here.
  ///
  /// [maxWidth] is the room the text has, when it is bounded. Text with Arabic
  /// in it is broken into lines against it here ([_setArabic]); the rest is
  /// left to the renderer, which breaks it.
  pw.Widget _text(
    String logical, {
    required pw.TextStyle style,
    bool atEnd = false,
    double? maxWidth,
  }) {
    final bool alignRight = atEnd ? !_isRtl : _isRtl;
    final pw.Widget? set = _setArabic(
      logical,
      style: style,
      alignRight: alignRight,
      maxWidth: maxWidth,
    );
    if (set != null) return set;
    final bool rtl = containsArabic(logical);
    final String shaped = pdfText(logical);
    return pw.Text(
      rtl ? rightToLeftParagraphs(shaped) : shaped,
      textDirection:
          rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: alignRight
          ? (rtl ? pw.TextAlign.start : pw.TextAlign.end)
          : (rtl ? pw.TextAlign.end : pw.TextAlign.start),
      style: style,
    );
  }

  /// Sets text that contains Arabic line by line and word by word, or returns
  /// null when a word is too wide to fit a line on its own.
  ///
  /// The renderer places the words of a right-to-left line by their ink width
  /// rather than their advance, so each gap moves by the difference between two
  /// words' side margins. Next to a number it closed completely: «30 سبتمبر
  /// 2026» came out as «سبتمبر2026», the tail of the ر and the digits' own
  /// margins taking the whole space. Drawn one word at a time there is nothing
  /// for that to move, so each word is its own text ([_word]), in the order
  /// [visualWordOrder] gives, a space apart.
  ///
  /// The lines are broken here as well, at the spaces, against [maxWidth]. A
  /// paragraph handed to the renderer is ordered by its own bidirectional
  /// pass, which re-shapes what it is given — «للاستعادة» lost its lam-alef —
  /// and throws outright on some lines, so no Arabic goes to it that does not
  /// have to. A paragraph keeps one direction over all its lines, from its
  /// first letter. A word too wide for a line of its own is the exception:
  /// only the renderer can break inside a word, so that text is left to it.
  pw.Widget? _setArabic(
    String logical, {
    required pw.TextStyle style,
    required bool alignRight,
    double? maxWidth,
  }) {
    if (!containsArabic(logical)) return null;
    final double gap = _advance(' ', style);
    final List<pw.Widget> lines = <pw.Widget>[];
    for (final String paragraph in logical.split('\n')) {
      final List<String> words = <String>[
        for (final String word in paragraph.split(' '))
          if (word.isNotEmpty) pdfText(word),
      ];
      if (words.isEmpty) {
        // A blank line between two paragraphs keeps its height.
        lines.add(pw.Text(' ', style: style));
        continue;
      }
      final bool rightToLeft = readsRightToLeft(words, fallback: _isRtl);
      pw.Widget lineOf(List<String> line) => _line(
            line,
            style: style,
            gap: gap,
            alignRight: alignRight,
            rightToLeft: rightToLeft,
          );

      List<String> line = <String>[];
      double width = 0;
      for (final String word in words) {
        final double advance = _advance(word, style);
        if (maxWidth != null) {
          if (advance > maxWidth) return null;
          if (line.isNotEmpty && width + gap + advance > maxWidth) {
            lines.add(lineOf(line));
            line = <String>[];
            width = 0;
          }
        }
        width += (line.isEmpty ? 0 : gap) + advance;
        line.add(word);
      }
      lines.add(lineOf(line));
    }
    if (lines.length == 1) return lines.single;

    final double spacing = style.lineSpacing ?? 0;
    return pw.Column(
      crossAxisAlignment:
          alignRight ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        for (int i = 0; i < lines.length; i++) ...<pw.Widget>[
          if (i > 0 && spacing > 0) pw.SizedBox(height: spacing),
          lines[i],
        ],
      ],
    );
  }

  /// One line of [words], in reading order, drawn a space apart.
  pw.Widget _line(
    List<String> words, {
    required pw.TextStyle style,
    required double gap,
    required bool alignRight,
    required bool rightToLeft,
  }) {
    final List<String> drawn = visualWordOrder(
      words,
      fallbackRightToLeft: rightToLeft,
      rightToLeft: rightToLeft,
    );
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      mainAxisAlignment:
          alignRight ? pw.MainAxisAlignment.end : pw.MainAxisAlignment.start,
      children: <pw.Widget>[
        for (int i = 0; i < drawn.length; i++) ...<pw.Widget>[
          if (i > 0) pw.SizedBox(width: gap),
          _word(drawn[i], style),
        ],
      ],
    );
  }

  /// One word of a line set by [_setArabic].
  ///
  /// Even alone, a right-to-left word is placed by its ink, and moves inside
  /// its own box by its end letters' margins: «شخصية:» sat a point off, and
  /// the gap after the colon looked doubled. A word [reversedArabicWord] can
  /// order is handed over already in drawing order, left to right, and is
  /// placed by its advance like any other; the rest keep their direction.
  pw.Widget _word(String word, pw.TextStyle style) {
    final String? reversed = reversedArabicWord(word);
    if (reversed != null) {
      return pw.Text(reversed, textDirection: pw.TextDirection.ltr, style: style);
    }
    final bool rtl = containsArabic(word);
    return pw.Text(
      rtl ? rightToLeftParagraphs(word) : word,
      textDirection: rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      style: style,
    );
  }

  /// The top of a first page: the mark and what the document is on the
  /// reading side, its number and date on the other, and the two rules.
  pw.Widget _headerOf({
    required String title,
    required String number,
    required DateTime issuedAt,
    DateTime? periodFrom,
    DateTime? periodTo,
    bool showCoverage = true,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _row(
          children: <pw.Widget>[
            _brandLockupOf(title),
            pw.Spacer(),
            _identityOf(
              number,
              issuedAt,
              periodFrom: periodFrom,
              periodTo: periodTo,
              showCoverage: showCoverage,
            ),
          ],
        ),
        pw.SizedBox(height: 12),
        pw.Container(height: 2, color: DocumentColors.brand),
        pw.SizedBox(height: 2),
        // The gold rule sits under the mark, on the reading side. It is the
        // document's one flourish and it should lead, not trail.
        _row(
          children: <pw.Widget>[
            pw.Container(width: 92, height: 1, color: DocumentColors.gold),
            pw.Spacer(),
          ],
        ),
      ],
    );
  }

  /// Logo mark, app name and document type, on the reading side of the page.
  ///
  /// The document type is the larger of the two lines: a page is identified by
  /// what it is — a statement — before by what made it.
  pw.Widget _brandLockupOf(String title) {
    return _row(
      children: <pw.Widget>[
        mark.widget(height: 34),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: _crossStart,
          children: <pw.Widget>[
            _text(
              localizations.appName,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
                color: DocumentColors.brand,
              ),
            ),
            _text(
              title,
              style: pw.TextStyle(
                fontSize: 19,
                fontWeight: pw.FontWeight.bold,
                color: DocumentColors.ink,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Document number, date and what the document covers, on the opposite side.
  ///
  /// The third line answers "until when": a stated period names both ends, and
  /// an unbounded statement says it runs up to the day it was issued. Without
  /// that line a reader could not tell a statement of the last month from one
  /// of the whole account.
  pw.Widget _identityOf(
    String number,
    DateTime issuedAt, {
    DateTime? periodFrom,
    DateTime? periodTo,
    bool showCoverage = true,
  }) {
    pw.Widget line(String label, String value) => _row(
          children: <pw.Widget>[
            _text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: DocumentColors.secondary,
              ),
            ),
            pw.SizedBox(width: 6),
            _text(
              value,
              style: pw.TextStyle(
                fontSize: 9.5,
                fontWeight: pw.FontWeight.bold,
                color: DocumentColors.ink,
              ),
            ),
          ],
        );

    final bool hasPeriod = periodFrom != null && periodTo != null;
    return pw.Column(
      crossAxisAlignment: _crossStart,
      children: <pw.Widget>[
        line(localizations.reportDocumentNumber, number),
        pw.SizedBox(height: 3),
        line(
          localizations.reportIssuedOn,
          formatting.date(issuedAt),
        ),
        // A receipt has already said when the payment happened and when it was
        // issued; repeating the issue date under "As of" would say one fact
        // twice. A statement has no other line that says what it covers.
        if (showCoverage) ...<pw.Widget>[
          pw.SizedBox(height: 3),
          line(
            hasPeriod
                ? localizations.reportPeriod
                : localizations.reportPeriodUntil,
            hasPeriod
                ? localizations.reportPeriodRange(
                    formatting.date(periodFrom),
                    formatting.date(periodTo),
                  )
                : formatting.date(issuedAt),
          ),
        ],
      ],
    );
  }

  /// One labelled line of the summary, on the reading side: the currency, or
  /// the one debt a statement is about.
  pw.Widget _summaryFact(
    String label,
    String value, {
    double width = _contentWidth,
  }) {
    const pw.TextStyle labelStyle = pw.TextStyle(
      fontSize: 9,
      color: DocumentColors.secondary,
    );
    final String labelText = '$label:';
    return _rowOnReadingSide(<pw.Widget>[
      _text(labelText, style: labelStyle),
      pw.SizedBox(width: 5),
      pw.Flexible(
        child: _text(
          value,
          style: pw.TextStyle(
            fontSize: 9.5,
            fontWeight: pw.FontWeight.bold,
            color: DocumentColors.ink,
          ),
          maxWidth: width - _advance(labelText, labelStyle) - 5,
        ),
      ),
    ]);
  }

  /// The foot of every page: who made it, its number, and the page count.
  ///
  /// The last page carries one more line: a plain statement that the document
  /// was made from the issuer's own records and is not the other party's
  /// acknowledgement. It is deliberately only on the last page — a disclaimer
  /// repeated under every page is noise, and a document is read to its end.
  pw.Widget _footerOf(pw.Context context, String number) {
    final bool isLastPage = context.pageNumber == context.pagesCount;
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: DocumentColors.border, width: 0.8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _row(
            children: <pw.Widget>[
              _text(
                localizations.reportGeneratedBy,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: DocumentColors.secondary,
                ),
              ),
              pw.Spacer(),
              // The number the header gives, on every page. A second, unexplained
              // code used to follow it.
              _text(
                number,
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: DocumentColors.secondary,
                ),
              ),
              pw.SizedBox(width: 10),
              _text(
                localizations.reportPageOf(
                  context.pageNumber,
                  context.pagesCount,
                ),
                style: const pw.TextStyle(
                  fontSize: 8,
                  color: DocumentColors.secondary,
                ),
              ),
            ],
          ),
          if (isLastPage) ...<pw.Widget>[
            pw.SizedBox(height: 4),
            _text(
              localizations.reportFooterNotice,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: DocumentColors.secondary,
              ),
              maxWidth: _contentWidth,
            ),
          ],
        ],
      ),
    );
  }
  /// One table implementation for both statements.
  ///
  /// A repeating header and a row that may not split keep a long payment history
  /// legible across a page break, which is where generated statements usually
  /// fall apart.
  ///
  /// The column order is reversed for a right-to-left document. This is the one
  /// place the direction is handled by hand, because the renderer's table lays
  /// its columns out by index and takes no direction — and a `Directionality`
  /// wrapper is not an option, since it would hide the table from the
  /// multi-page splitter.
  pw.Widget _table({
    required List<String> headers,
    required List<List<String>> rows,
    required List<double> widthFractions,
    required int numericFrom,
    List<String>? openingRow,
    List<String>? totalRow,
  }) {
    final List<int> order = _isRtl
        ? List<int>.generate(headers.length, (int i) => headers.length - 1 - i)
        : List<int>.generate(headers.length, (int i) => i);

    /// Whether a column's content sits on the far side of the reading order.
    bool atEndFor(int column) => column >= numericFrom;

    final double fractionTotal =
        widthFractions.fold<double>(0, (double a, double b) => a + b);
    double widthOf(int column) =>
        _contentWidth * widthFractions[column] / fractionTotal;

    pw.TableRow header() => pw.TableRow(
          repeat: true,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: DocumentColors.brand),
            ),
          ),
          children: <pw.Widget>[
            for (final int column in order)
              _cell(
                headers[column],
                atEnd: atEndFor(column),
                bold: true,
                color: DocumentColors.brand,
                size: 9,
                maxWidth: widthOf(column),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
              ),
          ],
        );

    pw.TableRow row(
      List<String> values,
      int index, {
      bool isTotal = false,
      bool isOpening = false,
    }) =>
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isTotal
                ? DocumentColors.brandTint
                : (isOpening
                    ? null
                    : (index.isEven ? DocumentColors.rowTint : null)),
            border: const pw.Border(
              bottom: pw.BorderSide(color: DocumentColors.border, width: 0.6),
            ),
          ),
          children: <pw.Widget>[
            for (final int column in order)
              _cell(
                column < values.length ? values[column] : '',
                atEnd: atEndFor(column),
                bold: isTotal,
                color: isTotal
                    ? DocumentColors.brand
                    : (isOpening ? DocumentColors.secondary : DocumentColors.ink),
                size: 9.5,
                maxWidth: widthOf(column),
                padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 5),
              ),
          ],
        );

    return pw.Table(
      // The renderer keys a width by where the cell is drawn, not by which
      // column it holds. Keyed by column, a right-to-left table gave the debt
      // title the due date's narrow width and the due date the title's.
      columnWidths: <int, pw.TableColumnWidth>{
        for (int position = 0; position < order.length; position++)
          position: pw.FlexColumnWidth(widthFractions[order[position]] * 10),
      },
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      children: <pw.TableRow>[
        header(),
        if (openingRow != null) row(openingRow, -1, isOpening: true),
        for (int i = 0; i < rows.length; i++) row(rows[i], i),
        if (totalRow != null)
          row(totalRow, rows.length, isTotal: true),
      ],
    );
  }

  /// One cell.
  ///
  /// The text is not wrapped here and no width is measured for it. It is handed
  /// the cell's own width and the renderer breaks the lines — which is the whole
  /// point: the width that is measured and the width that is drawn are then the
  /// same string, so a cell cannot overflow its column. This file used to wrap
  /// in logical order and draw in shaped order, and the two disagreed by a third
  /// on Arabic, which pushed the end of a long debt title off the page.
  pw.Widget _cell(
    String value, {
    required bool atEnd,
    required double size,
    required pw.EdgeInsets padding,
    bool bold = false,
    PdfColor? color,
    double? maxWidth,
  }) {
    return pw.Padding(
      padding: padding,
      child: pw.Align(
        alignment: atEnd ? _alignEnd : _alignStart,
        child: _text(
          value,
          atEnd: atEnd,
          style: pw.TextStyle(
            fontSize: size,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: color ?? DocumentColors.ink,
          ),
          maxWidth: maxWidth == null ? null : maxWidth - padding.horizontal,
        ),
      ),
    );
  }

}

/// Renders a debt statement as a real document.
///
/// The output is deliberately not a picture of the app: it is a financial
/// statement with its own header, summary, ledger table and footer, laid out for
/// the page rather than for a phone.
///
/// Two directions are in play, and the renderer handles neither well enough:
///
///  * **Text** with Arabic in it is set here. It is shaped ([pdfText]), broken
///    into lines, and each line's words are put in drawing order
///    ([visualWordOrder]) and drawn one by one, left to right. The renderer's
///    own right-to-left handling spaces words by their ink, re-shapes what it
///    is given and throws on some lines; it is used only for a word this file
///    cannot order, such as one mixing letters and digits, and for a word too
///    wide to fit a line. Latin and numeric text goes to the renderer as it is.
///  * **Layout** is explicit. The renderer's `Row` and `Column` take no
///    direction and the only way to give them one is a `Directionality`
///    ancestor — which cannot be used here, because it would hide the tables
///    from the multi-page splitter and a long payment history would throw
///    instead of flowing onto a second page. So rows are reversed here and
///    alignments are named sides rather than relative ones.
class StatementDocument extends _Sheet {
  StatementDocument({
    required this.data,
    required super.localizations,
    required super.formatting,
    required super.regularFont,
    required super.semiBoldFont,
    required super.mark,
  });

  final StatementData data;

  @override
  bool get _isRtl => data.language.isRtl;


  /// The room inside the party card, inside its padding.
  static const double _partyWidth = _contentWidth - 14 * 2;

  /// The room inside one of the two fact cards, inside its padding.
  static const double _factCellWidth = (_contentWidth - 10) / 2 - 11 * 2;

  /// The room inside the headline block, inside its padding.
  static const double _heroWidth = _contentWidth - 16 * 2;

  /// The person the statement is about. Every sentence on the page that says
  /// who owes whom names them, rather than saying "I" or "me": the page is read
  /// by the other party, for whom those words point the wrong way.
  String get _name =>
      _Sheet.shortened(data.personName.trim(), _Sheet.displayNameLimit);

  /// A debt title as a fixed-width cell can show it. The full title, when it
  /// was shortened, is printed again in the appendix.
  String _displayTitle(String value) {
    final String title = value.trim();
    return title.isEmpty
        ? localizations.reportUntitledDebt
        : _Sheet.shortened(title, _Sheet.displayTitleLimit);
  }

  /// Values whose full form is printed in the appendix because a fixed cell
  /// could only show their beginning.
  List<({String label, String value})> get _fullValues {
    final List<({String label, String value})> values =
        <({String label, String value})>[];
    if (data.personName.runes.length > _Sheet.displayNameLimit) {
      values.add((
        label: localizations.reportAppendixName,
        value: data.personName,
      ));
    }
    for (final StatementDebtLine line in data.debts) {
      if (line.title.trim().runes.length > _Sheet.displayTitleLimit) {
        values.add((
          label: localizations.reportAppendixDebtTitle,
          value: line.title.trim(),
        ));
      }
    }
    return values;
  }

  /// What the document calls itself.
  ///
  /// A statement whose every record is settled is not a statement any more: it
  /// is the page that says the account is closed, and it says so in its title.
  String get _documentTitle => data.isClearance
      ? localizations.reportClearanceTitle
      : localizations.reportStatementTitle;

  /// Builds the document.
  ///
  /// The footer is drawn by the page theme rather than by the body content, so a
  /// statement that runs to three pages still carries the generated-by line and a
  /// page number on every one of them.
  pw.Document build() {
    final pw.ThemeData theme = pw.ThemeData.withFont(
      base: _regular,
      bold: _semiBold,
    );

    final pw.Document document = pw.Document(
      title: '$_documentTitle · ${data.personName}',
      author: localizations.appName,
      subject: _documentTitle,
      creator: localizations.appName,
      producer: localizations.appName,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        maxPages: _Sheet.maxDocumentPages,
        margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 52),
        header: (pw.Context context) =>
            context.pageNumber == 1 ? pw.SizedBox() : _runningHeader(),
        footer: (pw.Context context) => _footer(context),
        build: (pw.Context context) => <pw.Widget>[
          _header(),
          pw.SizedBox(height: 20),
          _partyBlock(),
          pw.SizedBox(height: 18),
          _summaryBlock(),
          if (data.options.includeDebtBreakdown && data.debts.length > 1) ...<pw.Widget>[
            _keepWithNext(_tableLead),
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.reportDebtsBreakdown),
            pw.SizedBox(height: 8),
            _debtTable(),
          ],
          if (data.options.includePayments) ...<pw.Widget>[
            _keepWithNext(_tableLead),
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.reportMovementsTitle),
            pw.SizedBox(height: 8),
            // The two short words the balance column uses, spelled out once.
            // Only a two-sided statement needs them: with every debt on one
            // side the headline has already said whose balance it is.
            if (data.isMixed && data.entries.isNotEmpty) ...<pw.Widget>[
              _text(
                localizations.reportSideLegend(_name),
                style: const pw.TextStyle(
                  fontSize: 8.5,
                  color: DocumentColors.secondary,
                ),
                maxWidth: _contentWidth,
              ),
              pw.SizedBox(height: 6),
            ],
            _paymentsTable(),
          ],
          if (data.options.includeNotes &&
              data.notes != null &&
              data.notes!.trim().isNotEmpty) ...<pw.Widget>[
            _keepWithNext(_notesLead),
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.fieldNote),
            pw.SizedBox(height: 6),
            _notesBlock(data.notes!),
          ],
          if (_fullValues.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.reportAppendixTitle),
            pw.SizedBox(height: 6),
            _fullValuesBlock(),
          ],
        ],
      ),
    );

    return document;
  }

  /// The room a table needs to start on a page: its heading, the line under
  /// it, the column header, and two rows.
  static const double _tableLead = 115;

  /// The room the notes need to start: the heading and a couple of lines.
  static const double _notesLead = 70;

  /// Starts a new page unless [room] points are still free on this one.
  ///
  /// A table breaks between rows wherever the page ends, including straight
  /// after its header — and the heading above it is not part of the table at
  /// all, so it can be left behind on its own. A reader then finds «كشف
  /// الحركات» and a row of column names at the foot of one page and the figures
  /// they describe on the next. Asking for the room first keeps a section's
  /// opening and its first rows together; the table itself still flows.
  pw.Widget _keepWithNext(double room) => pw.NewPage(freeSpace: room);

  // --- Header --------------------------------------------------------------

  pw.Widget _header() => _headerOf(
        title: _documentTitle,
        number: data.documentNumber,
        issuedAt: data.generatedAt,
        periodFrom: data.periodFrom,
        periodTo: data.periodTo,
      );

  pw.Widget _runningHeader() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 14),
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: DocumentColors.border, width: 0.8),
        ),
      ),
      child: _row(
        children: <pw.Widget>[
          _text(
            '${localizations.appName} · $_documentTitle',
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: DocumentColors.secondary,
            ),
          ),
          pw.Spacer(),
          _text(
            _name,
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: DocumentColors.secondary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Party ---------------------------------------------------------------

  pw.Widget _partyBlock() {
    final bool showPhone = data.options.includePhone &&
        data.phone != null &&
        data.phone!.trim().isNotEmpty;

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // A hairline, not a tint: the page has one filled area and it is the
      // headline figure below, which is what the eye should land on.
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: DocumentColors.border, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _text(
            localizations.reportStatementFor,
            style: const pw.TextStyle(fontSize: 9, color: DocumentColors.secondary),
            maxWidth: _partyWidth,
          ),
          pw.SizedBox(height: 4),
          _text(
            _name,
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.ink,
            ),
            maxWidth: _partyWidth,
          ),
          if (showPhone) ...<pw.Widget>[
            pw.SizedBox(height: 3),
            _text(
              data.phone!.trim(),
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: DocumentColors.secondary,
              ),
            ),
          ],
          // Who it is from, when the user gave a name. Under a hairline, so the
          // two parties read as two, and absent altogether otherwise: an empty
          // "From:" would look like a field somebody forgot to fill in.
          if (data.options.issuerName.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 8),
            pw.Container(height: 0.6, color: DocumentColors.border),
            pw.SizedBox(height: 8),
            _summaryFact(
              localizations.reportIssuerLabel,
              data.options.issuerName.trim(),
              width: _partyWidth,
            ),
          ],
        ],
      ),
    );
  }

  // --- Summary -------------------------------------------------------------

  pw.Widget _summaryBlock() {
    final bool showProgress = !data.isMixed && data.totalMinor > 0;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _sectionTitle(localizations.reportAccountSummary),
        pw.SizedBox(height: 8),
        _heroBlock(),
        pw.SizedBox(height: 10),
        _row(children: _factCells()),
        if (showProgress) ...<pw.Widget>[
          pw.SizedBox(height: 10),
          _progressBar(),
        ],
        pw.SizedBox(height: 10),
        // The currency is stated once rather than repeated after every amount:
        // a column of "₹ 68,500 INR" is harder to scan than one of "₹ 68,500".
        _summaryFact(
          localizations.fieldCurrency,
          '${data.currency.code} · ${data.currency.symbol}',
        ),
        // A statement of one debt has no breakdown table, and its title used
        // to appear nowhere at all: the reader could not tell what it was for.
        if (data.debts.length == 1 &&
            data.debts.single.title.trim().isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 4),
          _summaryFact(
            localizations.reportColumnDebt,
            _displayTitle(data.debts.single.title),
          ),
        ],
        // What the statement covers, stated on the page. A filtered statement
        // that did not say so would read as the whole account, and the person
        // holding it would have no way to know a settled debt was left off.
        pw.SizedBox(height: 4),
        _summaryFact(localizations.reportScopeLabel, _scopeText()),
      ],
    );
  }

  /// The sentence and the figure the page leads with: what is left, and on whom.
  ///
  /// By name. «المتبقي عليّ» is true for the person who made the statement and
  /// backwards for the person reading it, and this page is made to be sent.
  (String, Money) _headline() {
    final Money nothing = Money(0, data.currency);
    // A clearance states the fact it exists to state, in one approved sentence,
    // and not a figure: the figure is zero, and the sentence says what that
    // means. The date is the one the records were stated through — the end of
    // a period, or the day the document was issued.
    if (data.isClearance) {
      final DateTime through = data.periodTo ?? data.generatedAt;
      return (
        localizations.reportClearanceSentence(formatting.date(through)),
        nothing,
      );
    }
    // A period is answered with the balance the account held when it ended:
    // the reader asked what was left at that moment, not what is left today.
    final int? closing = data.closingBalanceMinor;
    if (data.hasPeriod && closing != null) {
      if (closing == 0) return (localizations.reportNothingOutstanding, nothing);
      final bool owedByPerson = closing > 0;
      return (
        data.isMixed
            ? (owedByPerson
                ? localizations.reportNetOwedByName(_name)
                : localizations.reportNetOwedToName(_name))
            : (owedByPerson
                ? localizations.reportOwedByName(_name)
                : localizations.reportOwedToName(_name)),
        Money(closing.abs(), data.currency),
      );
    }
    if (data.isMixed) {
      // Positive when the user is owed on balance, which is the person owing.
      final int net = data.net.minorUnits;
      if (net == 0) return (localizations.reportNothingOutstanding, nothing);
      return (
        net > 0
            ? localizations.reportNetOwedByName(_name)
            : localizations.reportNetOwedToName(_name),
        Money(net.abs(), data.currency),
      );
    }
    final DebtDirection? side = data.direction;
    if (data.remainingMinor <= 0 || side == null) {
      return (
        data.remainingMinor <= 0
            ? localizations.reportNothingOutstanding
            : localizations.detailRemaining,
        data.remaining,
      );
    }
    return (
      // The user owes: the money is the person's. Otherwise the person owes it.
      side.isIOwe
          ? localizations.reportOwedToName(_name)
          : localizations.reportOwedByName(_name),
      data.remaining,
    );
  }

  /// The one filled block on the page: the answer to "how much, and on whom",
  /// then where the account stands.
  ///
  /// It replaced three equal boxes in which the figure that mattered was a
  /// point and a half larger than the two that did not.
  pw.Widget _heroBlock() {
    final (String sentence, Money amount) = _headline();
    final DateTime? due = data.dueAt;
    final String? dueTitle = data.dueDebtTitle == null
        ? null
        : _displayTitle(data.dueDebtTitle!);
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: DocumentColors.brandTint,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _text(
            sentence,
            style: const pw.TextStyle(
              fontSize: 10.5,
              color: DocumentColors.secondary,
            ),
            maxWidth: _heroWidth,
          ),
          pw.SizedBox(height: 5),
          _text(
            _money(amount),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.ink,
            ),
            maxWidth: _heroWidth,
          ),
          // A status is today's fact; a period is read at its own end. The
          // badge is left off rather than stating a state the period cannot
          // have.
          if (!data.hasPeriod) ...<pw.Widget>[
            pw.SizedBox(height: 10),
            _rowOnReadingSide(<pw.Widget>[_statusBadge()]),
          ],
          if (due != null) ...<pw.Widget>[
            pw.SizedBox(height: 8),
            _summaryFact(
              // With several debts the date belongs to one of them, and is
              // named; with one it can only be that debt's.
              dueTitle == null
                  ? localizations.detailDueOn
                  : localizations.reportNextDue,
              dueTitle == null
                  ? formatting.date(due)
                  : '${formatting.date(due)} · $dueTitle',
              width: _heroWidth,
            ),
          ],
        ],
      ),
    );
  }

  /// The two figures behind the headline.
  ///
  /// On one side: what the debts came to and what has been paid. On both: each
  /// side on its own, by name — adding them would describe no one's position.
  List<pw.Widget> _factCells() {
    if (data.isMixed) {
      return <pw.Widget>[
        _factCell(
          label: localizations.reportSideByName(_name),
          value: _money(data.owedToMe),
        ),
        pw.SizedBox(width: 10),
        _factCell(
          label: localizations.reportSideToName(_name),
          value: _money(data.iOwe),
        ),
      ];
    }
    return <pw.Widget>[
      _factCell(
        label: localizations.detailTotal,
        value: _money(data.total),
      ),
      pw.SizedBox(width: 10),
      _factCell(
        label: localizations.reportColumnPaid,
        value: _money(data.paid),
        valueColor: DocumentColors.settled,
      ),
    ];
  }

  pw.Widget _factCell({
    required String label,
    required String value,
    PdfColor? valueColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: DocumentColors.border, width: 0.8),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: <pw.Widget>[
            _text(
              label,
              style: const pw.TextStyle(
                fontSize: 8.5,
                color: DocumentColors.secondary,
              ),
              maxWidth: _factCellWidth,
            ),
            pw.SizedBox(height: 4),
            _text(
              value,
              style: pw.TextStyle(
                fontSize: 11.5,
                fontWeight: pw.FontWeight.bold,
                color: valueColor ?? DocumentColors.ink,
              ),
              maxWidth: _factCellWidth,
            ),
          ],
        ),
      ),
    );
  }

  /// How much of the total has been paid, as a bar and as a figure.
  ///
  /// Two rectangles in two tones, so it reads on a black-and-white printout,
  /// and the percentage beside it says the same thing in words. Not drawn for
  /// a two-sided statement, where "paid" would add two people's payments.
  pw.Widget _progressBar() {
    final double fraction =
        (data.paidMinor / data.totalMinor).clamp(0.0, 1.0).toDouble();
    // A sliver stays visible: one payment on a large debt is still a payment.
    final double filled = fraction <= 0
        ? 0
        : (_contentWidth * fraction).clamp(3.0, _contentWidth).toDouble();
    final double rest = _contentWidth - filled;
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _row(
          children: <pw.Widget>[
            if (filled > 0)
              pw.Container(
                width: filled,
                height: 5,
                color: DocumentColors.brand,
              ),
            if (rest > 0.5)
              pw.Container(
                width: rest - 0.5,
                height: 5,
                color: DocumentColors.border,
              ),
          ],
        ),
        pw.SizedBox(height: 4),
        _text(
          localizations.reportPaidPercent(formatting.percent(fraction)),
          style: const pw.TextStyle(
            fontSize: 8.5,
            color: DocumentColors.secondary,
          ),
          maxWidth: _contentWidth,
        ),
      ],
    );
  }

  /// The scope in words, and how many settled debts it left out.
  ///
  /// Archived debts are not counted here on purpose: archiving is the user's
  /// own filing, and this page is read by someone else.
  String _scopeText() {
    final String scope = switch (data.options.scope) {
      StatementScope.openOnly => localizations.reportScopeOpenFull,
      StatementScope.all => localizations.reportScopeAllFull,
      StatementScope.selected => localizations.reportScopeSelectedFull,
    };
    final String period = data.hasPeriod
        ? ' · ${localizations.reportPeriod}: '
            '${localizations.reportPeriodRange(
              formatting.date(data.periodFrom!),
              formatting.date(data.periodTo!),
            )}'
        : '';
    if (data.hiddenSettledCount <= 0) return '$scope$period';
    return '$scope$period · '
        '${localizations.reportHiddenSettled(data.hiddenSettledCount)}';
  }

  /// Status as a word plus a shape.
  ///
  /// The shape carries the meaning for anyone who cannot separate the colours,
  /// and the word carries it for anyone reading a greyscale printout.
  pw.Widget _statusBadge() {
    // A clearance always carries the closed state, whatever the individual
    // records were filed as: the badge is part of what the document says.
    final (PdfColor color, bool filled, String label) = data.isClearance
        ? (DocumentColors.settled, true, localizations.statusPaid)
        : switch (data.status) {
      DebtLifecycleStatus.paid => (
          DocumentColors.settled,
          true,
          localizations.statusPaid,
        ),
      DebtLifecycleStatus.overdue => (
          DocumentColors.overdue,
          true,
          localizations.statusOverdue,
        ),
      DebtLifecycleStatus.dueToday => (
          DocumentColors.dueSoon,
          true,
          localizations.statusDueToday,
        ),
      DebtLifecycleStatus.dueSoon => (
          DocumentColors.dueSoon,
          false,
          localizations.statusDueSoon,
        ),
      DebtLifecycleStatus.upcoming => (
          DocumentColors.neutral,
          false,
          localizations.statusUpcoming,
        ),
      DebtLifecycleStatus.active => (
          DocumentColors.neutral,
          false,
          localizations.statusActive,
        ),
      DebtLifecycleStatus.archived => (
          DocumentColors.muted,
          false,
          localizations.statusArchived,
        ),
    };

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: color, width: 0.9),
        borderRadius: pw.BorderRadius.circular(9),
      ),
      child: _row(
        children: <pw.Widget>[
          pw.Container(
            width: 6.5,
            height: 6.5,
            decoration: pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: filled ? color : PdfColors.white,
              border: pw.Border.all(color: color),
            ),
          ),
          pw.SizedBox(width: 6),
          _text(
            label,
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // --- Tables --------------------------------------------------------------

  /// A section heading: the gold rule, then the title, on the reading side.
  pw.Widget _sectionTitle(String title) {
    return _rowOnReadingSide(<pw.Widget>[
      pw.Container(width: 3, height: 13, color: DocumentColors.gold),
      pw.SizedBox(width: 7),
      _text(
        title,
        style: pw.TextStyle(
          fontSize: 11.5,
          fontWeight: pw.FontWeight.bold,
          color: DocumentColors.ink,
        ),
      ),
    ]);
  }

  /// The side a debt is on, from the person's point of view and in one word.
  ///
  /// The user owing is the person being owed. The two words are spelled out
  /// once above the movements, by name.
  String _sideWord(DebtDirection direction) => direction.isIOwe
      ? localizations.reportSideIsOwed
      : localizations.reportSideOwes;

  pw.Widget _debtTable() {
    final bool mixed = data.isMixed;
    // A status column states today's state. A period has no such state to
    // state, so the column is left out rather than filled with a present-tense
    // word beside figures that belong to another day.
    final bool showStatus = !data.hasPeriod;
    final List<String> headers = <String>[
      localizations.reportColumnDebt,
      // Which side each debt is on only needs saying when there are two.
      if (mixed) localizations.reportColumnSide,
      localizations.reportColumnTotal,
      localizations.reportColumnPaid,
      localizations.reportColumnRemaining,
      localizations.reportColumnDue,
      if (showStatus) localizations.reportColumnStatus,
    ];

    final List<List<String>> rows = <List<String>>[
      for (final StatementDebtLine line in data.debts)
        <String>[
          _displayTitle(line.title),
          if (mixed) _sideWord(line.direction),
          _money(line.principal),
          _money(line.paid),
          _money(line.remaining),
          // The month as a word. `7/10/2026` is the seventh of October to one
          // reader and the tenth of July to another, and a due date is the
          // last thing a statement can afford to be read two ways.
          line.dueAt == null ? '—' : formatting.date(line.dueAt!),
          // In words: a settled debt used to be told apart only by the zero
          // in its remaining column.
          if (showStatus) line.status.label(localizations),
        ],
    ];

    return _table(
      headers: headers,
      rows: rows,
      widthFractions: showStatus
          ? (mixed
              ? const <double>[0.22, 0.08, 0.14, 0.13, 0.14, 0.16, 0.13]
              : const <double>[0.24, 0.15, 0.14, 0.15, 0.17, 0.15])
          : (mixed
              ? const <double>[0.24, 0.09, 0.15, 0.14, 0.15, 0.23]
              : const <double>[0.27, 0.17, 0.16, 0.18, 0.22]),
      numericFrom: mixed ? 2 : 1,
      // A total adds like to like. With debts on both sides the summary above
      // states each side and the difference, and one row adding them would not.
      totalRow: mixed
          ? null
          : <String>[
              localizations.totalLabel,
              _money(data.total),
              _money(data.paid),
              _money(data.remaining),
              '',
              if (showStatus) '',
            ],
    );
  }

  pw.Widget _paymentsTable() {
    // Without a period an empty history is an empty box. With one it is still a
    // table: the opening balance and the closing balance are both facts, even
    // when nothing moved in between.
    if (data.entries.isEmpty && !data.hasPeriod) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: DocumentColors.border),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: _text(
          localizations.detailNoPayments,
          style: const pw.TextStyle(
            fontSize: 10,
            color: DocumentColors.secondary,
          ),
          maxWidth: _contentWidth - 12 * 2,
        ),
      );
    }

    final List<String> headers = <String>[
      localizations.reportColumnDate,
      localizations.reportColumnOperation,
      localizations.reportColumnDebtAmount,
      localizations.reportColumnPaymentAmount,
      localizations.reportColumnBalance,
    ];

    // A debt and a payment each have their own column. They used to share one
    // "amount", and whether a line raised the balance or lowered it could only
    // be learned by reading its description.
    final List<List<String>> rows = <List<String>>[
      for (final StatementEntry entry in data.entries)
        <String>[
          formatting.date(entry.date),
          _entryLabel(entry, withNote: data.options.includeNotes),
          entry.kind == StatementEntryKind.debtCreated
              ? _money(entry.amount)
              : '',
          entry.kind == StatementEntryKind.payment ? _money(entry.amount) : '',
          _balanceLabel(entry),
        ],
    ];

    // What the account held the morning the period began. It carries no date
    // and no amount of its own: it is everything that came before, already
    // summed. Printed only when a period is stated — without one the first row
    // is the first thing that ever happened, so there is nothing before it.
    final List<String>? openingRow = data.hasPeriod
        ? <String>[
            '',
            localizations.reportOpeningBalance,
            '',
            '',
            _signedBalanceLabel(data.openingBalanceMinor),
          ]
        : null;

    final int? closing = data.closingBalanceMinor;
    return _table(
      headers: headers,
      rows: rows,
      openingRow: openingRow,
      // A two-sided balance also names its side, and needs the room.
      widthFractions: data.isMixed
          ? const <double>[0.19, 0.26, 0.15, 0.15, 0.25]
          : const <double>[0.2, 0.32, 0.16, 0.16, 0.16],
      numericFrom: 2,
      // Where the account stands after the last line, set apart so nobody has
      // to find the bottom row to learn it. It is the headline figure again,
      // reached the long way. Within a period it is the balance the period
      // closed on; the last printed movement can be earlier than that.
      totalRow: <String>[
        localizations.reportClosingBalance,
        '',
        '',
        '',
        data.hasPeriod && closing != null
            ? _signedBalanceLabel(closing)
            : _balanceLabel(data.entries.last),
      ],
    );
  }

  /// What a history line records: a debt, or a payment on one.
  ///
  /// It no longer says whose — «دين عليّ», «دفعة مستلمة» — because those were
  /// the maker's words. Which column the amount sits in says what happened, and
  /// the balance beside it says where that leaves the two parties.
  ///
  /// With [withNote] a payment's own note is set on a second line under it. A
  /// payment made against several debts at once carries the same note on each
  /// of its lines, so each says where its money came from. Off unless the
  /// statement's notes option is on: a note is often the user's own reminder.
  String _entryLabel(StatementEntry entry, {bool withNote = false}) {
    final String base = switch (entry.kind) {
      StatementEntryKind.debtCreated => localizations.reportEntryDebt,
      StatementEntryKind.payment => localizations.reportEntryPayment,
      StatementEntryKind.settled => localizations.debtClosed,
    };
    // Which debt the line belongs to, when there is more than one to tell
    // apart. A payment used to be named by nothing at all.
    final String? title = entry.debtTitle;
    final String label =
        title != null && data.debts.length > 1 ? '$base · $title' : base;
    final String? note = entry.note?.trim();
    if (!withNote || note == null || note.isEmpty) return label;
    return '$label\n$note';
  }

  /// The balance after a line. With debts on both sides the figure alone does
  /// not say who it favours, so the side is named with it — in the person's
  /// terms, with the two words explained above the table.
  ///
  /// The side comes first, which leaves the figure against the column's edge
  /// in both directions, level with the amounts beside it. Named after the
  /// figure, the two words are different widths and moved it.
  String _balanceLabel(StatementEntry entry) {
    final String amount = _money(entry.balanceAfter);
    final DebtDirection? side = entry.balanceDirection;
    if (!data.isMixed || side == null) return amount;
    return '${_sideWord(side)} · $amount';
  }

  /// A balance the document computed itself, from a signed figure.
  ///
  /// Positive means the user is owed. A printed row carries its side and its
  /// amount in separate places; the opening and closing rows are sums of many
  /// rows, so the sign is the only thing that says which side they fall on.
  String _signedBalanceLabel(int signedMinor) {
    final String amount =
        _money(Money(signedMinor.abs(), data.currency));
    if (!data.isMixed || signedMinor == 0) return amount;
    return '${_sideWord(signedMinor > 0
        ? DebtDirection.owedToMe
        : DebtDirection.iOwe)} · $amount';
  }

  pw.Widget _notesBlock(String notes) {
    final List<String> chunks = _Sheet.textChunks(notes.trim());
    // A short note keeps the bordered box it has always had. A note too tall
    // for one page is printed in pieces instead: one box per piece is the only
    // shape the paginator can break between.
    if (chunks.length == 1) {
      return pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(11),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: DocumentColors.border),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: _text(
          notes,
          style: const pw.TextStyle(
            fontSize: 10,
            color: DocumentColors.ink,
            lineSpacing: 2,
          ),
          maxWidth: _contentWidth - 11 * 2,
        ),
      );
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        for (final String chunk in chunks)
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              horizontal: 11,
              vertical: 5,
            ),
            decoration: pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: DocumentColors.border,
                  width: 0.6,
                ),
              ),
            ),
            child: _text(
              chunk,
              style: const pw.TextStyle(
                fontSize: 10,
                color: DocumentColors.ink,
                lineSpacing: 2,
              ),
              maxWidth: _contentWidth - 11 * 2,
            ),
          ),
      ],
    );
  }

  /// The full form of every value a fixed cell had to shorten.
  pw.Widget _fullValuesBlock() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        for (final ({String label, String value}) entry in _fullValues) ...<
            pw.Widget>[
          _text(
            '${entry.label}:',
            style: const pw.TextStyle(
              fontSize: 8.5,
              color: DocumentColors.secondary,
            ),
            maxWidth: _contentWidth,
          ),
          for (final String chunk in _Sheet.textChunks(entry.value))
            _text(
              chunk,
              style: const pw.TextStyle(
                fontSize: 9.5,
                color: DocumentColors.ink,
              ),
              maxWidth: _contentWidth,
            ),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  pw.Widget _footer(pw.Context context) =>
      _footerOf(context, data.documentNumber);
}
