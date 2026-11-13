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
import '../../core/share/share_origin.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/async_value_view.dart';
import '../../core/widgets/bottom_sheet_shell.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/feedback.dart';
import '../../core/widgets/form_fields.dart';
import '../../core/widgets/money_text.dart';
import '../../core/widgets/settings_tile.dart';
import '../../data/services/statement_service.dart';
import '../../domain/entities/ledger_views.dart';
import '../../domain/entities/payment.dart';
import '../../l10n/enum_labels.dart';
import '../../l10n/generated/app_localizations.dart';

/// Opens the statement for a person.
///
/// The preview is the real document, built from the same records the app is
/// showing, so what the user checks before sending is exactly what the other
/// person receives — not an illustration of it.
///
/// With [debtId] the statement opens on that one debt. The person's other debts
/// are a tap away on the same screen; they are simply not what was asked for.
Future<void> showStatement(
  BuildContext context,
  String personId, {
  String? debtId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (BuildContext context) =>
          StatementScreen(personId: personId, initialDebtId: debtId),
    ),
  );
}

/// The statement screen: what it covers, a live preview, and the actions.
class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({
    required this.personId,
    this.initialDebtId,
    super.key,
  });

  final String personId;

  /// The one debt to open on, when the statement was asked for from a debt.
  final String? initialDebtId;

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  /// What the statement shows. Lives here and nowhere else: it is not stored,
  /// so nothing chosen on this screen can alter a record.
  late StatementOptions _options = widget.initialDebtId == null
      ? const StatementOptions()
      : StatementOptions(
          scope: StatementScope.selected,
          selectedDebtIds: <String>{widget.initialDebtId!},
        );

  /// The currency the user picked, or null while the screen is still choosing
  /// for them.
  AppCurrency? _currency;
  bool _busy = false;

  /// The document as it last rendered. Kept so sharing, printing and the preview
  /// all refer to one build rather than three subtly different ones.
  StatementData? _document;

  /// Counts the times the user asked for the preview again after it failed.
  /// Part of the preview's key, so a new number builds a new document.
  int _attempt = 0;

  void _setOptions(StatementOptions options) {
    if (options == _options) return;
    setState(() {
      _options = options;
      _document = null;
    });
  }

  /// The currency to state: the user's choice while it still has something to
  /// show, otherwise the first that does. Null when nothing is in scope at all.
  AppCurrency? _resolveCurrency(
    PersonLedger ledger,
    List<AppCurrency> currencies,
  ) {
    if (currencies.isEmpty) return null;
    final AppCurrency? chosen = _currency;
    if (chosen != null && currencies.contains(chosen)) return chosen;
    // Opened from a debt: start in that debt's own currency.
    final String? debtId = widget.initialDebtId;
    if (chosen == null && debtId != null) {
      for (final DebtView view in ledger.debts) {
        if (view.debt.id == debtId && currencies.contains(view.currency)) {
          return view.currency;
        }
      }
    }
    return currencies.first;
  }

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

          if (StatementService.allCurrenciesFor(data).isEmpty) {
            // A person with no debts gets an explanation, not an empty document.
            return EmptyState(
              title: localizations.personNoDebts,
              body: localizations.reportEmptyBody,
              actionLabel: localizations.addDebtAction,
              onAction: () => Navigator.of(context).pop(),
            );
          }

          final List<AppCurrency> currencies =
              StatementService.currenciesFor(data, options: _options);
          final AppCurrency? currency = _resolveCurrency(data, currencies);
          final ({int settled, int archived}) hidden = currency == null
              ? (settled: 0, archived: 0)
              : StatementService.hiddenCounts(
                  ledger: data,
                  currency: currency,
                  options: _options,
                );

          return Column(
            children: <Widget>[
              _ScopeBar(
                scope: _options.scope,
                hiddenSettled: hidden.settled,
                hiddenArchived: hidden.archived,
                onScope: (StatementScope scope) => _chooseScope(data, scope),
                onShowSettled: () => _setOptions(
                  _options.copyWith(scope: StatementScope.all),
                ),
                onShowArchived: () => _setOptions(
                  _options.copyWith(includeArchived: true),
                ),
              ),
              if (currency != null && currencies.length > 1)
                _CurrencyPicker(
                  currencies: currencies,
                  selected: currency,
                  onChanged: (AppCurrency value) => setState(() {
                    _currency = value;
                    _document = null;
                  }),
                ),
              Expanded(
                child: currency == null
                    // Debts exist, but none of them is what the statement is
                    // set to show. Say which, and offer the way out — never a
                    // blank page.
                    ? _NothingInScope(
                        scope: _options.scope,
                        onShowSettled: () => _setOptions(
                          _options.copyWith(
                            scope: StatementScope.all,
                            includeArchived: true,
                          ),
                        ),
                        onChoose: () =>
                            _chooseScope(data, StatementScope.selected),
                      )
                    : _Preview(
                        // Rebuilds the document whenever the options or the
                        // currency change, which is what makes the preview
                        // live. Keyed by value, so options that print the same
                        // document do not rebuild it.
                        key: ValueKey<Object>((currency, _options, _attempt)),
                        builder: (PdfPageFormat format) =>
                            _buildBytes(data, currency),
                        onRetry: () => setState(() => _attempt++),
                      ),
              ),
              _ActionBar(
                busy: _busy,
                onShare: currency == null ? null : () => _share(data, currency),
                onPrintOrSave: currency == null
                    ? null
                    : () => _printOrSave(data, currency),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Applies a scope. Choosing by hand opens the list of debts first, and keeps
  /// the previous scope when the user backs out or ticks nothing.
  Future<void> _chooseScope(PersonLedger ledger, StatementScope scope) async {
    if (scope != StatementScope.selected) {
      _setOptions(_options.copyWith(scope: scope));
      return;
    }
    final Set<String>? chosen = await showAppSheet<Set<String>>(
      context,
      child: _DebtPickerSheet(
        personId: widget.personId,
        debts: ledger.debts,
        initial: _options.scope == StatementScope.selected
            ? _options.selectedDebtIds
            : const <String>{},
      ),
    );
    if (chosen == null || chosen.isEmpty || !mounted) return;
    _setOptions(
      _options.copyWith(
        scope: StatementScope.selected,
        selectedDebtIds: chosen,
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
      child: _OptionsSheet(initial: _options),
    );
    if (result == null || !mounted) return;
    _setOptions(result);
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
          // An iPad does not open a share sheet that has nowhere to point.
          sharePositionOrigin: shareOriginFallback(),
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
  const _Preview({required this.builder, required this.onRetry, super.key});

  final LayoutCallback builder;

  /// Builds the document again. A failure used to leave a line of text and no
  /// way forward but leaving the screen.
  final VoidCallback onRetry;

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
      onError: (BuildContext context, Object error) => EmptyState(
        title: AppLocalizations.of(context).exportFailed,
        actionLabel: AppLocalizations.of(context).actionRetry,
        onAction: onRetry,
        icon: Icons.error_outline,
      ),
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

  /// Null when there is no document to act on, which disables the button.
  final VoidCallback? onShare;
  final VoidCallback? onPrintOrSave;

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
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.palette.textOnBrand,
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

/// What the statement covers, always in view above the preview.
///
/// The scope used to be reachable only through the options sheet, where nobody
/// looked for it: a settled debt on a statement is the first thing a user wants
/// to change, so the control for it sits beside the document itself.
class _ScopeBar extends StatelessWidget {
  const _ScopeBar({
    required this.scope,
    required this.hiddenSettled,
    required this.hiddenArchived,
    required this.onScope,
    required this.onShowSettled,
    required this.onShowArchived,
  });

  final StatementScope scope;
  final int hiddenSettled;
  final int hiddenArchived;
  final ValueChanged<StatementScope> onScope;
  final VoidCallback onShowSettled;
  final VoidCallback onShowArchived;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    Widget chip(StatementScope value, String label) => ChoiceChip(
          label: Text(label),
          selected: scope == value,
          // Tapping the chosen-by-hand chip again reopens the list, so the
          // selection can be changed without leaving and coming back.
          onSelected: (_) => onScope(value),
        );

    Widget hiddenLine(String text, VoidCallback onShow) => Row(
          children: <Widget>[
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: palette.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: onShow,
              child: Text(localizations.reportShowThem),
            ),
          ],
        );

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              chip(StatementScope.openOnly, localizations.reportScopeOpen),
              chip(StatementScope.all, localizations.reportScopeAll),
              chip(StatementScope.selected, localizations.reportScopeSelected),
            ],
          ),
          if (hiddenSettled > 0)
            hiddenLine(
              localizations.reportHiddenSettled(hiddenSettled),
              onShowSettled,
            ),
          if (hiddenArchived > 0)
            hiddenLine(
              localizations.reportHiddenArchived(hiddenArchived),
              onShowArchived,
            ),
        ],
      ),
    );
  }
}

