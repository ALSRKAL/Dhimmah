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
/// Two directions are in play and they are handled in different places, because
/// the renderer supports one of them and not the other:
///
///  * **Text** is given its own direction and the renderer does the rest —
///    the Unicode bidirectional algorithm, line arrangement from the reading
///    side, and line breaking. See [pdfText] for why that matters.
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

  /// The width of the text area, in points.
  static const double _contentWidth = 595.276 - 38 * 2;

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
  ///  * **Direction** follows the string. An Arabic string is handed to the
  ///    renderer as right-to-left so it is reordered and arranged properly; a
  ///    Latin or numeric one is handed over left-to-right, because the renderer
  ///    reorders *every* right-to-left paragraph by reversing its words, and
  ///    `₹ 45,500` would come out as `45,500 ₹`.
  ///  * **Alignment** follows the document, then the string. A label sits on the
  ///    reading side; a number sits on the far side so a column of amounts lines
  ///    up. The renderer expresses both as `start`/`end` *of the string's own
  ///    direction*, so the side is converted here.
  pw.Widget _text(
    String logical, {
    required pw.TextStyle style,
    bool atEnd = false,
  }) {
    final bool rtl = containsArabic(logical);
    final bool alignRight = atEnd ? !_isRtl : _isRtl;
    return pw.Text(
      pdfText(logical),
      textDirection:
          rtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      textAlign: alignRight
          ? (rtl ? pw.TextAlign.start : pw.TextAlign.end)
          : (rtl ? pw.TextAlign.end : pw.TextAlign.start),
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
          ),
          pw.SizedBox(height: 4),
          _text(
            data.personName,
            style: pw.TextStyle(
              fontSize: 15,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.brand,
            ),
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
        _rowOnReadingSide(<pw.Widget>[
          _text(
            '${localizations.fieldCurrency}:',
            style: const pw.TextStyle(
              fontSize: 9,
              color: DocumentColors.secondary,
            ),
          ),
          pw.SizedBox(width: 5),
          _text(
            '${data.currency.code} · ${data.currency.symbol}',
            style: pw.TextStyle(
              fontSize: 9.5,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.ink,
            ),
          ),
        ]),
        pw.SizedBox(height: 8),
        _row(
          children: <pw.Widget>[
            _summaryCell(
              label: localizations.detailTotal,
              value: _money(data.total),
              emphasis: false,
            ),
            pw.SizedBox(width: 10),
            _summaryCell(
              label: localizations.detailPaid,
              value: _money(data.paid),
              emphasis: false,
              valueColor: DocumentColors.settled,
            ),
            pw.SizedBox(width: 10),
            _summaryCell(
              label: localizations.detailRemaining,
              value: _money(data.remaining),
              emphasis: true,
            ),
          ],
        ),
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
            ),
            pw.SizedBox(height: 4),
            _text(
              value,
              style: pw.TextStyle(
                fontSize: emphasis ? 14 : 12.5,
                fontWeight: pw.FontWeight.bold,
                color: valueColor ?? DocumentColors.ink,
              ),
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
      totalRow: <String>[
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
          _money(entry.balanceAfter),
        ],
    ];

    return _table(
      headers: headers,
      rows: rows,
      widthFractions: const <double>[0.22, 0.34, 0.22, 0.22],
      numericFrom: 2,
    );
  }

  String _entryLabel(StatementEntry entry) {
    final String base = switch (entry.kind) {
      StatementEntryKind.debtCreated => localizations.activityDebtCreated,
      StatementEntryKind.payment => localizations.activityPaymentRecorded,
      StatementEntryKind.settled => localizations.debtClosed,
    };
    // When a row is one debt among several, naming it makes the table readable.
    if (entry.kind == StatementEntryKind.debtCreated &&
        entry.note != null &&
        data.debts.length > 1) {
      return '$base · ${entry.note}';
    }
    return base;
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
      columnWidths: <int, pw.TableColumnWidth>{
        for (int i = 0; i < widthFractions.length; i++)
          i: pw.FlexColumnWidth(widthFractions[i] * 10),
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
          _text(
            '${data.documentNumber} · ${data.documentId}',
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
