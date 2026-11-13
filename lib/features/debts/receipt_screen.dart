import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/pdf/statement_models.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../data/services/statement_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the receipt for one payment.
Future<void> showReceipt(
  BuildContext context, {
  required DebtView view,
  required Payment payment,
}) {
  return Navigator.of(context).push<void>(
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
  bool _busy = false;

  /// Counts retries after a failed preview; part of the preview's key.
  int _attempt = 0;

  /// The person the receipt names: the one the debt is with, or every one of
  /// them for a record shared between several.
  String get _personName {
    final String names = widget.view.participantNames.trim();
    return names.isNotEmpty ? names : widget.view.displayName;
  }

  ReceiptData _data(StatementService service) => service.buildReceipt(
        view: widget.view,
        payment: widget.payment,
        personName: _personName,
        now: DateTime.now(),
        issuerName: _issuerName,
      );

  Future<File> _render() {
    final StatementService service = ref.read(statementServiceProvider);
    return service.renderReceipt(_data(service));
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

  Future<void> _share(Rect? origin) {
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

  Future<void> _editIssuer() async {
    final String? name = await showAppSheet<String>(
      context,
      child: _IssuerSheet(initial: _issuerName),
    );
    if (name == null || !mounted || name == _issuerName) return;
    setState(() => _issuerName = name);
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
            tooltip: localizations.reportOptionIssuer,
            icon: const Icon(Icons.person_outline, size: 20),
            onPressed: _editIssuer,
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: PdfPreview(
              key: ValueKey<Object>((_issuerName, _attempt)),
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
                icon: Icons.error_outline,
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
                            : () => _share(_originOf(buttonContext)),
                        icon: const Icon(Icons.ios_share, size: 20),
                        label: Text(localizations.reportSharePdf),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _print,
                      icon: const Icon(Icons.print_outlined, size: 18),
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

  /// Where a widget is on the screen, for a share sheet to point at.
  static Rect? _originOf(BuildContext context) {
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox || !object.hasSize) return null;
    return object.localToGlobal(Offset.zero) & object.size;
  }
}

/// One field: the name the receipt is issued under.
class _IssuerSheet extends StatefulWidget {
  const _IssuerSheet({required this.initial});

  final String initial;

  @override
  State<_IssuerSheet> createState() => _IssuerSheetState();
}

class _IssuerSheetState extends State<_IssuerSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AppSheet(
      title: localizations.reportOptionIssuer,
      primaryLabel: localizations.filterApply,
      onPrimary: () => Navigator.of(context).pop(_name.text.trim()),
      child: AppTextField(
        label: localizations.reportOptionIssuer,
        controller: _name,
        helperText: localizations.reportOptionIssuerHint,
        prefixIcon: Icons.person_outline,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        maxLength: 60,
        autofocus: true,
      ),
    );
  }
}
