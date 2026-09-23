import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/providers.dart';
import '../../core/money/currency.dart';
import '../../core/pdf/statement_models.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/services/statement_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the statement for a person.
///
/// The preview is the real document, built from the same records the app is
/// showing, so what the user checks before sending is exactly what the other
/// person receives — not an illustration of it.
Future<void> showStatement(BuildContext context, String personId) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) => StatementScreen(personId: personId),
    ),
  );
}

/// The statement screen: a live preview, the document options, and the actions.
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({required this.personId, super.key});

  final String personId;

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  StatementOptions _options = const StatementOptions();
  AppCurrency? _currency;
  bool _busy = false;

  /// The document as it last rendered. Kept so sharing, printing and the preview
  /// all refer to one build rather than three subtly different ones.
  StatementData? _document;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AsyncValue<PersonLedger?> ledger =
        ref.watch(personLedgerProvider(widget.personId));

    return Scaffold(
      appBar: AppBar(
        title: Text(localizations.reportStatementTitle),
        actions: <Widget>[
          IconButton(
            tooltip: localizations.reportOptionsTitle,
            icon: const Icon(Icons.tune, size: 20),
            onPressed: () => _openOptions(),
          ),
        ],
      ),
      body: AsyncValueView<PersonLedger?>(
        value: ledger,
        onRetry: () => ref.invalidate(personLedgerProvider(widget.personId)),
        loading: const ListSkeleton(rows: 4),
        isEmpty: (PersonLedger? value) => value == null,
        empty: Center(child: Text(localizations.personDeleted)),
        builder: (BuildContext context, PersonLedger? data) {
          if (data == null) return const SizedBox.shrink();
          final List<AppCurrency> currencies =
              StatementService.currenciesFor(data);

          if (currencies.isEmpty) {
            // A person with no debts gets an explanation, not an empty document.
            return EmptyState(
              title: localizations.personNoDebts,
              body: localizations.reportEmptyBody,
              actionLabel: localizations.addDebtAction,
              onAction: () => Navigator.of(context).pop(),
            );
          }

          final AppCurrency currency = _currency ?? currencies.first;
          _currency ??= currency;

          return Column(
            children: <Widget>[
              if (currencies.length > 1)
                _CurrencyPicker(
                  currencies: currencies,
                  selected: currency,
                  onChanged: (AppCurrency value) => setState(() {
                    _currency = value;
                    _document = null;
                  }),
                ),
              Expanded(
                child: _Preview(
                  // Rebuilds the document whenever the options or currency
                  // change, which is what makes the preview live.
                  key: ValueKey<String>('$currency-${_options.hashCode}'),
                  builder: (PdfPageFormat format) => _buildBytes(data, currency),
                ),
              ),
              _ActionBar(
                busy: _busy,
                onShare: () => _share(data, currency),
                onPrintOrSave: () => _printOrSave(data, currency),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Builds the document and returns its bytes for the preview.
  Future<Uint8List> _buildBytes(PersonLedger ledger, AppCurrency currency) async {
    final File file = await _render(ledger, currency);
    return file.readAsBytes();
  }

  /// Renders the document, remembering the data it was built from.
  Future<File> _render(PersonLedger ledger, AppCurrency currency) async {
    final StatementService service = ref.read(statementServiceProvider);
    final List<Payment> payments = <Payment>[];
    for (final DebtView view in ledger.debts) {
      payments.addAll(
        await ref.read(paymentRepositoryProvider).forDebt(view.debt.id),
      );
    }
    final StatementData data = service.buildData(
      ledger: ledger,
      payments: payments,
      currency: currency,
      now: DateTime.now(),
      options: _options,
    );
    _document = data;
    return service.render(data);
  }

  Future<void> _openOptions() async {
    final StatementOptions? result = await showAppSheet<StatementOptions>(
      context,
      isScrollControlled: false,
      child: _OptionsSheet(initial: _options),
    );
    if (result == null || !mounted) return;
    setState(() {
      _options = result;
      _document = null;
    });
  }

  Future<void> _share(PersonLedger ledger, AppCurrency currency) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final File file = await _render(ledger, currency);
      await SharePlus.instance.share(
        ShareParams(
          files: <XFile>[XFile(file.path, mimeType: 'application/pdf')],
          subject: localizations.reportStatementTitle,
        ),
      );
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Opens the platform dialog where a copy can be saved or printed.
  Future<void> _printOrSave(PersonLedger ledger, AppCurrency currency) async {
    final AppLocalizations localizations = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final File file = await _render(ledger, currency);
      final Uint8List bytes = await file.readAsBytes();
      await Printing.layoutPdf(
        name: _document?.fileName ?? 'Dhimmah',
        onLayout: (PdfPageFormat format) async => bytes,
      );
    } on Object {
      if (!mounted) return;
      AppFeedback.error(context, localizations.exportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The live document preview.
///
/// Drawn by the platform's own PDF renderer, so the user is looking at the file
/// rather than a reconstruction of it.
class _Preview extends StatelessWidget {
  const _Preview({required this.builder, super.key});

  final LayoutCallback builder;

  @override
  Widget build(BuildContext context) {
    return PdfPreview(
      build: builder,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      useActions: false,
      allowPrinting: false,
      allowSharing: false,
      dynamicLayout: false,
      padding: const EdgeInsets.all(AppSpacing.md),
      loadingWidget: const Center(child: CircularProgressIndicator()),
      onError: (BuildContext context, Object error) =>
          Center(child: Text(AppLocalizations.of(context).exportFailed)),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busy,
    required this.onShare,
    required this.onPrintOrSave,
  });

  final bool busy;
  final VoidCallback onShare;
  final VoidCallback onPrintOrSave;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final AppPalette palette = context.palette;

    return Container(
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
              child: FilledButton.icon(
                onPressed: busy ? null : onShare,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.ios_share, size: 20),
                label: Text(localizations.reportSharePdf),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: busy ? null : onPrintOrSave,
                icon: const Icon(Icons.print_outlined, size: 18),
                label: Text(localizations.reportSavePdf),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CurrencyPicker extends StatelessWidget {
  const _CurrencyPicker({
    required this.currencies,
    required this.selected,
    required this.onChanged,
  });

  final List<AppCurrency> currencies;
  final AppCurrency selected;
  final ValueChanged<AppCurrency> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                localizations.fieldCurrency,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            for (final AppCurrency currency in currencies)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: ChoiceChip(
                  label: Text(currency.code),
                  selected: currency == selected,
                  onSelected: (_) => onChanged(currency),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The document options.
class _OptionsSheet extends StatefulWidget {
  const _OptionsSheet({required this.initial});

  final StatementOptions initial;

  @override
  State<_OptionsSheet> createState() => _OptionsSheetState();
}

class _OptionsSheetState extends State<_OptionsSheet> {
  late StatementOptions _draft = widget.initial;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AppSheet(
      title: localizations.reportOptionsTitle,
      primaryLabel: localizations.filterApply,
      onPrimary: () => Navigator.of(context).pop(_draft),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          SettingsSwitchTile(
            title: localizations.reportOptionPayments,
            subtitle: localizations.reportPaymentHistory,
            icon: Icons.receipt_long_outlined,
            value: _draft.includePayments,
            onChanged: (bool value) => setState(
              () => _draft = _draft.copyWith(includePayments: value),
            ),
          ),
          SettingsSwitchTile(
            title: localizations.reportOptionBreakdown,
            subtitle: localizations.reportDebtsBreakdown,
            icon: Icons.list_alt_outlined,
            value: _draft.includeDebtBreakdown,
            onChanged: (bool value) => setState(
              () => _draft = _draft.copyWith(includeDebtBreakdown: value),
            ),
          ),
          SettingsSwitchTile(
            // Off by default: the recipient usually already has the number, and
            // this document is often sent to them.
            title: localizations.reportOptionPhone,
            subtitle: localizations.personPhoneLabel,
            icon: Icons.phone_outlined,
            value: _draft.includePhone,
            onChanged: (bool value) => setState(
              () => _draft = _draft.copyWith(includePhone: value),
            ),
          ),
          SettingsSwitchTile(
            // Also off by default: a note is often the user's own reminder.
            title: localizations.reportOptionNotes,
            subtitle: localizations.fieldNote,
            icon: Icons.notes,
            value: _draft.includeNotes,
            onChanged: (bool value) => setState(
              () => _draft = _draft.copyWith(includeNotes: value),
            ),
          ),
        ],
      ),
    );
  }
}