/// Shown instead of a preview when no debt matches what the statement is set to
/// cover: every debt settled, or nothing ticked in this currency.
class _NothingInScope extends StatelessWidget {
  const _NothingInScope({
    required this.scope,
    required this.onShowSettled,
    required this.onChoose,
  });

  final StatementScope scope;
  final VoidCallback onShowSettled;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    if (scope == StatementScope.selected) {
      return EmptyState(
        title: localizations.reportNothingSelectedTitle,
        actionLabel: localizations.reportSelectDebts,
        onAction: onChoose,
      );
    }
    return EmptyState(
      title: localizations.reportNothingOpenTitle,
      body: localizations.reportNothingOpenBody,
      actionLabel: localizations.reportShowSettled,
      onAction: onShowSettled,
      tone: EmptyTone.positive,
    );
  }
}

/// The person's debts, to tick the ones a statement should cover.
///
/// Every debt is listed, in every state and currency: this is the one place a
/// settled or an archived debt can be put on a statement deliberately. Each row
/// says what state it is in, so nothing is ticked by mistake.
class _DebtPickerSheet extends StatefulWidget {
  const _DebtPickerSheet({
    required this.personId,
    required this.debts,
    required this.initial,
  });

  final String personId;
  final List<DebtView> debts;
  final Set<String> initial;

