part of 'statement_document.dart';

/// Renders the receipt for one payment.
///
/// One page, set with the same tools as the statement ([_Sheet]) so the two are
/// plainly from the same hand: the same header, the same rules, the same way of
/// drawing Arabic. It says who paid whom by name — «استُلم من أحمد», not "I
/// received" — for the reason the statement does: it is handed to the other
/// party, who would read "I" as themselves.
class ReceiptDocument extends _Sheet {
  ReceiptDocument({
    required this.data,
    required super.localizations,
    required super.formatting,
    required super.regularFont,
    required super.semiBoldFont,
    required super.mark,
  });

  final ReceiptData data;

  @override
  bool get _isRtl => data.language.isRtl;

  /// The room inside a bordered or tinted block, inside its padding.
  static const double _blockWidth = _contentWidth - 16 * 2;

  String get _title => data.isReceived
      ? localizations.receiptTitleIn
      : localizations.receiptTitleOut;

  pw.Document build() {
    final pw.Document document = pw.Document(
      title: '$_title · ${data.personName}',
      author: localizations.appName,
      subject: _title,
      creator: localizations.appName,
      producer: localizations.appName,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: _regular, bold: _semiBold),
        margin: const pw.EdgeInsets.fromLTRB(38, 34, 38, 52),
        footer: (pw.Context context) => _footerOf(context, data.number),
        build: (pw.Context context) => <pw.Widget>[
          _headerOf(
            title: _title,
            number: data.number,
            issuedAt: data.issuedAt,
          ),
          pw.SizedBox(height: 20),
          _partiesBlock(),
          pw.SizedBox(height: 14),
          _amountBlock(),
          pw.SizedBox(height: 14),
          // No signature line: the developer took the signature box out of
          // the documents (PLAN.md ق13).
          _detailsBlock(),
        ],
      ),
    );
    return document;
  }

  /// Who the money moved between, by name.
  pw.Widget _partiesBlock() {
    final String issuer = data.issuerName.trim();
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: DocumentColors.border, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: <pw.Widget>[
          _summaryFact(
            data.isReceived
                ? localizations.receiptReceivedFrom
                : localizations.receiptPaidTo,
            data.personName.trim(),
            width: _blockWidth,
          ),
          // The other half of the sentence, when the user gave their name.
          // Left off rather than printed empty otherwise.
          if (issuer.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 6),
            _summaryFact(
              data.isReceived
                  ? localizations.receiptReceivedBy
                  : localizations.receiptPaidBy,
              issuer,
              width: _blockWidth,
            ),
          ],
        ],
      ),
    );
  }

  /// The figure, in the one filled block on the page.
  pw.Widget _amountBlock() {
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
            localizations.reportColumnAmount,
            style: const pw.TextStyle(
              fontSize: 10.5,
              color: DocumentColors.secondary,
            ),
            maxWidth: _blockWidth,
          ),
          pw.SizedBox(height: 5),
          _text(
            _money(data.amount),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: DocumentColors.ink,
            ),
            maxWidth: _blockWidth,
          ),
        ],
      ),
    );
  }

  /// When, what for, and what it leaves.
  pw.Widget _detailsBlock() {
    final String? title = data.debtTitle?.trim();
    final String? note = data.note?.trim();
    pw.Widget gap() => pw.SizedBox(height: 6);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: <pw.Widget>[
        _summaryFact(
          localizations.receiptPaidOn,
          formatting.date(data.paidAt),
        ),
        if (title != null && title.isNotEmpty) ...<pw.Widget>[
          gap(),
          _summaryFact(localizations.receiptFor, title),
        ],
        // One payment spread over several debts: where each share went, and
        // what each debt has left. The total is the figure above.
        if (data.isSplit) ...<pw.Widget>[
          pw.SizedBox(height: 10),
          _text(
            '${localizations.receiptFor}:',
            style: const pw.TextStyle(
              fontSize: 9,
              color: DocumentColors.secondary,
            ),
          ),
          pw.SizedBox(height: 4),
          _table(
            headers: <String>[
              localizations.reportColumnDebt,
              localizations.reportColumnAmount,
              localizations.receiptRemainingNow,
            ],
            rows: <List<String>>[
              for (final ReceiptLine line in data.lines)
                <String>[
                  line.debtTitle,
                  _money(line.amount),
                  _money(line.remainingNow),
                ],
            ],
            widthFractions: const <double>[0.46, 0.24, 0.30],
            numericFrom: 1,
            totalRow: <String>[
              localizations.totalLabel,
              _money(data.amount),
              _money(data.remainingNow),
            ],
          ),
          pw.SizedBox(height: 4),
        ],
        gap(),
        _summaryFact(
          localizations.receiptRemainingNow,
          _money(data.remainingNow),
        ),
        if (note != null && note.isNotEmpty) ...<pw.Widget>[
          gap(),
          _summaryFact(localizations.fieldNote, note),
        ],
      ],
    );
  }
}
