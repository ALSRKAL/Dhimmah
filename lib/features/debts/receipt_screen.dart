import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/share/share_origin.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/read_models/ledger_queries.dart';
import '../../data/services/statement_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the receipt for one payment.
///
/// [navigator] is for a caller whose own context is gone by the time the
/// receipt is asked for — the payment sheet, which offers it after closing.
Future<void> showReceipt(
  BuildContext context, {
  required DebtView view,
  required Payment payment,
  NavigatorState? navigator,
}) {
  return (navigator ?? Navigator.of(context)).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          ReceiptScreen(view: view, payment: payment),
    ),
  );
}

/// A payment's receipt: the document itself, and the two things done with it.
///
/// The preview is the real file, as on the statement screen. The receipt is
/// built from the payment and the debt the screen was opened with, so it shows
/// the payment as it was when the user asked — it reads, and writes nothing.
class ReceiptScreen extends ConsumerStatefulWidget {
  const ReceiptScreen({required this.view, required this.payment, super.key});

  final DebtView view;
  final Payment payment;

  @override
  ConsumerState<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends ConsumerState<ReceiptScreen> {
  /// The user's own name on the receipt. Typed here and kept only while the
  /// screen is open: the app stores no name for its user.
  String _issuerName = '';

  /// Whether the payment's note is printed. Off unless asked for: a note is
  /// often the user's own reminder, and a receipt is handed to the other party.
  bool _includeNote = false;
  bool _busy = false;

  /// Counts retries after a failed preview; part of the preview's key.
  int _attempt = 0;

  /// The person the receipt names: the one the debt is with, or every one of
  /// them for a record shared between several.
  String get _personName {
    final String names = widget.view.participantNames.trim();
    return names.isNotEmpty ? names : widget.view.displayName;
  }

  /// Every part of the payment this receipt is for, each with its debt.
  ///
  /// A payment recorded from a person's page against several debts is several
  /// rows; the receipt is for all of them, however it was opened. Read fresh
  /// each time, so a part edited or removed since is reflected. Falls back to
  /// the one row it was opened on if anything cannot be matched.
  Future<List<({DebtView view, Payment payment})>> _parts() async {
    // The debt as it stands now, not as the caller last saw it: a receipt
    // offered straight after saving a payment was handed the view from before
    // it, and printed the balance the payment had just cleared.
    DebtView current = widget.view;
    try {
      final DebtDetail? detail = await ref.read(
        debtDetailProvider(widget.view.debt.id).future,
      );
      if (detail != null) current = detail.view;
    } on Object {
      // The view the screen was opened with is still a true account.
    }
    final List<({DebtView view, Payment payment})> single =
        <({DebtView view, Payment payment})>[
      (view: current, payment: widget.payment),
    ];
    final String? personId = widget.payment.personId;
    if (personId == null) return single;
    final List<Payment> personPayments = await ref
        .read(paymentRepositoryProvider)
        .watchForPerson(personId)
        .first;
    final List<Payment> group =
        StatementService.paymentGroupOf(widget.payment, personPayments);
    if (group.length < 2) return single;
    final PersonLedger? ledger =
        await ref.read(personLedgerProvider(personId).future);
    if (ledger == null) return single;
    final Map<String, DebtView> byId = <String, DebtView>{
      for (final DebtView view in ledger.debts) view.debt.id: view,
    };
    final List<({DebtView view, Payment payment})> parts =
        <({DebtView view, Payment payment})>[
      for (final Payment payment in group)
        if (byId[payment.debtId] != null)
          (view: byId[payment.debtId]!, payment: payment),
    ];
    return parts.length == group.length ? parts : single;
  }

  Future<File> _render() async {
    final StatementService service = ref.read(statementServiceProvider);
    final List<({DebtView view, Payment payment})> parts = await _parts();
    // A split payment is from the person, not from one record's participants.
    String personName = _personName;
    if (parts.length > 1 && widget.payment.personId != null) {
      final PersonLedger? ledger = await ref
          .read(personLedgerProvider(widget.payment.personId!).future);
      if (ledger != null) personName = ledger.person.name;
    }
    return service.renderReceipt(
      service.buildReceipt(
        parts: parts,
        personName: personName,
        now: DateTime.now(),
        issuerName: _issuerName,
        includeNote: _includeNote,
      ),
    );
  }

  Future<void> _run(Future<void> Function(File file) action) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await action(await _render());
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share(Rect origin) {
    final String subject = AppLocalizations.of(context).receiptAction;
    return _run(
      (File file) => SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          subject: subject,
          // Where the share sheet points on a tablet. An iPad refuses to show
          // one that has nowhere to point.
          sharePositionOrigin: origin,
        ),
      ),
    );
  }

  Future<void> _print() => _run((File file) async {
        final Uint8List bytes = await file.readAsBytes();
        await Printing.layoutPdf(
          name: file.uri.pathSegments.last,
          onLayout: (PdfPageFormat format) async => bytes,
        );
      });

  Future<void> _editOptions() async {
    final String note = widget.payment.note?.trim() ?? '';
    final ({String issuer, bool includeNote})? result =
        await showAppSheet<({String issuer, bool includeNote})>(
      context,
      child: _ReceiptOptionsSheet(
        initialIssuer: _issuerName,
        initialIncludeNote: _includeNote,
        // Offered only when there is a note to print.
        hasNote: note.isNotEmpty,
      ),
    );
    if (result == null || !mounted) return;
    if (result.issuer == _issuerName && result.includeNote == _includeNote) {
      return;
    }
    setState(() {
      _issuerName = result.issuer;
      _includeNote = result.includeNote;
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;
    final String title = widget.view.debt.direction.isIOwe
        ? localizations.receiptTitleOut
        : localizations.receiptTitleIn;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: <Widget>[
          IconButton(
            tooltip: localizations.receiptOptionsTitle,
            icon: const Icon(AppIcons.tune, size: 20),
            onPressed: _editOptions,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PdfPreview(
              key: ValueKey<Object>((_issuerName, _includeNote, _attempt)),
              build: (PdfPageFormat format) async =>
                  (await _render()).readAsBytes(),
              canChangeOrientation: false,
              canChangePageFormat: false,
              canDebug: false,
              useActions: false,
              allowPrinting: false,
              allowSharing: false,
              dynamicLayout: false,
              padding: const EdgeInsets.all(AppSpacing.md),
              loadingWidget: const Center(child: CircularProgressIndicator()),
              onError: (BuildContext context, Object error) => EmptyState(
                title: localizations.exportFailed,
                actionLabel: localizations.actionRetry,
                onAction: () => setState(() => _attempt++),
                icon: AppIcons.error,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border(top: BorderSide(color: palette.border)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      // Its own context, so the button's place on screen can be
                      // read when it is pressed.
                      builder: (BuildContext buttonContext) =>
                          FilledButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _share(shareOriginOf(buttonContext)),
                        icon: const Icon(AppIcons.iosShare, size: 20),
                        label: Text(localizations.reportSharePdf),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _print,
                      icon: const Icon(AppIcons.print, size: 18),
                      label: Text(localizations.reportSavePdf),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// What the receipt carries beyond the payment: the issuer's name, and the note.
class _ReceiptOptionsSheet extends StatefulWidget {
  const _ReceiptOptionsSheet({
    required this.initialIssuer,
    required this.initialIncludeNote,
    required this.hasNote,
  });

  final String initialIssuer;
  final bool initialIncludeNote;
  final bool hasNote;

  @override
  State<_ReceiptOptionsSheet> createState() => _ReceiptOptionsSheetState();
}

class _ReceiptOptionsSheetState extends State<_ReceiptOptionsSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initialIssuer);
  late bool _includeNote = widget.initialIncludeNote;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AppSheet(
      title: localizations.receiptOptionsTitle,
      primaryLabel: localizations.filterApply,
      onPrimary: () => Navigator.of(context).pop(
        (issuer: _name.text.trim(), includeNote: _includeNote),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: localizations.reportOptionIssuer,
            controller: _name,
            helperText: localizations.reportOptionIssuerHint,
            prefixIcon: AppIcons.person,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 60,
          ),
          if (widget.hasNote)
            SettingsSwitchTile(
              title: localizations.reportOptionNotes,
              subtitle: localizations.paymentNote,
              icon: AppIcons.notes,
              value: _includeNote,
              onChanged: (bool value) => setState(() => _includeNote = value),
            ),
        ],
      ),
    );
  }
}