  @override
  State<_DebtPickerSheet> createState() => _DebtPickerSheetState();
}

class _DebtPickerSheetState extends State<_DebtPickerSheet> {
  late final Set<String> _chosen = <String>{...widget.initial};

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final AppPalette palette = context.palette;

    return AppSheet(
      title: localizations.reportSelectDebts,
      // Its own button rather than the sheet's default: the default disappears
      // when it has nothing to do, and a button that waits for a choice should
      // stay where it is, disabled, so the sheet does not jump.
      primaryAction: SizedBox(
        width: double.infinity,
        child: FilledButton(
          // Nothing ticked is not a statement.
          onPressed: _chosen.isEmpty
              ? null
              : () => Navigator.of(context).pop(<String>{..._chosen}),
          child: Text(localizations.filterApply),
        ),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: ListView(
          shrinkWrap: true,
          children: <Widget>[
            for (final DebtView view in widget.debts)
              CheckboxListTile(
                value: _chosen.contains(view.debt.id),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(
                  view.displayNameFor(widget.personId),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  view.status.label(localizations),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                secondary: MoneyText(
                  view.isSettled ? view.principal : view.remaining,
                  showCode: true,
                  style: theme.textTheme.titleSmall,
                ),
                onChanged: (bool? ticked) => setState(() {
                  if (ticked ?? false) {
                    _chosen.add(view.debt.id);
                  } else {
                    _chosen.remove(view.debt.id);
                  }
                }),
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
  late final TextEditingController _issuer =
      TextEditingController(text: widget.initial.issuerName);

  @override
  void dispose() {
    _issuer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations localizations = AppLocalizations.of(context);
    return AppSheet(
      title: localizations.reportOptionsTitle,
      primaryLabel: localizations.filterApply,
      onPrimary: () => Navigator.of(context).pop(
        _draft.copyWith(issuerName: _issuer.text.trim()),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          AppTextField(
            label: localizations.reportOptionIssuer,
            controller: _issuer,
            helperText: localizations.reportOptionIssuerHint,
            prefixIcon: Icons.person_outline,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            maxLength: 60,
          ),
          const SizedBox(height: AppSpacing.sm),
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
            // Off by default: archiving is how a record is put out of sight, and
            // a document sent to someone else must not bring it back unasked.
            title: localizations.reportOptionArchived,
            subtitle: localizations.reportOptionArchivedHint,
            icon: Icons.archive_outlined,
            value: _draft.includeArchived,
            onChanged: (bool value) => setState(
              () => _draft = _draft.copyWith(includeArchived: value),
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
