import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/enums/debt_enums.dart';
import '../../l10n/generated/app_localizations.dart';
import '../brand/brand_mark.dart';
import '../formatting/app_formatting.dart';
import '../money/money.dart';
import 'pdf_text.dart';
import 'statement_models.dart';

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
class StatementDocument {
  StatementDocument({
    required this.data,
    required this.localizations,
    required this.formatting,
    required this.regularFont,
    required this.semiBoldFont,
    required this.mark,
  });

  final StatementData data;
  final AppLocalizations localizations;
  final AppFormatting formatting;
  final ByteData regularFont;
  final ByteData semiBoldFont;

  /// The brand mark, as the artwork rather than a redrawing of it.
  final BrandMark mark;

  bool get _isRtl => data.language.isRtl;

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

  /// The width of the text area, in points.
  static const double _contentWidth = 595.276 - 38 * 2;

  /// The room inside the party card, inside its padding.
  static const double _partyWidth = _contentWidth - 14 * 2;

  /// The room inside one of the three summary cards, inside its padding.
  static const double _summaryCellWidth = (_contentWidth - 10 * 2) / 3 - 11 * 2;

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
      title: '${localizations.reportStatementTitle} · ${data.personName}',
      author: localizations.appName,
      subject: localizations.reportStatementTitle,
      creator: localizations.appName,
      producer: localizations.appName,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
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
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.reportDebtsBreakdown),
            pw.SizedBox(height: 8),
            _debtTable(),
          ],
          if (data.options.includePayments) ...<pw.Widget>[
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.reportPaymentHistory),
            pw.SizedBox(height: 8),
            _paymentsTable(),
          ],
          if (data.options.includeNotes &&
              data.notes != null &&
              data.notes!.trim().isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 20),
            _sectionTitle(localizations.fieldNote),
            pw.SizedBox(height: 6),
            _notesBlock(data.notes!),
          ],
        ],
      ),
    );

    return document;
  }

  // --- Header --------------------------------------------------------------

  pw.Widget _header() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _row(
          children: <pw.Widget>[
            _brandLockup(),
            pw.Spacer(),
            _documentIdentity(),
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
  pw.Widget _brandLockup() {
    return _row(
      children: <pw.Widget>[
        mark.widget(height: 28),
        pw.SizedBox(width: 10),
        pw.Column(
          crossAxisAlignment: _crossStart,
          children: <pw.Widget>[
            _text(
              localizations.appName,
              style: pw.TextStyle(
                fontSize: 17,
                fontWeight: pw.FontWeight.bold,
                color: DocumentColors.brand,
              ),
            ),
            _text(
              localizations.reportStatementTitle,
              style: const pw.TextStyle(
                fontSize: 10.5,
                color: DocumentColors.secondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Document number and date, on the opposite side.
  pw.Widget _documentIdentity() {
    pw.Widget line(String label, String value) => _row(
          children: <pw.Widget>[
            _text(
              label,
              style: const pw.TextStyle(
                fontSize: 9,
                color: DocumentColors.muted,
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

    return pw.Column(
      crossAxisAlignment: _crossStart,
      children: <pw.Widget>[
        line(localizations.reportDocumentNumber, data.documentNumber),
        pw.SizedBox(height: 3),
        line(
          localizations.reportIssuedOn,
          formatting.date(data.generatedAt),
        ),
      ],
    );
  }

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
            '${localizations.appName} · ${localizations.reportStatementTitle}',
            style: const pw.TextStyle(fontSize: 8.5, color: DocumentColors.muted),
          ),
          pw.Spacer(),
          _text(
            data.personName,
            style: const pw.TextStyle(fontSize: 8.5, color: DocumentColors.muted),
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
      decoration: pw.BoxDecoration(
        color: DocumentColors.brandTint,
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
            data.personName,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.brand,
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
        ],
      ),
    );
  }

  // --- Summary -------------------------------------------------------------

  pw.Widget _summaryBlock() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _sectionTitle(localizations.reportAccountSummary),
        pw.SizedBox(height: 8),
        // The currency is stated once, at the top of the summary, rather than
        // repeated after every amount: a column of "₹ 68,500 INR" is harder to
        // scan than a column of "₹ 68,500".
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
            data.debts.single.title.trim(),
          ),
        ],
        pw.SizedBox(height: 8),
        _row(children: data.isMixed ? _twoSidedCells() : _oneSidedCells()),
        pw.SizedBox(height: 10),
        _rowOnReadingSide(<pw.Widget>[
          _statusBadge(),
          pw.SizedBox(width: 10),
          if (data.dueAt != null)
            _inlineFact(
              localizations.detailDueOn,
              formatting.date(data.dueAt!),
            ),
        ]),
      ],
    );
  }

  /// One labelled line of the summary, on the reading side: the currency, or
  /// the one debt a statement is about.
  pw.Widget _summaryFact(String label, String value) {
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
          maxWidth: _contentWidth - _advance(labelText, labelStyle) - 5,
        ),
      ),
    ]);
  }

  /// Every debt on one side: what it came to, what was paid, and what is left,
  /// with the side named, since the figures alone do not say who owes whom.
  List<pw.Widget> _oneSidedCells() {
    final DebtDirection? side = data.direction;
    return <pw.Widget>[
      _summaryCell(
        label: localizations.detailTotal,
        value: _money(data.total),
        emphasis: false,
      ),
      pw.SizedBox(width: 10),
      _summaryCell(
        label: localizations.reportColumnPaid,
        value: _money(data.paid),
        emphasis: false,
        valueColor: DocumentColors.settled,
      ),
      pw.SizedBox(width: 10),
      _summaryCell(
        label: side == null
            ? localizations.detailRemaining
            : side.isIOwe
                ? localizations.reportRemainingIOwe
                : localizations.reportRemainingOwedToMe,
        value: _money(data.remaining),
        emphasis: true,
      ),
    ];
  }

  /// Debts on both sides: each side, and the difference, as the person's page
  /// states it. Adding the two sides, as the cards used to, gave a total, a
  /// paid and a remaining figure that described no one's position.
  List<pw.Widget> _twoSidedCells() {
    final int net = data.net.minorUnits;
    return <pw.Widget>[
      _summaryCell(
        label: localizations.navOwedToMe,
        value: _money(data.owedToMe),
        emphasis: false,
      ),
      pw.SizedBox(width: 10),
      _summaryCell(
        label: localizations.navIOwe,
        value: _money(data.iOwe),
        emphasis: false,
      ),
      pw.SizedBox(width: 10),
      _summaryCell(
        label: net > 0
            ? localizations.reportNetOwedToMe
            : net < 0
                ? localizations.reportNetIOwe
                : localizations.dashboardBalanced,
        value: _money(Money(net.abs(), data.currency)),
        emphasis: true,
      ),
    ];
  }

  pw.Widget _summaryCell({
    required String label,
    required String value,
    required bool emphasis,
    PdfColor? valueColor,
  }) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(
            color: emphasis ? DocumentColors.brand : DocumentColors.border,
            width: emphasis ? 1.2 : 0.8,
          ),
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
              maxWidth: _summaryCellWidth,
            ),
            pw.SizedBox(height: 4),
            _text(
              value,
              style: pw.TextStyle(
                fontSize: emphasis ? 14 : 12.5,
                fontWeight: pw.FontWeight.bold,
                color: valueColor ?? DocumentColors.ink,
              ),
              maxWidth: _summaryCellWidth,
            ),
          ],
        ),
      ),
    );
  }

  /// Status as a word plus a shape.
  ///
  /// The shape carries the meaning for anyone who cannot separate the colours,
  /// and the word carries it for anyone reading a greyscale printout.
  pw.Widget _statusBadge() {
    final (PdfColor color, bool filled, String label) = switch (data.status) {
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

  pw.Widget _inlineFact(String label, String value) {
    return _row(
      children: <pw.Widget>[
        _text(
          '$label:',
          style: const pw.TextStyle(
            fontSize: 9.5,
            color: DocumentColors.secondary,
          ),
        ),
        pw.SizedBox(width: 5),
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

  pw.Widget _debtTable() {
    final List<String> headers = <String>[
      localizations.reportColumnDebt,
      localizations.reportColumnDirection,
      localizations.reportColumnTotal,
      localizations.reportColumnPaid,
      localizations.reportColumnRemaining,
      localizations.reportColumnDue,
    ];

    final List<List<String>> rows = <List<String>>[
      for (final StatementDebtLine line in data.debts)
        <String>[
          line.title.trim().isEmpty ? localizations.unknownPerson : line.title,
          line.direction.isIOwe
              ? localizations.navIOwe
              : localizations.navOwedToMe,
          _money(line.principal),
          _money(line.paid),
          _money(line.remaining),
          line.dueAt == null
              ? localizations.dateNoDueDate
              : formatting.dates.numeric(line.dueAt!),
        ],
    ];

    return _table(
      headers: headers,
      rows: rows,
      widthFractions: const <double>[0.26, 0.13, 0.16, 0.15, 0.16, 0.14],
      numericFrom: 2,
      // A total adds like to like. With debts on both sides the summary above
      // states each side and the difference, and one row adding them would not.
      totalRow: data.isMixed
          ? null
          : <String>[
              localizations.totalLabel,
              '',
              _money(data.total),
              _money(data.paid),
              _money(data.remaining),
              '',
            ],
    );
  }

  pw.Widget _paymentsTable() {
    if (data.entries.isEmpty) {
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
      localizations.reportColumnAmount,
      localizations.reportColumnBalance,
    ];

    final List<List<String>> rows = <List<String>>[
      for (final StatementEntry entry in data.entries)
        <String>[
          formatting.dates.numeric(entry.date),
          _entryLabel(entry),
          entry.kind == StatementEntryKind.settled
              ? '—'
              : _money(entry.amount),
          _balanceLabel(entry),
        ],
    ];

    return _table(
      headers: headers,
      rows: rows,
      // A two-sided balance also names its side, and needs the room.
      widthFractions: data.isMixed
          ? const <double>[0.19, 0.33, 0.2, 0.28]
          : const <double>[0.22, 0.34, 0.22, 0.22],
      numericFrom: 2,
    );
  }

  /// What a history line records, in the words of a statement rather than of
  /// the app's activity feed ("debt created", "payment recorded"), and on which
  /// side: money lent or borrowed, a payment received or made.
  String _entryLabel(StatementEntry entry) {
    final bool iOwe = entry.direction.isIOwe;
    final String base = switch (entry.kind) {
      StatementEntryKind.debtCreated => iOwe
          ? localizations.reportEntryIOwe
          : localizations.reportEntryOwedToMe,
      StatementEntryKind.payment => iOwe
          ? localizations.reportEntryPaid
          : localizations.reportEntryReceived,
      StatementEntryKind.settled => localizations.debtClosed,
    };
    // Which debt the line belongs to, when there is more than one to tell
    // apart. A payment used to be named by nothing at all.
    final String? title = entry.debtTitle;
    if (title != null && data.debts.length > 1) return '$base · $title';
    return base;
  }

  /// The balance after a line. With debts on both sides the figure alone does
  /// not say who it favours, so the side is named with it.
  ///
  /// The side comes first, which leaves the figure against the column's edge
  /// in both directions, level with the amounts beside it. Named after the
  /// figure, «لي» and «عليّ» are different widths and moved it.
  String _balanceLabel(StatementEntry entry) {
    final String amount = _money(entry.balanceAfter);
    final DebtDirection? side = entry.balanceDirection;
    if (!data.isMixed || side == null) return amount;
    final String sideName =
        side.isIOwe ? localizations.navIOwe : localizations.navOwedToMe;
    return '$sideName · $amount';
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

    pw.TableRow row(List<String> values, int index, {bool isTotal = false}) =>
        pw.TableRow(
          decoration: pw.BoxDecoration(
            color: isTotal
                ? DocumentColors.brandTint
                : (index.isEven ? DocumentColors.rowTint : null),
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
                color: isTotal ? DocumentColors.brand : DocumentColors.ink,
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

  pw.Widget _notesBlock(String notes) {
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

  pw.Widget _footer(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.only(top: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: DocumentColors.border, width: 0.8),
        ),
      ),
      child: _row(
        children: <pw.Widget>[
          _text(
            localizations.reportGeneratedBy,
            style: const pw.TextStyle(fontSize: 8, color: DocumentColors.muted),
          ),
          pw.Spacer(),
          // The number the header gives, on every page. A second, unexplained
          // code used to follow it.
          _text(
            data.documentNumber,
            style: const pw.TextStyle(fontSize: 8, color: DocumentColors.muted),
          ),
          pw.SizedBox(width: 10),
          _text(
            localizations.reportPageOf(
              context.pageNumber,
              context.pagesCount,
            ),
            style: const pw.TextStyle(fontSize: 8, color: DocumentColors.muted),
          ),
        ],
      ),
    );
  }
}
